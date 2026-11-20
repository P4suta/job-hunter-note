# Prepare the store submission

The iOS release candidate is version 1.0, build 2, with bundle identifier `app.miraisagashi.jobnote`.
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

## Screenshots and artwork

The [Japanese screenshots](screenshots/ja/) show real journal records on each simulator display.
The iPhone 18 Pro images measure 1206 × 2622 pixels and the iPhone 18 Pro Max images measure 1320 × 2868 pixels.
The folded iPhone Duo shows the deadline list and detail at 1398 × 2034 pixels.
The unfolded Duo shows employers and submission history together at 2853 × 2007 pixels.
The 13-inch iPad shows employer history in portrait at 2064 × 2752 pixels and the selected deadline in landscape at 2752 × 2064 pixels.
Apple lists the accepted dimensions in its [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).

Build the test runner once and select a booted simulator for each display.
Use `iphone`, `iphone-large`, `duo-outer`, `duo-inner`, or `ipad` for `PROFILE`.
Use [hinge](https://github.com/artemnovichkov/hinge/tree/v0.3.1) to fold or unfold the Duo before capturing the corresponding display.
The test loads a fictional journal into an isolated store and waits for each selected record to appear.
The capture command reads the full simulator display while the test holds the screen.

```sh
xcodebuild -project JobHunterNote.xcodeproj -scheme JobHunterNote \
  -destination "id=$SIMULATOR_ID" -derivedDataPath .build-output/Xcode build-for-testing
make store-capture DEVICE="$SIMULATOR_ID" PROFILE=ipad
```

The [product page header](artwork/ja/product-page-header.png) shows the calendar and the [search result](artwork/ja/search-results.png) highlights submission history.
Both compositions use the safe areas from Apple's [creative asset templates](https://developer.apple.com/app-store/asset-best-practices/).
Render the editable [drawing](../Scripts/RenderStoreArtwork.swift) with `xcrun swift Scripts/RenderStoreArtwork.swift`.
Run `make metadata` to check the opaque exports, upright Japanese text, both split-view columns, and screenshot dimensions.

## Archive

Run `make check`, `make tsan`, `make mutation`, and `make metadata` before preparing a distribution candidate.
Run `make archive` to build and inspect an unsigned arm64 archive for iOS.
With an installed signing identity and provisioning profile, supply the team identifier to produce a signed archive.

```sh
make archive DEVELOPMENT_TEAM="$APPLE_TEAM_ID" ARCHIVE_PATH=.build-output/AppStore/JobHunterNote-1.0-2.xcarchive
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
