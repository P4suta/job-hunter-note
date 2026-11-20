DESTINATION ?= platform=iOS Simulator,name=iPhone 18 Pro
DERIVED_DATA ?= .build-output/Xcode
PACKAGE_BUILD ?= .build-output/Swift
SCHEME = JobHunterNote
PROJECT = JobHunterNote.xcodeproj
ARCHIVE_PATH ?= .build-output/JobHunterNote.xcarchive
ARCHIVED_APP = $(ARCHIVE_PATH)/Products/Applications/JobHunterNote.app

.PHONY: check lint unit simulator tsan mutation archive metadata
check: lint unit simulator

lint:
	xcrun swift-format lint --strict --recursive App Sources Tests AppTests AppUITests Package.swift
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

archive:
	xcodebuild -quiet -jobs 4 -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration Release \
		-destination 'generic/platform=iOS' -archivePath "$(ARCHIVE_PATH)" -derivedDataPath "$(DERIVED_DATA)" \
		$(if $(DEVELOPMENT_TEAM),DEVELOPMENT_TEAM="$(DEVELOPMENT_TEAM)",CODE_SIGNING_ALLOWED=NO) archive
	test "$$(plutil -extract CFBundleIdentifier raw "$(ARCHIVED_APP)/Info.plist")" = app.miraisagashi.jobnote
	plutil -lint "$(ARCHIVED_APP)/PrivacyInfo.xcprivacy"
	cmp App/Resources/Lucide-LICENSE.txt "$(ARCHIVED_APP)/Lucide-LICENSE.txt"
	xcrun dwarfdump --uuid "$(ARCHIVED_APP)/JobHunterNote"
	$(if $(DEVELOPMENT_TEAM),codesign --verify --strict "$(ARCHIVED_APP)")

metadata:
	mise x github:rorkai/App-Store-Connect-CLI@6.6.1 -- asc metadata validate --dir store/metadata
