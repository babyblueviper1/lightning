# syntax=docker/dockerfile:1.7-labs

FROM debian:bookworm-slim AS base

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        git \
        wget \
        autoconf \
        automake \
        libtool \
        pkg-config \
        libsodium-dev \
        libsqlite3-dev \
        libpq-dev \
        python3-dev \
        python3-pip \
        jq \
        inotify-tools \
        socat \
        protobuf-compiler \
        libffi-dev \
        libgmp-dev \
        libssl-dev \
        curl \
        gnupg \
        lowdown && \
    rm -rf /var/lib/apt/lists/*

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /opt

# Clone CLN without .git and submodules
RUN git clone --depth 1 https://github.com/ElementsProject/lightning.git
WORKDIR /opt/lightning

# Build
RUN ./configure --disable-rust --disable-valgrind --enable-static
RUN make -j$(nproc)

# Final image
FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        inotify-tools \
        socat \
        jq \
        libpq5 \
        libsqlite3-0 \
        libsodium23 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/lightning/lightningd /usr/local/bin/
COPY --from=builder /opt/lightning/cli/lightning-cli /usr/local/bin/

# Entry point
COPY tools/docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV LIGHTNINGD_DATA=/root/.lightning
ENV LIGHTNINGD_RPC_PORT=9835
ENV LIGHTNINGD_PORT=9735
ENV LIGHTNINGD_NETWORK=bitcoin

EXPOSE 9735 9835
VOLUME ["/root/.lightning"]
ENTRYPOINT ["/entrypoint.sh"]
