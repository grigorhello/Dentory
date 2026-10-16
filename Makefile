SCHEME := MediSave
PROJECT := MediSave.xcodeproj
LPAREN := (
SIM_NAME ?= iPhone 16
# Newest installed runtime that has $(SIM_NAME), matched as plain text so names like "iPad Pro 11-inch (M4)" work.
# xcodebuild's default (latest SDK) may not include the device.
SIM_ID ?= $(shell xcrun simctl list devices available | grep -F "    $(SIM_NAME) $(LPAREN)" | tail -1 | grep -oE '[0-9A-F-]{36}')
SIM_DESTINATION ?= platform=iOS Simulator,id=$(SIM_ID)
SPM_DIR ?= .build/spm
# CI sets this to YES so any compiler warning fails the build.
WARNINGS_AS_ERRORS ?= NO
# CI sets this to -onlyUsePackageVersionsFromResolvedFile so it builds the committed Package.resolved.
SPM_FLAGS ?=

XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
	-clonedSourcePackagesDirPath $(SPM_DIR) $(SPM_FLAGS) \
	WARNINGS_AS_ERRORS=$(WARNINGS_AS_ERRORS)

# Stops test runs early when no simulator matched SIM_NAME (skipped when SIM_DESTINATION is set by hand).
CHECK_SIM = $(if $(filter %id=,$(SIM_DESTINATION)),$(error No available simulator named "$(SIM_NAME)". See: xcrun simctl list devices available))

.PHONY: project build test uitest lint db-start db-stop db-reset db-test functions-serve functions-check

project:
	xcodegen generate

build:
	$(XCODEBUILD) -destination 'generic/platform=iOS Simulator' build

test:
	$(CHECK_SIM)
	$(XCODEBUILD) -destination '$(SIM_DESTINATION)' -only-testing:MediSaveTests test

uitest:
	$(CHECK_SIM)
	$(XCODEBUILD) -destination '$(SIM_DESTINATION)' -only-testing:MediSaveUITests test

lint:
	swiftlint lint --strict

# Local Supabase stack (Docker). Studio: http://127.0.0.1:54323, API: http://127.0.0.1:54321.
db-start:
	supabase start

db-stop:
	supabase stop

# Drops the local database, applies supabase/migrations in order, then supabase/seed.sql.
db-reset:
	supabase db reset

# Runs the pgTAP tests in supabase/tests against the local database.
db-test:
	supabase test db

functions-serve:
	supabase functions serve

# Type-checks every Edge Function (needs Deno: brew install deno).
functions-check:
	deno check supabase/functions/*/index.ts
