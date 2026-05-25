#!/bin/sh
# build.sh
#
# Compiles a fully-static rtorrent binary inside an Alpine Linux container.
#
# Required environment variables:
#   VERSION_NUM   rtorrent / libtorrent version without the leading 'v'
#                 (e.g.  0.16.12)
#   ARCH          Output filename suffix that identifies the target CPU
#                 (e.g.  amd64  or  arm64)

set -eux

: "${VERSION_NUM:?VERSION_NUM must be set (e.g. 0.16.12)}"
: "${ARCH:?ARCH must be set (e.g. amd64 or arm64)}"

# ---------------------------------------------------------------------------
# 1. System packages
# ---------------------------------------------------------------------------
apk add --no-cache \
    build-base \
    autoconf \
    automake \
    libtool \
    pkgconf \
    curl-dev \
    libunistring-dev \
    ncurses-dev \
    ncurses-static \
    openssl-dev \
    zlib-dev \
    wget

# ---------------------------------------------------------------------------
# 2. Build libtorrent (same version tag as rtorrent)
# ---------------------------------------------------------------------------
mkdir -p /build
cd /build

wget -q \
    "https://github.com/rakshasa/rtorrent/releases/download/v${VERSION_NUM}/libtorrent-${VERSION_NUM}.tar.gz"
tar xf "libtorrent-${VERSION_NUM}.tar.gz"
cd "libtorrent-${VERSION_NUM}"

./configure \
    --enable-static \
    --disable-shared \
    PKG_CONFIG="pkg-config --static" \
    CXXFLAGS="-Os"

make -j"$(nproc)"
make install

# ---------------------------------------------------------------------------
# 3. Build rtorrent (same version tag as libtorrent)
# ---------------------------------------------------------------------------
cd /build

wget -q \
    "https://github.com/rakshasa/rtorrent/releases/download/v${VERSION_NUM}/rtorrent-${VERSION_NUM}.tar.gz"
tar xf "rtorrent-${VERSION_NUM}.tar.gz"
cd "rtorrent-${VERSION_NUM}"

./configure \
    --enable-static \
    --disable-shared \
    PKG_CONFIG="pkg-config --static" \
    LDFLAGS="-static -Wl,--as-needed" \
    CXXFLAGS="-Os"

make -j"$(nproc)"

# ---------------------------------------------------------------------------
# 4. Copy and verify the output binary
# ---------------------------------------------------------------------------
OUTPUT="/output/rtorrent-linux-${ARCH}"

cp src/rtorrent "${OUTPUT}"
strip "${OUTPUT}"

echo "=== Build complete ==="
file "${OUTPUT}"
ls -lh "${OUTPUT}"
