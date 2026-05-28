#!/bin/sh
# build-nightly.sh
#
# Compiles a fully-static rtorrent binary from upstream git commits inside an
# Alpine Linux container.
#
# Required environment variables:
#   RTORRENT_SHA  Git commit hash for rtorrent (e.g. 1a2b3c4)
#   LIBTORRENT_SHA Git commit hash for libtorrent (e.g. 1a2b3c4)
#   ARCH          Output filename suffix that identifies the target CPU
#                 (e.g.  amd64  or  arm64)
# Optional environment variables:
#   WITH_OPTION   extra build parameter for rtorrent
#                 (e.g. --with-xmlrpc-c or --with-xmlrpc-tinyxml2)
#   SUFFIX        Extra suffix for the output file

set -eux

: "${RTORRENT_SHA:?RTORRENT_SHA must be set}"
: "${LIBTORRENT_SHA:?LIBTORRENT_SHA must be set}"
: "${ARCH:?ARCH must be set (e.g. amd64 or arm64)}"
: "${WITH_OPTION:=}"
: "${SUFFIX:=}"

# ---------------------------------------------------------------------------
# 1. System packages
# ---------------------------------------------------------------------------
apk add --no-cache \
    autoconf \
    autoconf-archive \
    automake \
    build-base \
    cppunit-dev \
    gawk \
    gettext-dev \
    git \
    libtool \
    pkgconf \
    curl-dev \
    curl-static \
    brotli-static \
    libidn2-static \
    libpsl-static \
    libunistring-dev \
    libunistring-static \
    ncurses-dev \
    ncurses-static \
    nghttp2-static \
    openssl-dev \
    openssl-libs-static \
    xmlrpc-c-dev \
    xmlrpc-c-static \
    zlib-dev \
    zlib-static \
    zstd-static

# ---------------------------------------------------------------------------
# 2. Build libtorrent from the selected upstream commit
# ---------------------------------------------------------------------------
mkdir -p /build
cd /build

git clone --filter=blob:none --single-branch https://github.com/rakshasa/libtorrent.git
cd libtorrent
git checkout "$LIBTORRENT_SHA"

autoreconf -fi
./configure \
    --enable-aligned \
    --enable-static \
    --disable-shared \
    --disable-debug \
    PKG_CONFIG="pkg-config --static" \
    CFLAGS="-Os" \
    CXXFLAGS="-Os"

make -j"$(nproc)"
make install

# ---------------------------------------------------------------------------
# 3. Build rtorrent from the selected upstream commit
# ---------------------------------------------------------------------------
cd /build

git clone --filter=blob:none --single-branch https://github.com/rakshasa/rtorrent.git
cd rtorrent
git checkout "$RTORRENT_SHA"

autoreconf -fi
./configure \
    ${WITH_OPTION} \
    --enable-static \
    --disable-shared \
    --disable-debug \
    PKG_CONFIG="pkg-config --static" \
    CFLAGS="-Os" \
    CXXFLAGS="-Os"

make -j"$(nproc)" LDFLAGS="-all-static -Wl,--as-needed"

# ---------------------------------------------------------------------------
# 4. Copy and verify the output binary
# ---------------------------------------------------------------------------
OUTPUT="/output/rtorrent-linux-${ARCH}${SUFFIX}"

cp src/rtorrent "${OUTPUT}"
strip "${OUTPUT}"

echo "=== Build complete ==="
file "${OUTPUT}"
ls -lh "${OUTPUT}"
