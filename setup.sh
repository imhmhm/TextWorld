#!/usr/bin/env bash

# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT license.

set -ex
echo "Running setup.sh...";

# Repo root (this script lives at the top of the checkout).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=Mac;;
    CYGWIN*)    machine=Cygwin;;
    MINGW*)     machine=MinGW;;
    *)          machine="UNKNOWN:${unameOut}"
esac

cd "$SCRIPT_DIR/textworld/thirdparty/"

# Directory where TextWorld expects the Inform 7 installation to live. The
# path is referenced by I7_DEFAULT_PATH in textworld/generator/inform7/
# world2inform7.py (and can be overridden with the INFORM_HOME env var).
INSTALL_DIR="inform7"

# Allow callers to point at a pre-installed Inform instead of staging one
# from source. If INFORM_HOME is set and already contains a usable compiler,
# there is nothing to do here.
if [ -n "$INFORM_HOME" ] && [ -x "$INFORM_HOME/share/inform7/Compilers/ni" ]; then
    echo "INFORM_HOME ($INFORM_HOME) already provides Inform 7; nothing to stage."
    exit 0
fi

# Detect the machine architecture the way Inform's own release tarballs did,
# so we can pick the matching prebuilt bundle.
ARCH="$(uname -m)"

# Prefer a prebuilt, architecture-specific Inform bundle shipped in the repo
# (textworld/thirdparty/inform7-<arch>.tar.gz). This keeps TextWorld
# self-contained: cloning the repo and running setup.sh works without a local
# Inform source tree. The bundle's layout is exactly what we stage below:
#   share/inform7/Compilers/{ni,inform6}
#   share/inform7/Internal/...
BUNDLE="$SCRIPT_DIR/textworld/thirdparty/inform7-${ARCH}.tar.gz"

stage_from_bundle() {
    echo "Unpacking bundled Inform 7 ($BUNDLE) into $INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    tar xzf "$BUNDLE" -C "$INSTALL_DIR"
    chmod +x "$INSTALL_DIR/share/inform7/Compilers/ni" \
             "$INSTALL_DIR/share/inform7/Compilers/inform6"
}

# Fallback: stage directly from a locally-compiled Inform 10.x tree (the
# open-source 'inform', 'inweb' and 'intest' repositories built with 'make').
# Used when no matching prebuilt bundle exists (e.g. rebuilding on a new arch).
# Override the tree root with INFORM7_SRC=<path>.
stage_from_source() {
    INFORM7_SRC="${INFORM7_SRC:-$SCRIPT_DIR/../i7}"
    INFORM_SRC="$INFORM7_SRC/inform"
    if [ ! -x "$INFORM_SRC/inform7/Tangled/inform7" ] || \
       [ ! -x "$INFORM_SRC/inform6/Tangled/inform6" ]; then
        return 1
    fi
    echo "Staging Inform 7 from source tree ($INFORM_SRC) into $INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/share/inform7/Compilers"
    cp "$INFORM_SRC/inform7/Tangled/inform7" "$INSTALL_DIR/share/inform7/Compilers/ni"
    cp "$INFORM_SRC/inform6/Tangled/inform6" "$INSTALL_DIR/share/inform7/Compilers/inform6"
    chmod +x "$INSTALL_DIR/share/inform7/Compilers/ni" \
             "$INSTALL_DIR/share/inform7/Compilers/inform6"
    cp -R "$INFORM_SRC/inform7/Internal" "$INSTALL_DIR/share/inform7/Internal"
}

if [ -f "$BUNDLE" ]; then
    stage_from_bundle
elif ! stage_from_source; then
    echo "ERROR: no Inform 7 available." >&2
    echo "       No prebuilt bundle at $BUNDLE, and no compiled Inform tree" >&2
    echo "       found (looked for $SCRIPT_DIR/../i7/inform by default)." >&2
    echo "       Either add a bundle textworld/thirdparty/inform7-${ARCH}.tar.gz," >&2
    echo "       set INFORM7_SRC to a built inform/ tree, or point INFORM_HOME at" >&2
    echo "       an existing Inform installation." >&2
    exit 1
fi

echo "Staged Inform 7:"
"$INSTALL_DIR/share/inform7/Compilers/ni" -version
