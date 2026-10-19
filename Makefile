SCHEME := Dentory
PROJECT := Dentory.xcodeproj
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

.PHONY: project build test uitest lint db-start db-stop db-reset db-test seed-demo functions-serve functions-check invite-links

project:
	xcodegen generate

build:
	$(XCODEBUILD) -destination 'generic/platform=iOS Simulator' build

test:
	$(CHECK_SIM)
	$(XCODEBUILD) -destination '$(SIM_DESTINATION)' -only-testing:DentoryTests test

uitest:
	$(CHECK_SIM)
	$(XCODEBUILD) -destination '$(SIM_DESTINATION)' -only-testing:DentoryUITests test

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

# Loads the demo clinic from the design (MS-109) into the local database; run it right after db-reset.
# psql runs inside the database container, so no local Postgres client is needed.
DB_CONTAINER ?= supabase_db_Dentory
seed-demo:
	docker exec -i $(DB_CONTAINER) psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -o /dev/null < supabase/seed-demo.sql

functions-serve:
	supabase functions serve

# Type-checks every Edge Function (needs Deno: brew install deno).
functions-check:
	deno check supabase/functions/*/index.ts

# The local stack has no Resend key, so invite_member writes each invitation email to the function log
# instead of sending it. This prints the links of the last invitations; open one on the simulator with
# `xcrun simctl openurl booted "dentory://invite?token=<token>"` (MS-112).
EDGE_CONTAINER ?= supabase_edge_runtime_Dentory
invite-links:
	@docker logs $(EDGE_CONTAINER) 2>&1 | grep -oE 'invite\?token=[A-Za-z0-9_%-]+' | tail -5 | sed 's/^/dentory:\/\//'
