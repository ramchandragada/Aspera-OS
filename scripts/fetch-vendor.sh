#!/bin/bash
# Download pinned vendor .deb packages into vendor/
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/vendor"
mkdir -p "$VENDOR"

download() {
	local url="$1"
	local out="$2"
	echo "Fetching $url"
	curl -fL --retry 3 --retry-delay 2 -o "$out" "$url"
	ls -lh "$out"
}

# Aspera Hub
download \
	"https://github.com/ramchandragada/AsperaDock/releases/download/v0.5.53/asperadock_0.5.53_amd64.deb" \
	"$VENDOR/asperadock_0.5.53_amd64.deb"

# TuxGenie
download \
	"https://github.com/ramchandragada/tuxgenie/releases/download/v7.3.1/tuxgenie_7.3.1_all.deb" \
	"$VENDOR/tuxgenie_7.3.1_all.deb"

# AnyDesk
download \
	"https://download.anydesk.com/linux/anydesk_8.0.4-1_amd64.deb" \
	"$VENDOR/anydesk_8.0.4-1_amd64.deb"

# Google Chrome (stable amd64)
download \
	"https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" \
	"$VENDOR/google-chrome-stable_current_amd64.deb"

echo
echo "Vendor packages ready:"
ls -lh "$VENDOR"/*.deb
