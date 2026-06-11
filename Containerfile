# Multi-stage Erlang build for a DroneX release.
#
#   RELEASE=dronex_sim  (default) — the demo/simulator: generates drones, runs
#                        the full loop, and publishes airspace/<site>/* facts to
#                        the mesh. This is the image the live dashboard demo runs
#                        (4 tenants on the beam cluster). -> hecate-dronex-sim
#   RELEASE=dronex_edge — the production site brain (consumes real sensor facts,
#                        zero simulation code).                -> hecate-dronex-edge
#
# Build:  docker build -t ghcr.io/hecate-services/hecate-dronex-sim:latest .
#         docker build --build-arg RELEASE=dronex_edge -t .../hecate-dronex-edge .

ARG RELEASE=dronex_sim

#----------------------------------------------------------------------
# Stage 1 — builder
#----------------------------------------------------------------------
FROM docker.io/erlang:27-alpine AS builder
ARG RELEASE

RUN apk add --no-cache git curl bash build-base cmake perl linux-headers

# Rust via rustup (Alpine's rustc is too old for macula's NIF deps).
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --default-toolchain stable --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}"
ENV RUSTFLAGS="-C target-feature=-crt-static"

WORKDIR /build
COPY rebar.config rebar.lock* ./
COPY config ./config
COPY src ./src
COPY apps ./apps

RUN rebar3 as prod tar -n ${RELEASE}

#----------------------------------------------------------------------
# Stage 2 — runtime
#----------------------------------------------------------------------
FROM docker.io/alpine:3.22
ARG RELEASE
ENV RELEASE=${RELEASE}

RUN apk add --no-cache libstdc++ ncurses-libs openssl ca-certificates

WORKDIR /app
COPY --from=builder /build/_build/prod/rel/${RELEASE}/*.tar.gz /tmp/release.tar.gz
RUN tar xf /tmp/release.tar.gz && rm /tmp/release.tar.gz

VOLUME ["/etc/hecate/secrets", "/var/lib/hecate-dronex"]

# The release boot script is /app/bin/<release>; expand $RELEASE at runtime.
ENTRYPOINT ["/bin/sh", "-c", "exec /app/bin/$RELEASE foreground"]
