# hecate-dronex
#
# One island: a roster of drone controllers, an airspace, and a network that
# defends it.
#
# ONE IMAGE, WHERE THERE WERE TWO. The counter-UAS line built `dronex_sim' and
# `dronex_edge' from one tree with a RELEASE build-arg. An island is both a world
# and the brain that lives in it, so there is nothing left for the wall to
# separate. design/DESIGN_THE_SECOND_ACT.md says what came forward.
#
# ==========================================================================
# THE RUNTIME IS PINNED IN TWO PLACES AND THEY MUST AGREE
# ==========================================================================
#
# Here, and `.github/workflows/lint.yml'. On a sibling they did not: one said 27
# while development ran on 28, so a local `rebar3 eunit' meant "passing on 28"
# and nothing more. CI then failed for three commits on a crash that does not
# occur on 28 at all, and because `build-and-push' is a separate workflow the
# image went to the fleet regardless.
#
# ⚠ AND A RUN IS ONLY A PURE FUNCTION OF ITS SEED WITHIN ONE OTP RELEASE. `rand'
# and map iteration order are not promised to agree across releases, so seed 101
# is a different run on 28 and on 29. Every result this project records is a
# result about the release it was measured on.
#
# ==========================================================================
# WHY 28 AND NOT 29, MEASURED RATHER THAN ASSUMED
# ==========================================================================
#
# OTP 29 deprecates the old-style `catch Expr', and two libraries in this
# dependency tree use it while building with warnings as errors. Measured on a
# sibling 2026-08-04, whole tree, 29.0.2 against 28.4.2:
#
#     OTP 28.4.2   clean, compile exit 0
#     OTP 29.0.2   reckon_gater_repl.erl        FAILED   5 sites   ours
#                  khepri_import_export.erl     FAILED   2 sites   NOT ours
#
# rebar3 stops at the first failing application, so the second was found only by
# suppressing the first in a throwaway build directory. Reporting reckon_gater
# alone would have understated this as one small fix away.
#
# reckon-gater is ours and is a short change. khepri is RabbitMQ's, arrives
# through reckon_db, and needs an UPSTREAM release. So 29 is not a decision this
# project can take on its own. When both land, this pin and lint.yml's move
# together and the note stays, so the reason is not rediscovered by whoever next
# thinks 29 looks free.
FROM docker.io/erlang:28-alpine AS builder
WORKDIR /build

# TWO Rust NIFs are built here, not one.
#
# macula ships a QUIC NIF, and MACULA_FORCE_SOURCE_BUILD makes it build here
# rather than fetch a prebuilt binary linked against a different libc, which is
# the recorded glibc trap: the fetched artifact loads on the build host and fails
# on alpine at runtime.
#
# faber_tweann ships `native/faber_nn_nifs', which is why the dependency is in
# rebar.config at the spine rather than at the first module that evaluates a
# network. A NIF that does not build is exactly the kind of failure that appears
# in a container and never on a laptop, and finding that out now is the whole
# point of building the tedious end first.
RUN apk add --no-cache git curl bash build-base cmake perl linux-headers
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --default-toolchain stable --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}"
ENV RUSTFLAGS="-C target-feature=-crt-static"
ENV MACULA_FORCE_SOURCE_BUILD=1

RUN curl -fsSL https://s3.amazonaws.com/rebar3/rebar3 -o /usr/local/bin/rebar3 \
    && chmod +x /usr/local/bin/rebar3

# Dependencies resolve from rebar.config alone, so this layer survives every
# change to config/ and apps/ and the Rust toolchain is not re-run per commit.
COPY rebar.config ./
RUN rebar3 get-deps

COPY config ./config
COPY apps ./apps
RUN rebar3 as prod release

FROM docker.io/alpine:3.22
# LINKS THE PACKAGE TO THE REPO. Without it a ghcr package is an orphan: it does
# not appear on the repo page and does not inherit the repo's visibility. A
# sibling shipped private by accident this way and the deploy failed on the node
# with a bare "unauthorized" from the pull, which names nothing.
LABEL org.opencontainers.image.source="https://github.com/hecate-services/hecate-dronex"
RUN apk add --no-cache ncurses-libs libstdc++ libgcc openssl ca-certificates curl
WORKDIR /app
COPY --from=builder /build/_build/prod/rel/hecate_dronex ./

ENV HOME=/app
ENV RELX_REPLACE_OS_VARS=true

ENV HECATE_NODE_NAME=hecate_dronex
ENV HECATE_NODE_HOST=127.0.0.1
ENV HECATE_COOKIE=hecate_dronex
# Clear of the siblings: 8450, 8460, 8461, 8470, 8471 and 8481 to 8485 are taken
# across the fleet, and host networking makes a collision a silent bind failure.
ENV HECATE_HEALTH_PORT=8486

VOLUME ["/etc/hecate/secrets"]

EXPOSE 8486
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${HECATE_HEALTH_PORT}/health" || exit 1

CMD ["/app/bin/hecate_dronex", "foreground"]
