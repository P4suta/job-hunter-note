#!/usr/bin/env bash
set -euo pipefail

original=${1:?Landscape screenshot required}
work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

reject() {
	local fixture=$1 diagnostic=$2 result
	if result=$(xcrun swift Scripts/VerifyStoreMedia.swift "${fixture}" 2>&1); then
		echo "Invalid screenshot passed: ${fixture}" >&2
		return 1
	fi
	if [[ ${result} != *"${diagnostic}"* ]]; then
		printf '%s\n' "${result}" >&2
		return 1
	fi
}

magick "${original}" -rotate 180 "PNG24:${work}/inverted.png"
reject "${work}/inverted.png" 'missing upright'

dimensions=$(magick identify -format '%w %h' "${original}")
read -r width height <<<"${dimensions}"

check_edge() {
	local edge=$1 rectangle=$2
	magick "${original}" -fill black -stroke none -draw "rectangle ${rectangle}" "PNG24:${work}/${edge}.png"
	reject "${work}/${edge}.png" 'black display edge'
}

check_edge top "0,0 $((width - 1)),7"
check_edge bottom "0,$((height - 8)) $((width - 1)),$((height - 1))"
check_edge left "0,0 7,$((height - 1))"
check_edge right "$((width - 8)),0 $((width - 1)),$((height - 1))"
echo 'Rejected upside-down text and an eight-pixel black band on each display edge.'
