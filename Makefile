SCHEME := MediSave
PROJECT := MediSave.xcodeproj
SIM_NAME ?= iPhone 16
# Newest installed runtime that has $(SIM_NAME); xcodebuild's default (latest SDK) may not include it.
SIM_ID ?= $(shell xcrun simctl list devices available | grep -E '^ +$(SIM_NAME) .[0-9A-F]{8}-' | tail -1 | grep -oE '[0-9A-F-]{36}')
SIM_DESTINATION ?= platform=iOS Simulator,id=$(SIM_ID)
SPM_DIR ?= .build/spm
# CI sets this to YES so any compiler warning fails the build.
WARNINGS_AS_ERRORS ?= NO

XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
	-clonedSourcePackagesDirPath $(SPM_DIR) \
	WARNINGS_AS_ERRORS=$(WARNINGS_AS_ERRORS)

.PHONY: project build test uitest lint

project:
	xcodegen generate

build:
	$(XCODEBUILD) -destination 'generic/platform=iOS Simulator' build

test:
	$(XCODEBUILD) -destination '$(SIM_DESTINATION)' -only-testing:MediSaveTests test

uitest:
	$(XCODEBUILD) -destination '$(SIM_DESTINATION)' -only-testing:MediSaveUITests test

lint:
	swiftlint lint --strict
