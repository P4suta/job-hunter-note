DESTINATION ?= platform=iOS Simulator,name=iPhone 18 Pro
DERIVED_DATA ?= .build-output/Xcode
PACKAGE_BUILD ?= .build-output/Swift
SCHEME = JobHunterNote
PROJECT = JobHunterNote.xcodeproj
ARCHIVE_PATH ?= .build-output/JobHunterNote.xcarchive
ARCHIVED_APP = $(ARCHIVE_PATH)/Products/Applications/JobHunterNote.app
ASC = mise x github:rorkai/App-Store-Connect-CLI@6.6.1 -- asc
SCREENSHOTS_DIR ?= store/screenshots/ja

.PHONY: check lint unit simulator tsan mutation archive metadata store-media store-capture
check: lint unit simulator

lint:
	xcrun swift-format lint --strict --recursive App Sources Tests AppTests AppUITests Scripts Package.swift
	xcrun swift Scripts/VerifySystemControls.swift
	plutil -lint App/Info.plist App/PrivacyInfo.xcprivacy

unit:
	swift test --jobs 4 --scratch-path "$(PACKAGE_BUILD)"

tsan:
	swift test --sanitize=thread --jobs 2 --scratch-path "$(PACKAGE_BUILD)-tsan"

mutation:
	@set -eu; \
	package=$$(mktemp -d); \
	trap 'rm -rf "$$package"' EXIT; \
	cp -R Package.swift Sources Tests "$$package/"; \
	cd "$$package"; \
	mise x github:ericodx/swift-mutation-testing@1.7.1 -- swift-mutation-testing run . \
		--sources-path Sources --target JobJournalTests --operator-tier experimental \
		--concurrency 1 --timeout 30 --no-cache --no-warm-sandbox \
		--min-score 100 --max-integrity-warnings 0 --output result.json; \
	mise x jaq@3.1.2 -- jaq -e \
		'[.files[].mutants[].status] | any(. == "Killed") and all(. == "Killed" or . == "CompileError")' result.json

simulator:
	xcodebuild -quiet -jobs 4 -project "$(PROJECT)" -scheme "$(SCHEME)" -destination "$(DESTINATION)" -derivedDataPath "$(DERIVED_DATA)" -parallel-testing-enabled NO test

store-capture:
	DERIVED_DATA="$(DERIVED_DATA)" SCREENSHOTS_DIR="$(SCREENSHOTS_DIR)" bash Scripts/capture-store.sh "$(DEVICE)" "$(PROFILE)"

archive:
	xcodebuild -quiet -jobs 4 -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration Release \
		-destination 'generic/platform=iOS' -archivePath "$(ARCHIVE_PATH)" -derivedDataPath "$(DERIVED_DATA)" \
		$(if $(DEVELOPMENT_TEAM),DEVELOPMENT_TEAM="$(DEVELOPMENT_TEAM)",CODE_SIGNING_ALLOWED=NO) archive
	test "$$(plutil -extract CFBundleIdentifier raw "$(ARCHIVED_APP)/Info.plist")" = app.miraisagashi.jobnote
	plutil -lint "$(ARCHIVED_APP)/PrivacyInfo.xcprivacy"
	cmp App/Resources/Lucide-LICENSE.txt "$(ARCHIVED_APP)/Lucide-LICENSE.txt"
	xcrun dwarfdump --uuid "$(ARCHIVED_APP)/JobHunterNote"
	$(if $(DEVELOPMENT_TEAM),codesign --verify --strict "$(ARCHIVED_APP)")

store-media:
	xcrun swift Scripts/VerifyStoreMedia.swift --screenshots-dir "$(SCREENSHOTS_DIR)"
	bash Scripts/test-store-media.sh "$(SCREENSHOTS_DIR)/ipad/02-deadline-detail.png"

metadata: store-media
	$(ASC) metadata validate --dir store/metadata
	$(ASC) screenshots validate --path "$(SCREENSHOTS_DIR)/iphone" --device-type IPHONE_61
	$(ASC) screenshots validate --path "$(SCREENSHOTS_DIR)/iphone-large" --device-type IPHONE_69
	$(ASC) screenshots validate --path "$(SCREENSHOTS_DIR)/iphone-duo" --device-type IPHONE_DUO
	$(ASC) screenshots validate --path "$(SCREENSHOTS_DIR)/ipad" --device-type IPAD_PRO_3GEN_129
