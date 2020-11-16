# Packaging GHCJS for Ubuntu (or Debian)

This setup is based on HVR's ppa/ghcjs: https://launchpad.net/~hvr/+archive/ubuntu/ghcjs,
which atm provides only GHCJS-8.4

## Building in docker

### Bionic

```bash
docker run --rm -ti --entrypoint=/bin/bash phadej/ghc:8.6.5-bionic
```

```bash
mkdir /tmp/ghcjs-build
cd /tmp/ghcjs-build

apt-get update
apt-get install -y debhelper cabal-install-3.4 cabal-install-3.2 nodejs nodejs-dev npm node-gyp libssl1.0-dev

git clone https://github.com/phadej/ghcjs-ubuntu.git
cd ghcjs-ubuntu

cd ghcjs-8.6
time dpkg-buildpackage -i -us -uc -b
```

References:
- https://askubuntu.com/questions/1088662/npm-depends-node-gyp-0-10-9-but-it-is-not-going-to-be-installed

### Focal

```bash
docker run --rm -ti --entrypoint=/bin/bash phadej/ghc:8.6.5-focal
```

```bash
cd
apt-get update
apt-get install -y debhelper cabal-install-3.4 cabal-install-3.2 nodejs npm

git clone https://github.com/phadej/ghcjs-ubuntu.git
cd ghcjs-ubuntu

cd ghcjs-8.6
time dpkg-buildpackage -i -us -uc -b
```

## Steps to package GHCJS

In other words: How this repository contents are assembled.

- Prepare GHCJS source tree:
  - Checkout correct branch:  `git checkout ghc-8.6-ubuntu`
  - Make sure it is clean: `git clean -fdx && git submodule foreach --recursive git clean -fdx`
  - Apply GHC patch `cat | patch -p1`
- Create `boot.tar`: `./utils/makePackages.sh`
- Create sdists: `cabal v2-sdist all`
- Copy all sdists to `upstream/` subfolder
- Extract the `ghcjs-<version>.tar.gz` package, remove that tarball from `upstream/`
- Generate dependencies `plan.json`: `cabal build --dry --project-file=cabal.deps.project all`
- Use `cabal-bundler` to make curl download script: `cabal-bundler --curl --plan dist-newstyle/cache/plan.json ghcjs -o dependencies/download.sh`
- Download dependencies `(cd dependencies && sh download.sh)`
- Create "original" tarball: `tar -czvf ghcjs-8.6_8.6.0.1.orig.tar.gz --exclude=cabal.rc --exclude='debian/*' --exclude='dist-newstyle/*' ghcjs-8.6`. You should get around 16M tarball.
- Finally, we can build the package, for example `dpkg-buildpackage -i -us -uc -b`

## GHC patch(es)

We need to patch GHC-8.6 tree. https://gitlab.haskell.org/ghc/ghc/-/merge_requests/4420

```patch
diff --git a/libraries/base/base.cabal b/libraries/base/base.cabal
index f02ff0827c..8ae64a8351 100644
--- a/libraries/base/base.cabal
+++ b/libraries/base/base.cabal
@@ -1,4 +1,4 @@
-cabal-version:  2.1
+cabal-version:  2.2
 name:           base
 version:        4.12.0.0
 -- NOTE: Don't forget to update ./changelog.md
diff --git a/libraries/ghc-heap/ghc-heap.cabal.in b/libraries/ghc-heap/ghc-heap.cabal.in
index 6f9bd2d756..d7ab6c38bc 100644
--- a/libraries/ghc-heap/ghc-heap.cabal.in
+++ b/libraries/ghc-heap/ghc-heap.cabal.in
@@ -1,4 +1,4 @@
-cabal-version:  2.1
+cabal-version:  2.2
 name:           ghc-heap
 version:        @ProjectVersionMunged@
 license:        BSD-3-Clause
diff --git a/libraries/ghc-prim/ghc-prim.cabal b/libraries/ghc-prim/ghc-prim.cabal
index a95f1ecaa8..e6bf7fb624 100644
--- a/libraries/ghc-prim/ghc-prim.cabal
+++ b/libraries/ghc-prim/ghc-prim.cabal
@@ -1,4 +1,4 @@
-cabal-version:  2.1
+cabal-version:  2.2
 name:           ghc-prim
 version:        0.5.3
 -- NOTE: Don't forget to update ./changelog.md
```

## Gotchas

### ghc-prim

This is tricky package to build.
`cabal-install-3.4` doesn't like no `custom-setup` in `build-type: Custom`
package, but that causes cascade of effects.
Therefore we use `cabal-install-3.2` to boot GHCJS.

## Misc

- https://wiki.debian.org/Packaging/Intro?action=show&redirect=IntroDebianPackaging
- Does GHCJS depend on npm at runtime?
