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
# Optional: keep build output in this folder (agents set it to their scratch directory) instead of Xcode's default.
DERIVED_DATA ?=

XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
	-clonedSourcePackagesDirPath $(SPM_DIR) $(SPM_FLAGS) $(if $(DERIVED_DATA),-derivedDataPath $(DERIVED_DATA)) \
	WARNINGS_AS_ERRORS=$(WARNINGS_AS_ERRORS)

# Stops test runs early when no simulator matched SIM_NAME (skipped when SIM_DESTINATION is set by hand).
CHECK_SIM = $(if $(filter %id=,$(SIM_DESTINATION)),$(error No available simulator named "$(SIM_NAME)". See: xcrun simctl list devices available))

.PHONY: project build test uitest e2e lint release-check archive upload testflight db-start db-stop db-reset db-test \
	seed-demo seed-load seed-catalog catalog-check seed-demo-history demo-history-check perf-report perf-concurrency \
	functions-serve functions-check \
	invite-links invoice-reading-live

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

# The end-to-end flows (MS-136, DentoryE2ETests, run by the DentoryE2E scheme) on the local stack: the demo clinic
# seeded afresh, then the flows in the simulator against it. A Debug build talks to the local stack unless
# Config/Secrets.debug.xcconfig points it elsewhere, so that file stops the run. The stack must run from this checkout
# (`make db-start`) to serve these Edge Functions, among them extract_invoice reading the fixture invoice.
e2e:
	$(CHECK_SIM)
	@if [ -f Config/Secrets.debug.xcconfig ]; then \
		echo "Config/Secrets.debug.xcconfig points Debug builds away from the local stack: move it aside first."; exit 1; fi
	@functions=$$(docker inspect $(EDGE_CONTAINER) --format '{{range .Mounts}}{{println .Destination}}{{end}}' \
		2>/dev/null | grep '/supabase/functions$$'); [ -n "$$functions" ] && [ "$$functions" -ef supabase/functions ] \
		|| { echo "The local stack serves another checkout's Edge Functions: supabase stop, then make db-start here."; \
		exit 1; }
	supabase db reset
	$(MAKE) seed-demo
	$(subst -scheme $(SCHEME) ,-scheme DentoryE2E ,$(XCODEBUILD)) -destination '$(SIM_DESTINATION)' test

lint:
	swiftlint lint --strict

# Release builds for TestFlight and the App Store (MS-152, docs/runbooks/release.md): from a fresh clone of the default
# branch on the Mac that ships, signed through the Apple account signed into Xcode. They talk to the production
# project, whose ref (public: it is part of the API URL) is PRODUCTION_REF; its URL and anon key are in the git-ignored
# Config/Secrets.xcconfig. The archive and the export land in RELEASE_DIR (git-ignored).
PRODUCTION_REF := xjtmoctrodgtnsxafeps
RELEASE_DIR ?= build/release
ARCHIVE_PATH = $(RELEASE_DIR)/Dentory.xcarchive
# The build number App Store Connect sees: the default branch's commit count at the archived commit, higher after
# every merge. BUILD_NUMBER=<n> overrides it (90.1 uploads commit 90 a second time).
BUILD_NUMBER ?= $(shell /usr/bin/git rev-list --count HEAD 2>/dev/null)
SECRETS := Config/Secrets.xcconfig
# The last value $(SECRETS) gives the setting $(1), without its `//` comment and spaces, as Xcode reads it.
SECRET_VALUE = sed -n 's|^[[:space:]]*$(1)[[:space:]]*=||p' $(SECRETS) | tail -1 | sed -e 's|//.*||' \
	-e 's|^[[:space:]]*||' -e 's|[[:space:]]*$$||'

# Stops a release before anything is built unless it talks to production: PRODUCTION_REF set, and $(SECRETS) with
# production's URL, written https:/$()/<ref>.supabase.co as Secrets.example.xcconfig shows, and an anon key. A legacy
# anon key (a JWT) must name production's ref and the anon role, so neither another project's key nor the service role
# key ships; a publishable key (sb_publishable_…) passes. The shell reads the key and never prints it.
release-check:
	@[ -n "$(PRODUCTION_REF)" ] || { echo "PRODUCTION_REF is empty: set it in the Makefile to production's ref."; exit 1; }
	@[ -f $(SECRETS) ] || { echo "No $(SECRETS): write production's URL and anon key into it (release runbook)."; exit 1; }
	@url=$$($(call SECRET_VALUE,SUPABASE_URL)); [ "$$url" = 'https:/$$()/$(PRODUCTION_REF).supabase.co' ] || { \
		echo "SUPABASE_URL in $(SECRETS) is not production's: write https:/\$$()/$(PRODUCTION_REF).supabase.co."; exit 1; }
	@key=$$($(call SECRET_VALUE,SUPABASE_ANON_KEY)); \
	[ -n "$$key" ] || { echo "SUPABASE_ANON_KEY in $(SECRETS) is empty: write production's anon key into it."; exit 1; }; \
	case "$$key" in sb_publishable_*) exit 0 ;; esac; \
	claims=$$(printf '%s' "$$key" | cut -s -d . -f 2 | tr '_-' '/+'); \
	while [ $$(( $${#claims} % 4 )) -ne 0 ]; do claims="$$claims="; done; \
	claims=$$(printf '%s' "$$claims" | base64 -d 2>/dev/null); \
	printf '%s' "$$claims" | grep -Eq '"role" *: *"anon"' && \
		printf '%s' "$$claims" | grep -Eq '"ref" *: *"$(PRODUCTION_REF)"' || { \
		echo "SUPABASE_ANON_KEY in $(SECRETS) is not production's anon key."; exit 1; }

# A Release archive for App Store Connect: version MARKETING_VERSION (project.yml), build BUILD_NUMBER, signed
# automatically (-allowProvisioningUpdates lets Xcode create the distribution certificate and profile).
archive: release-check
	@case "$(BUILD_NUMBER)" in '' | *[!0-9.]*) \
		echo "The build number \"$(BUILD_NUMBER)\" is not a number: pass BUILD_NUMBER=<n>."; exit 1 ;; esac
	@echo "Archiving $$(/usr/bin/git rev-parse --short HEAD) as build $(BUILD_NUMBER), for $(PRODUCTION_REF)."
	$(XCODEBUILD) -configuration Release -destination 'generic/platform=iOS' -archivePath $(ARCHIVE_PATH) \
		-allowProvisioningUpdates CURRENT_PROJECT_VERSION=$(BUILD_NUMBER) archive

# Exports the archive with Config/ExportOptions.plist, which uploads it to App Store Connect with its symbols through
# the Apple account signed into Xcode; TestFlight shows the build once Apple has processed it.
upload:
	@[ -d $(ARCHIVE_PATH) ] || { echo "No archive at $(ARCHIVE_PATH): run make archive first."; exit 1; }
	xcodebuild -exportArchive -archivePath $(ARCHIVE_PATH) -exportOptionsPlist Config/ExportOptions.plist \
		-exportPath $(RELEASE_DIR)/export -allowProvisioningUpdates

# The whole upload: archive (release-check first), then upload.
testflight: archive
	@$(MAKE) --no-print-directory upload

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

# The load-test clinic of MS-150 (500 products, about 5,000 ledger rows over six months) beside the demo clinic or on its
# own; run it right after db-reset (or after seed-demo). Local stack only.
seed-load:
	docker exec -i $(DB_CONTAINER) psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -o /dev/null < supabase/seed-load.sql

# A starting catalog (supabase/catalogs/README.md) into one clinic, local or hosted: CLINIC_ID=<uuid>,
# CATALOG=<a file in supabase/catalogs> (general-practice), TARGET=local (the local stack) or TARGET=linked (the
# project this clone is linked to, through the Management API with the CLI's own login: no key is read or printed).
# Adds only the categories and products the clinic lacks, at 0, and prints how many. TARGET comes from the command
# line only, never from the environment, so a hosted project is written only when asked for.
CATALOG ?= general-practice
TARGET = local
seed-catalog:
	@CLINIC_ID='$(CLINIC_ID)' CATALOG='$(CATALOG)' TARGET='$(TARGET)' sh supabase/catalogs/seed.sh

# The catalog on two new clinics on the local stack, the way seed-catalog runs it, twice each; then what the nightly
# status refresh, first counts and a first delivery do to its products (supabase/catalogs/check.sh). CI runs it after
# the demo seed.
catalog-check:
	DB_CONTAINER=$(DB_CONTAINER) CATALOG=$(CATALOG) sh supabase/catalogs/check.sh

# About six weeks of stock history ending today (supabase/catalogs/README.md, "Demo history") into one clinic that holds
# the general-practice catalog and never stocked it, local or hosted: CLINIC_ID=<uuid>, TARGET=local (the default) or
# TARGET=linked (the project this clone is linked to, through the Management API with the CLI's own login). It prints
# what it will write first and stops on a refusal; DRY_RUN=1 stops there in any case. The ledger is append-only, so the
# history stays in the clinic for good: demo clinics only. TARGET comes from the command line only, as for seed-catalog.
seed-demo-history:
	@CLINIC_ID='$(CLINIC_ID)' TARGET='$(TARGET)' DRY_RUN='$(DRY_RUN)' sh supabase/catalogs/demo-history.sh

# The demo history on a new clinic with the catalog on the local stack, the way seed-demo-history runs it, then its end
# state, a second run and the refusals (supabase/catalogs/demo-history-check.sh). KEEP=1 keeps the clinic to look at in
# the app. CI runs it after catalog-check.
demo-history-check:
	DB_CONTAINER=$(DB_CONTAINER) KEEP=$(KEEP) sh supabase/catalogs/demo-history-check.sh

# How long each of the app's calls takes in the database for the load-test clinic's admin: p50, p95 and the slowest
# of PERF_RUNS runs, in milliseconds (supabase/perf/report.sql). Run it after db-reset and seed-load, before
# perf-concurrency adds to the clinic.
PERF_RUNS ?= 30
perf-report:
	docker exec -i $(DB_CONTAINER) psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -v runs=$(PERF_RUNS) \
		< supabase/perf/report.sql

# PERF_CLIENTS clients start procedures and open bottles of the same products in the load-test clinic at once,
# PERF_TRANSACTIONS changes each (pgbench in the database container), then the ledger is checked against the stock;
# fails on a deadlock or a lost change (supabase/perf/concurrency.sh). Run it after seed-load.
PERF_CLIENTS ?= 8
PERF_TRANSACTIONS ?= 20
perf-concurrency:
	DB_CONTAINER=$(DB_CONTAINER) PERF_CLIENTS=$(PERF_CLIENTS) PERF_TRANSACTIONS=$(PERF_TRANSACTIONS) \
		sh supabase/perf/concurrency.sh

functions-serve:
	supabase functions serve

# Type-checks every Edge Function and runs their unit tests (`*_test.ts`; needs Deno: brew install deno). The tests read
# their fixtures under supabase/ and nothing else.
functions-check:
	deno check supabase/functions/*/index.ts supabase/functions/extract_invoice/live_check.ts
	deno test --allow-read=supabase supabase/functions

# Reads the five fixture invoices with the real Claude API and checks what comes back and how fast (MS-129). Needs
# ANTHROPIC_API_KEY in the environment (it is ignored without one) and spends a few cents; RECORD=1 writes the answers
# over the recorded ones in supabase/functions/extract_invoice/fixtures.
invoice-reading-live:
	deno test --allow-read=supabase --allow-env --allow-net=api.anthropic.com \
		--allow-write=supabase/functions/extract_invoice/fixtures supabase/functions/extract_invoice/live_check.ts

# The local stack has no Resend key, so invite_member writes each invitation email to the function log
# instead of sending it. This prints the links of the last invitations; open one on the simulator with
# `xcrun simctl openurl booted "dentory://invite?token=<token>"` (MS-112).
EDGE_CONTAINER ?= supabase_edge_runtime_Dentory
invite-links:
	@docker logs $(EDGE_CONTAINER) 2>&1 | grep -oE 'invite\?token=[A-Za-z0-9_%-]+' | tail -5 | sed 's/^/dentory:\/\//'
