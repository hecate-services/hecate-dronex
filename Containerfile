# Multi-stage Erlang build for the dronex_edge release (the site brain).
# The dronex_sim release is a dev/test artifact and is not containerised here.
# Pushed to ghcr.io/hecate-services/hecate-dronex-edge:latest + :semver.

#----------------------------------------------------------------------
# Stage 1 — builder
#----------------------------------------------------------------------
FROM docker.io/erlang:27-alpine AS builder

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

# Build only the edge release (contains zero simulation code).
RUN rebar3 as prod tar -n dronex_edge

#----------------------------------------------------------------------
# Stage 2 — runtime
#----------------------------------------------------------------------
FROM docker.io/alpine:3.22

RUN apk add --no-cache libstdc++ ncurses-libs openssl ca-certificates

WORKDIR /app
COPY --from=builder /build/_build/prod/rel/dronex_edge/*.tar.gz /tmp/release.tar.gz
RUN tar xf /tmp/release.tar.gz && rm /tmp/release.tar.gz

VOLUME ["/etc/hecate/secrets", "/var/lib/hecate-dronex"]

ENTRYPOINT ["/app/bin/dronex_edge"]
CMD ["foreground"]
