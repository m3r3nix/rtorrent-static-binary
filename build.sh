#!/bin/sh
# build.sh
#
# Compiles a fully-static rtorrent binary inside an Alpine Linux container.
#
# Required environment variables:
#   VERSION_NUM   rtorrent / libtorrent version without the leading 'v'
#                 (e.g.  0.16.12)
#   RTORRENT_SHA  Git commit hash for rtorrent in case of a nightly build (e.g. 1a2b3c4)
#   LIBTORRENT_SHA Git commit hash for libtorrent in case of a nightly build (e.g. 1a2b3c4)
#   ARCH          Output filename suffix that identifies the target CPU
#                 (e.g.  amd64  or  arm64)
# Optional environment variables:
#   WITH_OPTION   extra build parameter for rtorrent
#                 (e.g. --with-xmlrpc-c or --with-xmlrpc-tinyxml2)
#   SUFFIX        Extra suffix for the output file

set -eux

: "${VERSION_NUM:=}"
: "${RTORRENT_SHA:=}"
: "${LIBTORRENT_SHA:=}"
: "${ARCH:?ARCH must be set (e.g. amd64 or arm64)}"
: "${WITH_OPTION:=}"
: "${SUFFIX:=}"

if [ -z "${VERSION_NUM}" ] && { [ -z "${RTORRENT_SHA}" ] || [ -z "${LIBTORRENT_SHA}" ]; }; then
    echo "VERSION_NUM must be set for release builds, or RTORRENT_SHA and LIBTORRENT_SHA must be set for nightly builds." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# 1. System packages
# ---------------------------------------------------------------------------
apk add --no-cache \
    autoconf \
    autoconf-archive \
    automake \
    brotli-static \
    build-base \
    cppunit-dev \
    curl \
    curl-dev \
    curl-static \
    gawk \
    gettext-dev \
    git \
    libidn2-static \
    libpsl-static \
    libtool \
    libunistring-dev \
    libunistring-static \
    ncurses-dev \
    ncurses-static \
    nghttp2-static \
    openssl-dev \
    openssl-libs-static \
    pkgconf \
    xmlrpc-c-dev \
    xmlrpc-c-static \
    zlib-dev \
    zlib-static \
    zstd-static

# ---------------------------------------------------------------------------
# 2. Build libtorrent (same version tag as rtorrent)
# ---------------------------------------------------------------------------
mkdir -p /build
cd /build

# If VERSION_NUM is set, we download the source tarball for that version. This is the default behavior for release builds.
# If VERSION_NUM is not set, we clone the git repository and checkout the specified commit. This is used for nightly builds that do not have a version tag.
if [ -n "${VERSION_NUM}" ]; then
    curl -fsSLO \
        "https://github.com/rakshasa/rtorrent/releases/download/v${VERSION_NUM}/libtorrent-${VERSION_NUM}.tar.gz"
    tar xf "libtorrent-${VERSION_NUM}.tar.gz"
    cd "libtorrent-${VERSION_NUM}"
else
    git clone --filter=blob:none --single-branch https://github.com/rakshasa/libtorrent.git
    cd libtorrent
    git checkout "$LIBTORRENT_SHA"
fi

autoreconf -fi
./configure \
    --enable-static \
    --disable-shared \
    --disable-debug \
    PKG_CONFIG="pkg-config --static" \
    CFLAGS="-Os" \
    CXXFLAGS="-Os"

make -j"$(nproc)"
make install

# ---------------------------------------------------------------------------
# 3. Build rtorrent (same version tag as libtorrent)
# ---------------------------------------------------------------------------
cd /build

if [ -n "${VERSION_NUM}" ]; then
    curl -fsSLO \
        "https://github.com/rakshasa/rtorrent/releases/download/v${VERSION_NUM}/rtorrent-${VERSION_NUM}.tar.gz"
    tar xf "rtorrent-${VERSION_NUM}.tar.gz"
    cd "rtorrent-${VERSION_NUM}"
else
    git clone --filter=blob:none --single-branch https://github.com/rakshasa/rtorrent.git
    cd rtorrent
    git checkout "$RTORRENT_SHA"
fi

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
