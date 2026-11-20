# Develop and test the app

Track employers, deadlines, and submissions in Japanese on iPhone, iPhone Duo, and iPad.
Records stay on the device.
The optional example uses separate records that disappear when you close it.

## Run the app

Open `JobHunterNote.xcodeproj` in Xcode 27.2, select the `JobHunterNote` scheme and a simulator, and choose Run.
For a physical device, select your development team in Signing & Capabilities.
Choose `入力例で試す` on the empty `締切` tab to try the December 4 example.

## Check the app

Run `make lint unit` to check Swift formatting, app metadata, and the journal rules.
Run `xcrun simctl list devices available` to find the identifier of an installed simulator.
Replace `SIMULATOR_ID` in `make check DESTINATION='id=SIMULATOR_ID'` to run the full suite on that device.
To check an iPhone Duo fold, use the [hinge CLI](https://github.com/artemnovichkov/hinge/tree/v0.3.1) to move the simulated hinge through 0, 90, and 180 degrees while editing the title of a sample deadline.
Check that the unsaved title survives each change and that `キャンセル` restores the saved title.
Run `make tsan` to check concurrent reads and writes with Thread Sanitizer.
Run `make mutation` with mise installed to check whether the journal tests detect changes to production logic.
The mutation check copies the Swift package to a temporary directory and runs one worker.
Keep package tests in named Swift Testing suites so the mutation runner can select the tests for each change.

## Reminders

Enable the reminder when saving a deadline and grant notification access when iOS asks.
The app groups unfinished deadlines with reminders by date and schedules one notification for 19:00 on the preceding local day.
Opening a notification shows the unfinished deadlines for its date.
The app updates the schedule after changes and when it returns to the foreground.
When reminder dates exceed the available notification slots, the earliest dates take priority.

## Project files

The Xcode project includes the app, its simulator tests, and the local Swift package.
After changing target membership, regenerate the project from `project.yml` with XcodeGen 2.46.0.
The app bundles the [Lucide and Feather icon licenses](../App/Resources/Lucide-LICENSE.txt).
The [App Store preparation guide](../store/README.md) covers product information, screenshot capture, and archiving.
