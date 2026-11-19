#!/bin/bash
# Build the *source* package (.dsc + .orig.tar.gz + .debian.tar.xz), one for
# every suite, for upload to deb.gaofn.xyz. build_debian.sh builds the
# binaries from this same source package.
#
# The orig tarball is upstream's tmux-<ver>.tar.gz with ncurses' signed
# release unpacked into ncurses/ (debian/rules builds its terminfo library
# and links it into tmux statically). It is one tarball rather than an
# orig-ncurses component because the mirror imports a single orig per
# source package. It is reproducible: fixed order, owner and mtime.
#
# Usage: ./build_src.sh <tmux_version> <build_version>
set -euo pipefail

VERSION="${1:-}"
BUILD="${2:-}"
if [ -z "$VERSION" ] || [ -z "$BUILD" ]; then
    echo "Usage: $0 <tmux_version> <build_version>" >&2
    echo "Example: $0 3.8 1" >&2
    exit 1
fi

# ncurses release linked into tmux, verified against Thomas E. Dickey's key
# (debian/upstream/ncurses-signing-key.asc, as shipped by Debian's ncurses,
# fingerprint 1988 2D92 DDA4 C400 C22C 0D56 CC2A F447 2167 BE03).
NCURSES_VERSION="6.6"

HERE="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_NAME="tmux"
ORIG_TARBALL="${PACKAGE_NAME}_${VERSION}.orig.tar.gz"
BUILD_DIR="${PACKAGE_NAME}-${VERSION}"

# A rebuild of an upstream version already released here (a +N build bump)
# must ship the very same orig tarball: the pool holds one per upstream
# version and reprepro refuses a different one. Reuse the earlier release's copy.
if [ ! -f "$ORIG_TARBALL" ]; then
    for ((b = BUILD - 1; b >= 1; b--)); do
        if wget -q "https://github.com/gaofengnan/tmux-debian/releases/download/${VERSION}%2B${b}/${ORIG_TARBALL}" -O "$ORIG_TARBALL"; then
            echo "  Reusing $ORIG_TARBALL from release ${VERSION}+${b}"
            break
        fi
        rm -f "$ORIG_TARBALL"
    done
fi

if [ ! -f "$ORIG_TARBALL" ]; then
    echo "Assembling $ORIG_TARBALL (tmux ${VERSION} + ncurses ${NCURSES_VERSION})..."
    rm -rf dl "$BUILD_DIR"
    mkdir dl
    wget -q "https://github.com/tmux/tmux/releases/download/${VERSION}/tmux-${VERSION}.tar.gz" -O "dl/tmux-${VERSION}.tar.gz"
    wget -q "https://ftp.gnu.org/gnu/ncurses/ncurses-${NCURSES_VERSION}.tar.gz" -O "dl/ncurses.tar.gz"
    wget -q "https://ftp.gnu.org/gnu/ncurses/ncurses-${NCURSES_VERSION}.tar.gz.sig" -O "dl/ncurses.tar.gz.sig"
    gpg --dearmor < "$HERE/debian/upstream/ncurses-signing-key.asc" > dl/ncurses-key.gpg
    gpgv --keyring "$PWD/dl/ncurses-key.gpg" dl/ncurses.tar.gz.sig dl/ncurses.tar.gz

    tar -xzf "dl/tmux-${VERSION}.tar.gz"
    [ -f "$BUILD_DIR/configure" ] || { echo "❌ unexpected tmux tarball layout" >&2; exit 1; }
    mkdir "$BUILD_DIR/ncurses"
    tar -xzf dl/ncurses.tar.gz -C "$BUILD_DIR/ncurses" --strip-components=1
    [ -f "$BUILD_DIR/ncurses/configure" ] || { echo "❌ unexpected ncurses tarball layout" >&2; exit 1; }

    # The newest file in tmux's own tarball dates it, so rebuilding the
    # orig of a given release gives the same bytes.
    # TZ and --mode keep the host's timezone and umask out of the bytes.
    MTIME="$(TZ=UTC tar -tvzf "dl/tmux-${VERSION}.tar.gz" --full-time | awk '{print $4" "$5}' | sort | tail -1)"
    tar --sort=name --owner=0 --group=0 --numeric-owner --mode=go-w --mtime="${MTIME} UTC" \
        -cf - "$BUILD_DIR" | gzip -n -9 > "$ORIG_TARBALL"
    rm -rf dl "$BUILD_DIR"
    echo "  Saved as $ORIG_TARBALL"
else
    echo "  Using existing $ORIG_TARBALL"
fi

FULL_VERSION="${VERSION}-${BUILD}~gaofn"
echo "  Building source package ${FULL_VERSION}..."
rm -rf "$BUILD_DIR"
tar -xzf "$ORIG_TARBALL"
cp -r "$HERE/debian" "$BUILD_DIR/"
cat > "$BUILD_DIR/debian/changelog" << EOC
tmux (${FULL_VERSION}) stable; urgency=medium

  * New upstream release ${VERSION}.

 -- Fengnan Gao <gao.fengnan@gmail.com>  $(date -R)
EOC
dpkg-source -b "$BUILD_DIR"
rm -rf "$BUILD_DIR"

echo ""
echo "Source package created:"
ls -la "${PACKAGE_NAME}_${FULL_VERSION}.dsc" "$ORIG_TARBALL" "${PACKAGE_NAME}_${FULL_VERSION}.debian.tar.xz"
