# Database

Supabase project files: `config.toml` (local stack), `migrations/` (one timestamped SQL file per change, applied in order), `seed.sql` (demo data after the migrations), `functions/` (Deno Edge Functions, one folder per function), `tests/database/` (pgTAP tests, one file per table, policy or RPC).

Commands are in the root `Makefile` (`make db-start db-reset db-test`); linking and pushing to the hosted projects is described in the root `README.md`.
