#!/bin/sh
set -eu
cd "$(dirname "$0")"
if [ "$#" -ne 0 ]; then
    echo 'Usage: ./build.sh' >&2
    exit 2
fi

if [ -L artifacts ]; then
    echo 'Refusing a symlink at artifacts/' >&2
    exit 2
fi
rm -f artifacts/DouyinDisc.dylib
python3 scripts/toolchain.py verify --output reports/local-toolchain.json
python3 scripts/build_dylib.py
