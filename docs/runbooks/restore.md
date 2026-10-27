# Backups and restore

How the hosted database is backed up, the restore drill MS-150 (#121) asks for, and what to do when production has to
be restored for real. Everything here is done by Grigor in the Supabase dashboard; nothing in CI or the build thread
touches a hosted project's backups.

## What a backup holds

A Supabase backup is the database, whole: every clinic's rows and ledger, the Auth users with their password hashes,
the Vault secrets, the scheduled jobs (`cron.job`), the migration history and the Storage metadata (`storage.objects`,
one row per file).

It does not hold:

- **The Storage files themselves**: invoice pages (`invoices`), clinic logos (`logos`) and export zips (`exports`). A
  restored project lists them but cannot serve them, and a file deleted by mistake cannot be brought back. The ledger,
  the stock and every invoice's lines are rows, so they are all in the backup; what is missing is the photo of an
  invoice and the logo, both of which a clinic can upload again. Kept as is for the pilot (decisions log, 2026-10-27);
  the option, if Grigor wants the files too, is a weekly copy of the `invoices` and `logos` buckets to storage he owns
  over Supabase's S3 endpoint (Storage › Settings › S3 access keys, then `rclone sync`).
- **The Edge Functions and their secrets**, the Auth settings (site URL, redirect URLs, SMTP), the API keys and the
  project's other settings. An in-place restore leaves them as they are; a new project starts without them.

## Turning them on (Grigor, once)

1. **Pro plan.** Organization › Billing › Change subscription plan › Pro. Every project of the organization then gets a
   daily backup, kept 7 days (Database › Backups › Scheduled backups), staging included.
2. **Point-in-time recovery for production.** PITR keeps the write-ahead log, so the database can go back to any second
   of the last 7 days instead of last night's backup. It is a paid add-on and needs a compute size of Small or larger
   (the dashboard says which when it is turned on):
   1. Production project › Project Settings › Compute and Disk: Small, if it is on Micro. The project restarts, a
      minute or two of downtime, so do it outside clinic hours.
   2. Project Settings › Add-ons › Point-In-Time Recovery › Change: 7 days. Once it is on, Supabase stops taking the
      daily backups of that project; PITR replaces them.
   3. Database › Backups › Point in time shows the earliest point it can restore to, which should be minutes after
      turning it on and move back to 7 days over the week.
3. **Staging.** The daily backups of step 1 are enough while staging only holds test data. While the pilot clinic's
   real data lives on staging (until production takes over, `docs/handoff/product-knowledge.md`), a day of its changes
   is what a restore can lose; PITR on staging too closes that gap, at the same price.

## The restore drill

Once before the first clinic is on production, then every six months and after any change to the plan or the add-on.
It restores production into a **new project** and checks it there; it never restores over production, nor over
staging, which holds the pilot clinic. Plan an hour; pick a time when clinics are closed (an evening or a weekend), so
production does not change while the counts are compared. Start a timer at step 2.

**1. Production's figures.** On production, SQL editor, with the clinic's id (`select id, name from clinics;`), run
the five queries of "The checks" below and keep the output. Note the time in UTC.

**2. Restore into a new project.**
- With PITR (step 2 above): production › Database › Backups › Restore to a new project; the noted time (or the
  latest); name `dentory-restore-drill`, the same region, the smallest compute it offers; Restore. The new project is
  billed by the hour until it is deleted.
- With the daily backups only: production › Database › Backups › Scheduled backups › Download the newest. Create the
  project `dentory-restore-drill` (same region, a new database password in the password manager) and load the file
  with `psql` and the new project's session pooler connection string, as Supabase's backup guide describes for a
  downloaded backup (supabase.com/docs, Platform, Backups); it also lists the errors to expect from objects every new
  project already has.

Note how long it took, from Restore (or the download) to the project being healthy.

**3. Stop the scheduled jobs, at once.** The backup carried the four jobs and the Vault, whose `project_url` and
`service_role_key` are production's: left alone, the drill project would call production's functions every minute. In
the drill project's SQL editor:

```sql
select cron.alter_job(jobid, active := false) from cron.job;
select jobname, active from cron.job;
```

All four (`invoice-reading-timeout`, `refresh-product-status`, `send-push`, `weekly-digest`) should say `false`.

**4. The checks**, in the drill project's SQL editor, each compared with production's output from step 1:

```sql
-- 1. Migrations: as many as on production, the same newest
select count(*) as "Migrations", max(version) as "Newest" from supabase_migrations.schema_migrations;

-- 2. Rows per table for the clinic: every table as on production
select c.table_name as "Table",
  (xpath('/row/n/text()', query_to_xml(format(
    'select count(*) as n from public.%I where clinic_id = %L', c.table_name, '<clinic id>'),
    false, true, '')))[1]::text::bigint as "Rows"
from information_schema.columns c
join information_schema.tables t using (table_schema, table_name)
where c.table_schema = 'public' and c.column_name = 'clinic_id' and t.table_type = 'BASE TABLE'
order by 1;

-- 3. Stock equals ledger: no row (every product's batches and open bottles add up to its ledger)
select p.name as "Product", s.quantity as "Stock", coalesce(sum(t.delta), 0) as "Ledger"
from public.products p
join public.product_stock s on s.product_id = p.id
left join public.transactions t on t.product_id = p.id
group by p.id, p.name, s.quantity
having s.quantity <> coalesce(sum(t.delta), 0);

-- 4. Storage: the same number of files per bucket
select bucket_id as "Bucket", count(*) as "Files" from storage.objects group by 1 order by 1;

-- 5. Auth: the same number of accounts
select count(*) as "Auth users" from auth.users;
```

The ledger is checked per product, not per batch: a count's ledger row names the product, not a batch. A difference in
2, 4 or 5 is either a change made on production after the noted time (the newest `created_at` of that table on both
says which) or a failed restore.

Then the files: in the drill project, Storage › `invoices`, open one page, and Storage › `logos`, open the logo. With
no bucket copy (above) they fail to load, as expected; record that.

**5. The app signs in.** Point a Debug build at the drill project: the git-ignored `Config/Secrets.debug.xcconfig`
with the drill project's URL and anon key (Project Settings › API), `make project`, run, and sign in with your own
account and its production password (the password hashes came with the backup). Inventory shows the clinic's products,
as many as row 2's `products` less the archived ones; open a product and its history, Activity and Team. Clinic
settings shows no logo, since its file is not in the backup. Delete `Config/Secrets.debug.xcconfig` afterwards.

**6. Clean up.** Stop the timer and fill in the record below. Delete the drill project (Project Settings › General ›
Delete project): it is a copy of production, the members' names and email addresses included.

## Restoring production for real

When production's data is lost or damaged as a whole (a bad migration, a mistaken bulk update), not for a clinic's own
mistake, which Undo, an adjustment or a count fixes.

1. Find the last good moment: the time just before the damage (the migration's push, the update's time in the
   Postgres logs, or the newest ledger row that is still right).
2. Tell the clinics: Dentory is offline for the restore, and every change made after that moment is gone, including
   the ones a phone sent and saw through; they recount what they changed since.
3. With PITR: Database › Backups › Point in time › that moment › Restore. With the daily backups only: Scheduled
   backups › the newest before the damage › Restore. Either restores production in place: it is offline while it
   runs, and the dashboard shows the progress.
4. Afterwards: the Edge Functions, their secrets and the Storage files are untouched, and the jobs keep running. Check
   the migration list (`supabase migration list` against production): if a migration caused the damage, fix it on a
   branch before pushing anything again. Run checks 3 to 5 and sign in.
5. Storage after an in-place restore: a file uploaded after that moment stays in its bucket without its row (nothing
   shows it); a file deleted after it is gone although its row is back, so that invoice's pages no longer load (its
   lines and receipt are intact).
6. Record it below and in the decisions log, with what the clinics were told.

## Record

| Date | Drill or real | From (project, time or backup) | Into | Restore took | Migrations | Rows per table | Stock equals ledger | Files (rows, loads) | Auth users | App sign-in | Total time | By |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| | | | | | | | | | | | | |
