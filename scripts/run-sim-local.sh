#!/usr/bin/env bash
# Build and run the dronex_sim release (edge brain + simulator driver) on one
# node, in a console.
#
# MESH NOTE (mesh-only, like parksim): contact_observed and track_confirmed are
# integration facts that cross the macula mesh. Ground-truth events flow through
# the local store regardless, but to close the full sim -> emitter -> fusion ->
# scorer loop the node needs a macula station + realm. Set station_seeds in
# config/sys.config (under hecate_om) to a reachable station, or run a local
# one. Without it, the simulator still produces ground truth and the slices are
# unit-testable, but the fact hops are no-ops.
set -euo pipefail
cd "$(dirname "$0")/.."

export DRONEX_ROLE="${DRONEX_ROLE:-sim}"
export SITE_ID="${SITE_ID:-leuven-perimeter}"
export DRONEX_TIME_SCALE="${DRONEX_TIME_SCALE:-10.0}"
export DRONEX_SCENARIO="${DRONEX_SCENARIO:-perimeter_probe}"
export HECATE_DATA_DIR="${HECATE_DATA_DIR:-$(pwd)/_data}"

rebar3 release -n dronex_sim
exec _build/default/rel/dronex_sim/bin/dronex_sim console
