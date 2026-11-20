#!/usr/bin/env bash
set -euo pipefail

original=${1:?Landscape screenshot required}
work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

reject() {
	local fixture=$1 diagnostic=$2
	if xcrun swift Scripts/VerifyStoreMedia.swift "${fixture}" >"${work}/result" 2>&1; then
		echo "Invalid screenshot passed: ${fixture}" >&2
		return 1
	fi
	if ! grep -Fq "${diagnostic}" "${work}/result"; then
		cat "${work}/result" >&2
		return 1
	fi
}

sips --rotate 180 "${original}" --out "${work}/inverted.png" >/dev/null
reject "${work}/inverted.png" 'missing upright'
sips --padToHeightWidth 2064 3600 --padColor 000000 "${original}" --out "${work}/padded.png" >/dev/null
reject "${work}/padded.png" 'black display edge'
echo 'Rejected upside-down text and black display edges.'
