#!/usr/bin/env bash
set -euo pipefail

device=${1:?Simulator identifier required}
profile=${2:?Use iphone, iphone-large, duo-outer, duo-inner, or ipad}
derived=${DERIVED_DATA:-.build-output/Xcode}
output=${SCREENSHOTS_DIR:-store/screenshots/ja}
directory=${profile}
display=()
display_name=
tests=()
case ${profile} in
iphone | iphone-large)
	scenes=(deadlines deadline-detail)
	names=(01-deadlines 02-deadline-detail)
	;;
duo-outer)
	directory=iphone-duo
	display_name=LCD
	scenes=(deadlines deadline-detail)
	names=(01-outer-deadlines 03-outer-deadline-detail)
	;;
duo-inner)
	directory=iphone-duo
	display_name=LCD-1
	scenes=(employers)
	names=(02-inner-employers)
	;;
ipad)
	scenes=(deadline-detail employers)
	names=(02-deadline-detail 01-employers)
	;;
*) exit 64 ;;
esac
for scene in "${scenes[@]}"; do
	case ${scene} in
	deadline-detail) tests+=(-only-testing:AppUITests/StoreCaptureTests/testDeadlineListAndSelectedDetail) ;;
	employers) tests+=(-only-testing:AppUITests/StoreCaptureTests/testEmployerListAndSubmissionHistory) ;;
	*) continue ;;
	esac
done
active_display_id() {
	local active active_name=none display_id
	for _ in {1..12}; do
		if active=$(xcrun devicectl device info displays --device "${device}" -q -j - |
			mise x jaq@3.1.2 -- jaq -er '.result.displays[] | select(.active) | [.name, .displayId] | @tsv'); then
			IFS=$'\t' read -r active_name display_id <<<"${active}"
			if [[ ${active_name} == "${display_name}" ]]; then
				echo "${display_id}"
				return 0
			fi
		fi
		sleep 0.5
	done
	echo "Expected active Duo display ${display_name}, found ${active_name}." >&2
	return 1
}
runner="${derived}/Build/Products/Debug-iphonesimulator/AppUITests-Runner.app"
xcrun simctl install "${device}" "${runner}"
identifier=$(plutil -extract CFBundleIdentifier raw "${runner}/Info.plist")
container=$(xcrun simctl get_app_container "${device}" "${identifier}" data)
marker="${container}/Documents/StoreCapture"
mkdir -p "${marker}" "${output}/${directory}"
work=$(mktemp -d)
trap 'rm -f "${marker}/active"; rm -rf "${work}"' EXIT
for scene in "${scenes[@]}"; do
	rm -f "${marker}/${scene}.ready" "${marker}/${scene}.done"
done
touch "${marker}/active"
xcrun simctl status_bar "${device}" override --time 9:41 --wifiBars 3 --cellularBars 4 --batteryLevel 100 --batteryState discharging
xcrun simctl ui "${device}" appearance light
bundle=("${derived}"/Build/Products/*.xctestrun)
xcodebuild -quiet -xctestrun "${bundle[0]}" -destination "id=${device}" -parallel-testing-enabled NO \
	-testLanguage ja -testRegion JP "${tests[@]}" test-without-building &
test_pid=$!
for index in "${!scenes[@]}"; do
	scene=${scenes[index]}
	while true; do
		if current=$(xcrun simctl get_app_container "${device}" "${identifier}" data 2>/dev/null); then
			marker="${current}/Documents/StoreCapture"
		fi
		if [[ -e ${marker}/${scene}.ready ]]; then break; fi
		if ! kill -0 "${test_pid}" 2>/dev/null; then
			wait "${test_pid}"
			exit 1
		fi
		sleep 0.5
	done
	if [[ -n ${display_name} ]]; then
		display_id=$(active_display_id)
		display=("--display=${display_id}")
	fi
	xcrun simctl io "${device}" screenshot ${display[@]+"${display[@]}"} "${work}/${scene}.png"
	magick "${work}/${scene}.png" -auto-orient -alpha off +repage "PNG24:${work}/${names[index]}.png"
	touch "${marker}/${scene}.done"
done
wait "${test_pid}"
for name in "${names[@]}"; do
	mv "${work}/${name}.png" "${output}/${directory}/${name}.png"
done
