#!/bin/sh
set -e

SDK="${1:?usage: build-local.sh /path/to/openwrt-sdk-25.12.5-ramips-mt7621}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$SDK/package/happwrt" "$SDK/package/luci-app-happwrt"
cp -r "$ROOT/happwrt/." "$SDK/package/happwrt/"
cp -r "$ROOT/luci-app-happwrt/." "$SDK/package/luci-app-happwrt/"

cd "$SDK"
./scripts/feeds update -a
./scripts/feeds install -a
make package/happwrt/compile V=s
make package/luci-app-happwrt/compile V=s

echo "packages are in $SDK/bin/packages/"
