# syntax=docker/dockerfile:1

###############################################################################
# Builder stage – only for components not conveniently available as Debian pkgs
###############################################################################
FROM debian:bookworm-slim AS builder
ARG DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        build-essential \
        meson \
        pkg-config \
        cmake \
        ca-certificates \
        git \
        curl \
        wget \
        unzip \
        sudo \
        lua5.1 \
        liblua5.1-0-dev \
        luajit \
        libffi-dev \
        libssl-dev \
        lua-bit32 \
        lua-cqueues \
        lua-http \
        lua-check \
        luarocks \
        pre-commit \
    ; \
    rm -rf /var/lib/apt/lists/*

# Build cffi-lua
RUN set -eux; \
    cd /tmp; \
    git clone --depth 1 https://github.com/q66/cffi-lua; \
    mkdir -p cffi-lua/build; \
    cd cffi-lua/build; \
    meson .. -Dlua_version=5.1 --buildtype=release; \
    ninja; \
    ninja test; \
    install -D -m 0644 cffi.so /out/usr/local/lib/lua/5.1/cffi.so; \
    rm -rf /tmp/cffi-lua

# Build nixio (manual install into /out; avoids Makefile DESTDIR issues)
RUN set -eux; \
    cd /tmp; \
    git clone --depth 1 https://github.com/Neopallium/nixio; \
    cd nixio; \
    make; \
    install -D -m 0644 src/nixio.so /out/usr/local/lib/lua/5.1/nixio.so; \
    mkdir -p /out/usr/local/share/lua/5.1; \
    if [ -d lua/nixio ]; then cp -a lua/nixio /out/usr/local/share/lua/5.1/; fi; \
    if [ -f lua/nixio.lua ]; then install -D -m 0644 lua/nixio.lua /out/usr/local/share/lua/5.1/nixio.lua; fi; \
    rm -rf /tmp/nixio

# Install luaposix from LuaRocks (pinned), staged into /out/usr/local
RUN set -eux; \
    luarocks --lua-version=5.1 --tree /out/usr/local install luaposix 36.3-1; \
    LUA_PATH='/out/usr/local/share/lua/5.1/?.lua;/out/usr/local/share/lua/5.1/?/init.lua;;' \
    LUA_CPATH='/out/usr/local/lib/lua/5.1/?.so;;' \
    lua5.1 -e "assert(require('posix.sys.socket')); print('luaposix ok on lua5.1')"; \
    LUA_PATH='/out/usr/local/share/lua/5.1/?.lua;/out/usr/local/share/lua/5.1/?/init.lua;;' \
    LUA_CPATH='/out/usr/local/lib/lua/5.1/?.so;;' \
    luajit -e "assert(require('posix.sys.socket')); print('luaposix ok on luajit')"

###############################################################################
# Final stage – runtime only (no compiler toolchain)
###############################################################################
FROM debian:bookworm-slim AS final
ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Runtime deps + Debian-packaged Lua modules (excluding lua-posix)
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        git \
        curl \
        sudo \
        lua5.1 \
        lua-bit32 \
        lua-cjson \
        lua-cqueues \
        lua-http \
        lua-check \
        luajit \
        wget \
    ; \
    rm -rf /var/lib/apt/lists/*

# Non-root user for VS Code
RUN set -eux; \
    groupadd --gid "${USER_GID}" "${USERNAME}"; \
    useradd  --uid "${USER_UID}" --gid "${USER_GID}" -m "${USERNAME}"; \
    echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}"; \
    chmod 0440 "/etc/sudoers.d/${USERNAME}"

# Copy compiled artefacts from builder (cffi, nixio, luaposix rock files)
COPY --from=builder /out/ /

USER ${USERNAME}