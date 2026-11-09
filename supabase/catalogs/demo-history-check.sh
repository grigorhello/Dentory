#!/bin/sh
# `make demo-history-check`: the demo history (demo-history.sql) on the local stack, run by demo-history.sh as
# `make seed-demo-history` runs it, on a clinic made through clinic_create by a new account as sign-up makes one, with
# the general-practice catalog (seed.sh) and two products of its own with three ledger rows between them, as Grigor's
# tests left "Pen" and "Pain killer" in Smile Groove.
# - A dry run prints what the history would write and writes nothing.
# - The real run ends in the state demo-history-check.sql checks through the admin's own reads (Home, Inventory, To buy,
#   Expiring soon, Activity, Procedures), with the ledger ending at every product's stock, nothing dated after now or
#   before the story, the append-only trigger back on and nothing of the clinic waiting to be pushed or emailed.
# - A second run is refused and writes nothing; so are an unknown clinic id, a malformed one, a clinic without the
#   catalog and a clinic without an active admin.
# The clinics and accounts are removed at the end, and before the start if an earlier run stopped half-way; KEEP=1
# keeps the history's clinic to look at in the app (sign in as demo-history-check@dentory.test, password demohistory).
set -eu

container=${DB_CONTAINER:-supabase_db_Dentory}
keep=${KEEP:-}
here=$(dirname "$0")
user_a=de7a0000-0000-4000-8000-0000000000a1
user_b=de7a0000-0000-4000-8000-0000000000b1
user_c=de7a0000-0000-4000-8000-0000000000c1
unknown=de7a0000-0000-4000-8000-0000000000d1

sql() {
  docker exec -i "$container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q "$@"
}

fail() {
  echo "demo-history-check: $*" >&2
  exit 1
}

# Makes an account (password "demohistory", so KEEP=1 can sign in) and its clinic as sign-up does (clinic_create as the
# signed-in account), and prints the clinic's id.
make_clinic() {
  sql -o /dev/null <<SQL
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token, email_change_token_new, email_change
)
values (
  '$1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '$2',
  extensions.crypt('demohistory', extensions.gen_salt('bf')), now(),
  '{"provider": "email", "providers": ["email"]}', '{}', now(), now(), '', '', '', ''
);
insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
values ('$1', '$1', '$1', 'email', jsonb_build_object('sub', '$1', 'email', '$2', 'email_verified', true), now(), now(),
  now());
begin;
select set_config('request.jwt.claims', json_build_object('sub', '$1', 'role', 'authenticated')::text, true);
set local role authenticated;
select public.clinic_create('$3', 'Toronto', 'CA', 'America/Toronto', '$4');
commit;
SQL
  sql -At -c "select clinic_id from public.memberships where user_id = '$1'"
}

catalog() {
  out=$(CLINIC_ID=$1 TARGET=local sh "$here/seed.sh" 2>&1) || fail "the catalog failed: $out"
}

# The rows of a clinic the history writes, as one line, to see that a refused run wrote nothing.
footprint() {
  sql -At -c "select concat_ws(' ',
    (select count(*) from public.transactions where clinic_id = '$1'),
    (select count(*) from public.stock_actions where clinic_id = '$1'),
    (select count(*) from public.batches where clinic_id = '$1'),
    (select count(*) from public.open_items where clinic_id = '$1'),
    (select count(*) from public.alerts where clinic_id = '$1'),
    (select count(*) from public.to_buy_items where clinic_id = '$1'),
    (select count(*) from public.procedure_events where clinic_id = '$1'),
    (select count(*) from public.procedure_templates where clinic_id = '$1'),
    (select count(*) from public.push_outbox where clinic_id = '$1'),
    (select count(*) from public.products where clinic_id = '$1' and supplier is not null),
    (select count(*) from public.products where clinic_id = '$1' and archived_at is not null))"
}

# Runs the history through demo-history.sh and expects it refused with a sentence holding $2.
expect_refused() {
  out=$(CLINIC_ID=$1 TARGET=local sh "$here/demo-history.sh" 2>&1) && fail "$3 was not refused: $out"
  case $out in *"$2"*) ;; *) fail "$3 was refused otherwise: $out" ;; esac
  echo "$3 is refused."
}

# The clinics hold ledger rows, which are append-only, and products, which are archived, never deleted, and each keeps
# an active admin: the three guards stand aside for this one transaction, on the local stack, to remove the check's
# clinics and accounts.
cleanup() {
  users="'$user_a', '$user_b', '$user_c'"
  [ -n "${1:-}" ] && users="'$user_b', '$user_c'"
  sql <<SQL
begin;
alter table public.transactions disable trigger transactions_append_only;
alter table public.products disable trigger products_archive_only;
alter table public.memberships disable trigger memberships_keep_an_admin;
create temp table check_clinics on commit drop as
select distinct clinic_id as id from public.memberships where user_id in ($users);
delete from public.transactions where clinic_id in (select id from check_clinics);
delete from public.stock_actions where clinic_id in (select id from check_clinics);
delete from public.clinics where id in (select id from check_clinics);
delete from auth.users where id in ($users);
alter table public.transactions enable trigger transactions_append_only;
alter table public.products enable trigger products_archive_only;
alter table public.memberships enable trigger memberships_keep_an_admin;
commit;
SQL
}

on_exit() {
  if [ -n "$keep" ]; then
    cleanup keep
    echo "KEEP: the history's clinic stays; sign in as demo-history-check@dentory.test, password demohistory."
  else
    cleanup
  fi
}

trap on_exit EXIT
trap 'exit 1' INT TERM
cleanup

echo "A clinic as sign-up makes it, with the catalog and two products of its own"
clinic_a=$(make_clinic "$user_a" demo-history-check@dentory.test 'Demo history check' 'Grigor Grigoryan')
catalog "$clinic_a"
sql -o /dev/null -v clinic="$clinic_a" -v admin="$user_a" <<'SQL'
begin;
select set_config('request.jwt.claims', json_build_object('sub', :'admin', 'role', 'authenticated')::text, true);
insert into public.products (clinic_id, name, unit, minimum, target)
values (:'clinic', 'Pen', 'pens', 1, 5), (:'clinic', 'Pain killer', 'tablets', 5, 20);
select public.stock_receive(:'clinic', jsonb_build_array(jsonb_build_object('product_id',
  (select id from public.products where clinic_id = :'clinic' and name = 'Pen'), 'qty', 2)),
  gen_random_uuid(), 'manual', null, 'Receive manually');
select public.stock_adjust((select id from public.products where clinic_id = :'clinic' and name = 'Pen'), 0,
  'Missing', null, gen_random_uuid());
select public.stock_receive(:'clinic', jsonb_build_array(jsonb_build_object('product_id',
  (select id from public.products where clinic_id = :'clinic' and name = 'Pain killer'), 'qty', 12,
  'expiry_month', date_trunc('month', now() + interval '1 year')::date)), gen_random_uuid(), 'manual', null,
  'Receive manually');
commit;
SQL

before=$(footprint "$clinic_a")
out=$(CLINIC_ID=$clinic_a TARGET=local DRY_RUN=1 sh "$here/demo-history.sh" 2>&1) || fail "the dry run failed: $out"
case $out in
  *'Demo history check (America/Toronto), as its admin Grigor Grigoryan: about six weeks of stock from Monday '*'archives Pain killer and Pen (Delete product)'*'DRY_RUN: nothing was written.'*) ;;
  *) fail "the dry run did not say what it would write: $out" ;;
esac
[ "$(footprint "$clinic_a")" = "$before" ] || fail "the dry run wrote rows"
echo "The dry run says what it would write and writes nothing."

out=$(CLINIC_ID=$clinic_a TARGET=local sh "$here/demo-history.sh" 2>&1) || fail "the history failed: $out"
case $out in
  *'Written. The clinic now reads:'*'Home: 3 To buy, 3 Expiring soon, 1 Missing expiry'*) ;;
  *) fail "the history did not end as it says: $out" ;;
esac
printf '%s\n' "$out" | sed -n '/^Written/,$p'

sql -v clinic="$clinic_a" -v admin="$user_a" < "$here/demo-history-check.sql"

echo
before=$(footprint "$clinic_a")
expect_refused "$clinic_a" "has stock, ledger rows or To buy lines on 74 catalog products already" "A second run"
[ "$(footprint "$clinic_a")" = "$before" ] || fail "the refused second run wrote rows"
echo "It wrote nothing."
expect_refused "$unknown" "No clinic has the id $unknown: nothing was written." "An unknown clinic id"
out=$(CLINIC_ID=not-a-uuid sh "$here/demo-history.sh" 2>&1) && fail "a malformed clinic id was accepted"
case $out in *"is not a clinic id"*) ;; *) fail "a malformed clinic id: $out" ;; esac
echo "A malformed clinic id is refused before anything is sent."
clinic_b=$(make_clinic "$user_b" demo-history-check-b@dentory.test 'Demo history check B' 'Check B')
expect_refused "$clinic_b" "does not hold the general-practice catalog" "A clinic without the catalog"
clinic_c=$(make_clinic "$user_c" demo-history-check-c@dentory.test 'Demo history check C' 'Check C')
catalog "$clinic_c"
sql -o /dev/null <<SQL
begin;
alter table public.memberships disable trigger memberships_keep_an_admin;
update public.memberships set status = 'revoked' where user_id = '$user_c';
alter table public.memberships enable trigger memberships_keep_an_admin;
commit;
SQL
before=$(footprint "$clinic_c")
expect_refused "$clinic_c" "has no active admin to write the history as: nothing was written." \
  "A clinic without an active admin"
[ "$(footprint "$clinic_c")" = "$before" ] || fail "the refused run wrote rows"

echo
echo "demo-history-check: the demo history passed."
