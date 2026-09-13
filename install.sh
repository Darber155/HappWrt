#!/bin/sh
set -e

REPO="Darber155/HappWrt"
BASE="https://github.com/${REPO}/releases/latest/download"
TMP="/tmp/happwrt-install"
SUBSCRIPTION="$1"

[ -f /etc/openwrt_release ] && . /etc/openwrt_release
ARCH="${DISTRIB_ARCH:-unknown}"

if [ "$ARCH" != "mipsel_24kc" ] && [ "$HAPPWRT_FORCE" != "1" ]; then
	echo "HappWRT: this release targets mipsel_24kc (Asus RT-AX53U), detected: $ARCH"
	echo "Set HAPPWRT_FORCE=1 to install anyway."
	exit 1
fi

if [ "$(id -u)" != "0" ]; then
	echo "HappWRT: must run as root"
	exit 1
fi

mkdir -p "$TMP"

fetch() {
	if command -v uclient-fetch >/dev/null 2>&1; then
		uclient-fetch -q -O "$2" "$1"
	elif command -v curl >/dev/null 2>&1; then
		curl -fsSL -o "$2" "$1"
	elif command -v wget >/dev/null 2>&1; then
		wget -q -O "$2" "$1"
	else
		echo "HappWRT: no downloader (uclient-fetch/curl/wget)" >&2
		return 1
	fi
}

echo "HappWRT: downloading packages for $ARCH"

if command -v apk >/dev/null 2>&1; then
	fetch "$BASE/happwrt.apk" "$TMP/happwrt.apk"
	fetch "$BASE/luci-app-happwrt.apk" "$TMP/luci-app-happwrt.apk"
	apk add --allow-untrusted "$TMP/happwrt.apk" "$TMP/luci-app-happwrt.apk"
elif command -v opkg >/dev/null 2>&1; then
	fetch "$BASE/happwrt.ipk" "$TMP/happwrt.ipk"
	fetch "$BASE/luci-app-happwrt.ipk" "$TMP/luci-app-happwrt.ipk"
	opkg install "$TMP/happwrt.ipk" "$TMP/luci-app-happwrt.ipk"
else
	echo "HappWRT: neither apk nor opkg found" >&2
	exit 1
fi

if [ -n "$SUBSCRIPTION" ]; then
	uci set "happwrt.main.subscription_url=$SUBSCRIPTION"
	uci set "happwrt.main.enabled=1"
	uci commit happwrt
	echo "HappWRT: subscription set and service enabled"
fi

echo "HappWRT: installed"
echo "Open LuCI -> Services -> HappWRT"
