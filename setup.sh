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

# Location of a locally-compiled Inform 10.x tree (the open-source 'inform',
# 'inweb' and 'intest' repositories checked out side by side). On aarch64
# there is no prebuilt Inform release, so this is how Inform is obtained.
# Override with INFORM7_SRC=<path>.
INFORM7_SRC="${INFORM7_SRC:-$SCRIPT_DIR/../i7}"
INFORM_SRC="$INFORM7_SRC/inform"

if [ ! -x "$INFORM_SRC/inform7/Tangled/inform7" ] || \
   [ ! -x "$INFORM_SRC/inform6/Tangled/inform6" ]; then
    echo "ERROR: could not find the compiled Inform compilers under:" >&2
    echo "       $INFORM_SRC/inform7/Tangled/inform7" >&2
    echo "       $INFORM_SRC/inform6/Tangled/inform6" >&2
    echo "Set INFORM7_SRC to the directory containing the inform/, inweb/ and" >&2
    echo "intest/ checkouts (built with 'make' inside inform/), or point" >&2
    echo "INFORM_HOME at an existing Inform installation." >&2
    exit 1
fi

echo "Staging Inform 7 from $INFORM_SRC into $INSTALL_DIR"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/share/inform7/Compilers"

# Compilers: the new inform7 binary plays the role the old 'ni' did, and the
# inform6 binary is the same tool as before (just a newer build).
cp "$INFORM_SRC/inform7/Tangled/inform7" "$INSTALL_DIR/share/inform7/Compilers/ni"
cp "$INFORM_SRC/inform6/Tangled/inform6" "$INSTALL_DIR/share/inform7/Compilers/inform6"
chmod +x "$INSTALL_DIR/share/inform7/Compilers/ni" \
         "$INSTALL_DIR/share/inform7/Compilers/inform6"

# Built-in material: Standard Rules, English Language, Basic Inform and the
# Inter-based Kits (WorldModelKit, CommandParserKit, ...). This also contains
# the trace_actions machinery TextWorld relies on, so -- unlike 6M62 -- no
# Actions.i6t patching is needed.
rm -rf "$INSTALL_DIR/share/inform7/Internal"
cp -R "$INFORM_SRC/inform7/Internal" "$INSTALL_DIR/share/inform7/Internal"

echo "Staged Inform 7:"
"$INSTALL_DIR/share/inform7/Compilers/ni" -version
