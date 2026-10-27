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

.PHONY: project build test uitest e2e lint db-start db-stop db-reset db-test seed-demo seed-load perf-report \
	perf-concurrency functions-serve functions-check invite-links invoice-reading-live

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
