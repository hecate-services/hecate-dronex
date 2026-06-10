# Proposal: an over-mesh test basis (mem-macula + hecate-om-testkit)

**Status:** Draft / Concept &nbsp;·&nbsp; **Date:** 2026-06-10 &nbsp;·&nbsp; **Driving consumer:** hecate-dronex

> Drafted in hecate-dronex because the need surfaced here (the DroneX over-mesh
> loop is untestable today), but the work lands in **macula-io** and
> **hecate-services**. Proposed final homes: `macula-io/macula/proposals/` and
> `hecate-services/hecate-om/proposals/` once accepted.

## 1. Problem

CMD and PRJ/QRY are now testable single-process:

- CMD: `evoq-testkit` (Layer A pure aggregate spec, Layer B persistence via
  `mem-evoq`). No store, no station.
- PRJ/QRY: plain eunit (`project/4` against a temp store; query the store).

What is **not** testable without a live station + realm + cert is the mesh hop:
a fact published on one node reaching a subscriber on another. For DroneX that
is the entire integration: `simulate_airspace` ground truth, then
`observe_remote_id` publishes `airspace.contact_observed`, then `fuse_airspace`
consumes it and publishes `airspace.track_confirmed`, then
`query_detection_quality` scores it. None of that fact-crossing has a test.

## 2. Principle: mirror the layering that already works

The command side proves the pattern:

```
evoq    →  mem-evoq          →  evoq-testkit
(store)    (in-memory double)    (harness + assertions)
```

Do the same for the mesh:

```
macula  →  mem-macula        →  hecate-om-testkit
(SDK)      (in-memory double)    (service + mesh harness)
```

Two packages, two layers, distinct responsibilities. This directly answers the
"macula-testkit **or** hecate-om-testkit?" question: **both, and the double is
named `mem-macula` (not "macula-testkit"), because the analogue of `mem-evoq`
is a `mem-` double, while the testkit is the harness that composes it.**

## 3. Key finding: the seam already exists

`macula` already defines `macula_net_transport`, a behaviour described in-source
as the "transport plugin contract for macula-net" (QUIC, BATMAN-adv, LoRa,
satellite all implement it). `macula_net_transport_quic` is one implementation.

So an in-memory transport is **just another plugin**, not SDK surgery. This is
the equivalent of `mem-evoq` being a second `evoq` adapter. The real macula
pub/sub, routing, and dedup run unchanged on top; only the bytes-on-the-wire
layer is swapped for in-process message passing. That makes the double faithful
(it exercises real routing) and cheap (no QUIC, no certs, no network).

## 4. Package A: `macula-io/mem-macula`

An in-memory `macula_net_transport` implementation plus the minimal in-process
station/loopback wiring needed for two or more in-process nodes to exchange
envelopes. Goal: `macula:connect/2` against a loopback seed yields a usable
pool, and `macula:publish` on node A is delivered to `macula:subscribe` on node
B, through the real stack.

It also pins the **canonical delivery contract** (the `{macula_event, Ref,
Topic, Payload, Meta}` tuple shape, CBOR-term-not-JSON). Owning that in macula
prevents drift: the 4-vs-5-element ambiguity that forced defensive `handle_info`
clauses in DroneX is exactly the kind of thing a macula-owned double fixes once.

Reusable by every macula consumer (mpong-bot, macula-rag, git-remote-mesh,
macula-mcp), none of which want `hecate_om` dragged in.

Sketch:

```erlang
%% start an in-memory mesh with N nodes; returns connected pools
{ok, [PoolA, PoolB]} = mem_macula:cluster(2).
ok = macula:publish(PoolA, Realm, Topic, Fact).
%% PoolB's subscriber receives {macula_event, _, Topic, Fact, _}
```

**Altitude decision.** Two options: (a) a transport-plugin loopback (an
in-memory `macula_net_transport`, real routing above it) or (b) a facade-level
fake pool (publish wired straight to subscribers, routing bypassed). Recommend
**(a)**: the seam exists, it exercises the real pub/sub, and it catches routing
regressions a facade fake would mask. Fall back to (b) only if standing up the
in-process station proves heavy.

## 5. Package B: `hecate-services/hecate-om-testkit`

Composes `mem-macula` into the `hecate_om:boot` path so a service starts with a
mocked mesh and no cert/station: `hecate_om:macula_client()` returns the
loopback pool, `hecate_om_identity:realm()` returns a test realm.

Sketch:

```erlang
hecate_om_testkit:with_mesh(fun(Mesh) ->
    ok = hecate_om_testkit:boot_service(fuse_airspace_service, Mesh),
    ok = hecate_om_testkit:publish(Mesh, ContactTopic, ContactFact),
    hecate_om_testkit:assert_published(Mesh, TrackTopic,
        fun(F) -> airspace_track_confirmed:track_id(F) =/= undefined end)
end).
```

It is the analogue of `evoq-testkit`: the harness + assertions that make the
double usable in a test, this time for the service boundary instead of the
dispatch boundary. Depends on `hecate_om` + `mem-macula`.

## 6. Dependency DAG (no cycles)

```
macula
  ├── mem-macula            (depends on macula)
hecate_om                   (depends on macula)
  └── hecate-om-testkit     (depends on hecate_om + mem-macula)
```

## 7. What it unlocks for DroneX

An over-mesh test boots the `dronex_sim` apps under `hecate-om-testkit` with a
2-node in-memory mesh, runs the `perimeter_probe` scenario, and asserts the full
loop: ground truth produced, `contact_observed` facts emitted, `track_confirmed`
facts published, and the final `score_detection:overview/0` within tolerance.
That is the one gap the CMD and PRJ/QRY suites cannot reach.

## 8. Scope boundaries

- `mem-macula` does **pub/sub + RPC first** (what services use). DHT records and
  streaming are later additions, behind the same transport seam.
- QRY testing stays app-local (plain eunit against a read-model fixture); not a
  mesh concern.
- A thin projection driver (`evoq_projection_spec`, "Layer C") belongs in
  `evoq-testkit`, not here. Separate, smaller proposal.

## 9. First step

Spike the in-memory `macula_net_transport` in `mem-macula`: stand up a 2-node
loopback cluster and prove `publish` on one node reaches `subscribe` on the
other through the real stack. If that holds, `hecate_om_testkit:with_mesh/1`
follows quickly, and the DroneX over-mesh test lands on top.
