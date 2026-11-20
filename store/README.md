# Prepare the store submission

The initial iOS version is 1.0, build 1, with bundle identifier `app.miraisagashi.jobnote`.
The app supports iPhone and iPad and uses Japanese as its primary language.

## Product information

The [app information](metadata/app-info/ja.json) and [version information](metadata/version/1.0/ja.json) use the App Store Connect CLI metadata format.
Run `make metadata` to check the product fields, character limits, and screenshot files for each display size.
Once the support site is live, run the URL check from the repository root.

```sh
mise x github:rorkai/App-Store-Connect-CLI@6.6.1 -- asc metadata validate --dir store/metadata --check-urls
```

The app stores the journal on the device and schedules local notifications.
Its privacy response is **Data Not Collected**.
The app includes its privacy manifest and a link to the [privacy policy](https://job-hunter-note.yasunobu.dev/privacy/).
Website visitors can contact the developer through [support](https://job-hunter-note.yasunobu.dev/support/).

## Screenshots

The [Japanese screenshots](screenshots/ja/) show the deadline list, deadline details, and employer selection.
The iPhone 18 Pro images measure 1206 × 2622 pixels and the iPhone 18 Pro Max images measure 1320 × 2868 pixels.
The iPhone Duo images show the list and details on the 1398 × 2034 outer display and employer selection on the 2853 × 2007 inner display.
The 13-inch iPad images measure 2064 × 2752 pixels in portrait and 2752 × 2064 pixels in landscape.
Apple lists the accepted sizes in its [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).

To capture the images again, run the sample notification test on each simulator.
Use a fresh result bundle path for each run.
The test attaches an image of each screen to the result bundle.

```sh
xcodebuild -project JobHunterNote.xcodeproj -scheme JobHunterNote \
  -destination "id=$SIMULATOR_ID" -parallel-testing-enabled NO \
  -only-testing:AppUITests/JobSearchTests/testSampleNotificationOpensTheDayAndCompletesOneOfTwo \
  -resultBundlePath "$RESULT_BUNDLE" test
xcrun xcresulttool export attachments --path "$RESULT_BUNDLE" \
  --filter 'Store*.png' --output-path "$SCREENSHOT_DIRECTORY"
```

For the iPhone Duo inner display, use [hinge](https://github.com/artemnovichkov/hinge/tree/v0.3.1) to unfold the simulator once the sample app is running.
Read the active display identifier, then capture the full display while the employer choices are visible.
Use ImageMagick to remove the alpha channel from the opaque capture.

```sh
hinge --device "$SIMULATOR_ID" set 180
xcrun devicectl device info displays --device "$SIMULATOR_ID"
xcrun simctl io "$SIMULATOR_ID" screenshot --display="$DISPLAY_ID" "$SCREENSHOT_DIRECTORY/inner.png"
magick "$SCREENSHOT_DIRECTORY/inner.png" -alpha off "PNG24:$SCREENSHOT_DIRECTORY/inner-employer-selection.png"
```

## Archive

Run `make check`, `make tsan`, `make mutation`, and `make metadata` before preparing a distribution candidate.
Run `make archive` to build and inspect an unsigned arm64 archive for iOS.
With an installed signing identity and provisioning profile, supply the team identifier to produce a signed archive.

```sh
make archive DEVELOPMENT_TEAM="$APPLE_TEAM_ID" ARCHIVE_PATH=.build-output/AppStore/JobHunterNote-1.0-1.xcarchive
```

The archive target checks the bundle identifier, privacy manifest, and bundled icon license.
It verifies the signature when a team identifier is present.
App Store distribution requires a distribution signing identity and profile for the bundle identifier at export.
Use a fresh build number when uploading another build of the same version.

## Notes for the reviewer

The app works without an account.
On the empty deadlines tab, choose `入力例で試す` to load a temporary example with an assessment due December 4.
Use `締切を追加` to add a deadline and `完了にする` to complete it.
Open `応募先` and select the employer to see the submission history.
The bell in the example opens a sample notification without waiting for a scheduled delivery.
Closing the example returns to the saved journal.
