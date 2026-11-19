#!/bin/bash
# Build the tmux binary packages (.deb), one per architecture for every
# suite, from the very source package build_src.sh produces.
#
# They are compiled in ubuntu:jammy, the oldest glibc (2.35) and the oldest
# libevent/jemalloc/systemd of the eight suites, so the one binary runs on
# all of them. arm64 is cross-compiled (no emulation needed to build).
#
# Produces, in ./out :
#   tmux_<ver>-<build>~gaofn_<arch>.deb    (amd64, arm64)
#
# Usage: ./build_debian.sh <tmux_version> <build_version> [amd64|arm64|all]
set -euo pipefail

VERSION="${1:-}"
BUILD="${2:-}"
ARCH="${3:-all}"
if [ -z "$VERSION" ] || [ -z "$BUILD" ]; then
    echo "Usage: $0 <tmux_version> <build_version> [amd64|arm64|all]" >&2
    echo "Example: $0 3.8 1 all" >&2
    exit 1
fi

FULL_VERSION="${VERSION}-${BUILD}~gaofn"

case "$ARCH" in
    all)   ARCHES=("amd64" "arm64") ;;
    amd64|arm64) ARCHES=("$ARCH") ;;
    *) echo "❌ Unsupported architecture: $ARCH (tmux-debian ships amd64 and arm64)" >&2; exit 1 ;;
esac

# The source package, built as the user in out/src (never by a container)
rm -rf out/src
mkdir -p out/src
(cd out/src && ../../build_src.sh "$VERSION" "$BUILD")

for arch in "${ARCHES[@]}"; do
    echo "==> Building tmux ${FULL_VERSION} (${arch})"

    docker build -t "tmux-${arch}" \
        --build-arg "ARCH=${arch}" \
        --build-arg "FULL_VERSION=${FULL_VERSION}" \
        -f Dockerfile .

    cid="$(docker create "tmux-${arch}")"
    docker cp "${cid}:/out/." ./out/
    docker rm "${cid}" > /dev/null
done

echo ""
echo "Built packages:"
ls -la out/tmux_*.deb
