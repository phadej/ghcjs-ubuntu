#!/bin/bash

set -e

# Versions
VER=8.6.0.1
GHCVER=8.6.5
CABALVER=3.4
BOOTCABALVER=3.2

# Installation prefix
INSTPREFIX="$1"

if [ -z "$INSTPREFIX" ]; then
	echo "Usage: ./boot-bin.sh"
	exit 1
fi

############################################################################
## Configuring

if [ -x /usr/bin/nodejs ]; then
    NODE=/usr/bin/nodejs
elif [ -x /usr/bin/node ]; then
    NODE=/usr/bin/node
else
    echo "WARNING: node not found"
fi

echo "NodeJS: $NODE"
$NODE --version

WORKDIR=${PWD}
TOPDIR0=/opt/ghcjs/$VER/lib/ghcjs

BINDIR=${INSTPREFIX}/opt/ghcjs/$VER/bin
TOPDIR=${INSTPREFIX}${TOPDIR0}

GHCJSDEPREPO="${WORKDIR}/dependencies"

# Unset cabal directories
unset CABAL_DIR
unset CABAL_CONFIG

# Make cabal.rc (global cabal config)
sed "s|@GHCJSDEPREPO@|$GHCJSDEPREPO|g" "${WORKDIR}/cabal.rc.in" > "${WORKDIR}/cabal.rc"

if [ ! -f "${WORKDIR}/cabal.rc.in" ]; then
    echo "cabal.rc not found in pwd ($WORKDIR)"
    exit 1
fi

# Make "CABAL_DIR"
mkdir -p /tmp/cabal

# Remove installation prefix
rm -rf "$INSTPREFIX"

# Update repository cache
PATH=/opt/ghc/$GHCVER/bin:$PATH HOME=/tmp/home CABAL_CONFIG="${WORKDIR}/cabal.rc" \
    /opt/cabal/$CABALVER/bin/cabal v2-update ghcjs-dependencies

############################################################################
## Building

PATH=/opt/ghc/$GHCVER/bin:$PATH HOME=/tmp/home CABAL_CONFIG="${WORKDIR}/cabal.rc" \
    /opt/cabal/$CABALVER/bin/cabal --project-file=./cabal.ghcjs.project v2-build :pkg:ghcjs

rm -fv .ghc.environment.x86_64-linux-$GHCVER

mkdir -p "$TOPDIR/bin"
for N in ghcjs ghcjs-pkg haddock-ghcjs hsc2hs-ghcjs; do
    cp -v "$WORKDIR/dist-newstyle/build/x86_64-linux/ghc-$GHCVER/ghcjs-$VER/build/$N/$N" "$TOPDIR/bin/$N"
done

GHCJSBOOT=$WORKDIR/dist-newstyle/build/x86_64-linux/ghc-$GHCVER/ghcjs-$VER/build/ghcjs-boot/ghcjs-boot
GHCJSRUN=$WORKDIR/dist-newstyle/build/x86_64-linux/ghc-$GHCVER/ghcjs-$VER/build/ghcjs-run/ghcjs-run
BOOTTAR=$WORKDIR/ghcjs-$VER/data/boot.tar

############################################################################
## building core binaries phase done; here starts boot library bootstrap phase

mkdir -p "${BINDIR}"

# temporary inplace wrappers
for N in ghcjs ghcjs-pkg haddock-ghcjs hsc2hs-ghcjs; do
    sed "s|@TOPDIR@|$TOPDIR|g" "./wrappers/$N.in" > "$BINDIR/$N"
    chmod +x "$BINDIR/$N"
done

HOME=/tmp/cabal CABAL_CONFIG="${WORKDIR}/cabal.rc" PATH="${BINDIR}:/opt/ghc/$GHCVER/bin:$PATH" \
    $GHCJSBOOT -s "$BOOTTAR" \
    --no-prof --no-haddock \
    --with-node $NODE \
    --with-ghcjs-run "$GHCJSRUN" \
    --with-cabal /opt/cabal/$BOOTCABALVER/bin/cabal

############################################################################
## fixup installation

# fixup database
sed -i "s|$TOPDIR|\${pkgroot}|g" "${TOPDIR}/package.conf.d"/*.conf
"$BINDIR/ghcjs-pkg" recache -v

# remove redundant stuff
rm -rf "$TOPDIR/boot"

# create proper wrappers
for N in ghcjs ghcjs-pkg haddock-ghcjs hsc2hs-ghcjs; do
    rm -fv "$BINDIR/$N"
    sed "s|@TOPDIR@|$TOPDIR0|g" "./wrappers/$N.in" > "$BINDIR/$N-$VER"
    chmod +x "$BINDIR/$N-$VER"
done

############################################################################
## Done

exit 0
