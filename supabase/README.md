# Database

Supabase project files: `config.toml` (local stack), `migrations/` (one timestamped SQL file per change, applied in order), `seed.sql` (runs after the migrations on every reset; empty for now), `seed-demo.sql` (the demo clinic from the design, MS-109), `functions/` (Deno Edge Functions, one folder per function), `tests/database/` (pgTAP tests, one file per table, policy or RPC).

Commands are in the root `Makefile` (`make db-start db-reset db-test seed-demo`; `make db-reset seed-demo` gives a fresh demo clinic); linking and pushing to the hosted projects is described in the root `README.md`.
