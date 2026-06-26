# Building / installing TextWorld from source

This document explains how to install TextWorld directly from the source tree
(rather than from PyPI). It also covers how the Inform 7 toolchain gets staged,
which matters on architectures such as **aarch64** that have no official Inform
release to download.

## TL;DR

```bash
git clone <this repo> && cd TextWorld
pip install .            # core
pip install ".[pddl]"   # core + ALFWorld's PDDL planner (fast-downward-textworld)
pip install ".[vis]"    # core + visualization stack
pip install ".[full]"   # everything
```

Installing any of the above runs `setup.sh`, which stages the Inform 7
toolchain TextWorld needs at build time and at game-compile time.

## Requirements

- Python >= 3.9 (tested on 3.11)
- A C toolchain (for `jericho`, which provides the z-machine interpreter used
  to *play* generated games — `jericho` ships aarch64 wheels, so no local
  build is needed there)
- The Inform 7 toolchain (see below) — this is what `setup.sh` provides

## How Inform 7 is obtained (`setup.sh`)

TextWorld compiles generated games with two Inform binaries and a folder of
built-in resources:

```
textworld/thirdparty/inform7/share/inform7/
    Compilers/ni        # the Inform 7 -> Inform 6 compiler (was "ni" in 6M62)
    Compilers/inform6   # the Inform 6 -> z-machine compiler
    Internal/           # Standard Rules, English Language, Basic Inform,
                        # and the Inter-based Kits (WorldModelKit, ...)
```

`setup.sh` stages this tree, in priority order:

1. **`INFORM_HOME` already set** and pointing at a usable Inform install
   (`<INFORM_HOME>/share/inform7/Compilers/ni` exists) → use it as-is,
   skip staging. Lets you point at any Inform you already have.

2. **A prebuilt bundle is shipped in the repo** at
   `textworld/thirdparty/inform7-<arch>.tar.gz` → unpack it into
   `textworld/thirdparty/inform7/`. This is the default path and needs no
   local Inform source tree. An aarch64 bundle
   (`inform7-aarch64.tar.gz`) is included; cloning the repo and installing
   works out of the box on aarch64.

3. **Fallback: stage from a locally-built Inform source tree** at
   `INFORM7_SRC` (default `../i7`). Used when no matching prebuilt bundle
   exists — e.g. rebuilding on a new architecture. `INFORM7_SRC` must point
   at the directory containing the open-source `inform/`, `inweb/` and
   `intest/` repositories, with `inform/` already built (`make` inside it).
   `setup.sh` then copies `inform/inform7/Tangled/inform7` → `Compilers/ni`,
   `inform/inform6/Tangled/inform6` → `Compilers/inform6`, and the whole
   `inform/inform7/Internal` directory.

Notes:

- The unpacked `textworld/thirdparty/inform7/` is a runtime artifact and is
  gitignored; only the `.tar.gz` bundles are committed.
- The old 6M62 flow (download three tarballs from emshort.com + patch
  `Actions.i6t`) is gone. Inform 10.x has `trace_actions` built in, emitting
  the exact `[action - succeeded]` text TextWorld parses, so no patching is
  needed.
- TextWorld does **not** use an external game interpreter binary; it plays
  games via `jericho.FrotzEnv` (a pip package). The old "interpreters"
  tarball is therefore not needed at all.

## aarch64 (e.g. this machine)

`pip install ".[pddl]"` works directly because:

- The repo ships `textworld/thirdparty/inform7-aarch64.tar.gz` (Inform 10.2.0
  "Krypton", built from source on aarch64). `setup.sh` unpacks it.
- `fast-downward-textworld` (the `[pddl]` extra) and `jericho` both have
  aarch64 wheels on PyPI.

No local Inform build is required.

## Rebuilding Inform from source (other architectures / development)

If you need to refresh the bundled binaries or target an architecture for
which no bundle exists:

1. Check out and build the open-source Inform tree:
   ```bash
   git clone https://github.com/ganelson/inform
   git clone https://github.com/ganelson/inweb
   git clone https://github.com/ganelson/intest
   # build (see the inform/ repository's README); produces:
   #   inform/inform7/Tangled/inform7
   #   inform/inform6/Tangled/inform6
   ```
2. Point `setup.sh` at it:
   ```bash
   INFORM7_SRC=/path/to/parent_of_inform bash setup.sh
   ```
3. (Optional) Produce a bundle for the repo so others on that arch don't
   have to rebuild:
   ```bash
   cd textworld/thirdparty
   tar czf inform7-$(uname -m).tar.gz -C inform7 share
   ```
   Commit `inform7-<arch>.tar.gz`; it will be used by step 2 of `setup.sh`.

## Building a wheel

To build a platform wheel (carries the staged Inform binaries):

```bash
# from the repo root, after setup.sh has staged Inform (pip install does this)
pip wheel --no-build-isolation -w releases/ ".[pddl]"
```

`--no-build-isolation` is required: it lets `setup.sh` run in the current
shell, where Inform is staged. The resulting `textworld-<ver>-cp311-cp311-
linux_<arch>.whl` is architecture-specific (it bundles native binaries).

Install a built wheel directly:

```bash
pip install releases/textworld-1.7.0-cp311-cp311-linux_aarch64.whl          # core only
pip install "releases/textworld-1.7.0-cp311-cp311-linux_aarch64.whl[pddl]"   # + planner
```

For a fully offline install (textworld + all deps), build them into one dir:

```bash
pip wheel --no-build-isolation -w wheelhouse/ ".[pddl]"
pip install --no-index --find-links wheelhouse/ "textworld[pddl]"
```
