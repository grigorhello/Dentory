#!/bin/sh
# `make catalog-check`: the starting catalog CATALOG (general-practice) on the local stack, run by seed.sh as
# `make seed-catalog` runs it, on two clinics made through clinic_create by two new accounts, as sign-up makes them.
# - A, as sign-up leaves it: the first run adds every product and only the categories sign-up does not make, the
#   second run nothing; check.sql then checks each product against the catalog's rules and New product's, that nothing
#   else was written, what the admin's screens read, and what the nightly status refresh, a first count and a first
#   delivery do (in a transaction it rolls back).
# - B, with the category of the first product renamed, the first product archived under its name in lower case and
#   the second typed in capitals with a unit of its own: a run that fails part-way adds nothing; the real run adds the
#   missing category and every other product and changes neither of those two; a second run adds nothing.
# - An unknown clinic id and a malformed one are refused.
# The two clinics and accounts are removed at the end, and before the start if an earlier run stopped half-way.
set -eu

container=${DB_CONTAINER:-supabase_db_Dentory}
catalog=${CATALOG:-general-practice}
here=$(dirname "$0")
file="$here/$catalog.sql"
user_a=ca7a0000-0000-4000-8000-0000000000a1
user_b=ca7a0000-0000-4000-8000-0000000000b1
unknown=ca7a0000-0000-4000-8000-0000000000c1

sql() {
  docker exec -i "$container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q "$@"
}

fail() {
  echo "catalog-check: $*" >&2
  exit 1
}

plural() {
  if [ "$1" = 1 ]; then echo "1 $2"; else echo "$1 $3"; fi
}

# Runs the catalog on a clinic through seed.sh and checks the line it ends with.
expect_run() {
  out=$(CLINIC_ID=$1 CATALOG=$catalog TARGET=local sh "$here/seed.sh" 2>&1) || fail "the catalog failed: $out"
  last=$(printf '%s\n' "$out" | tail -n 1)
  [ "$last" = "$2" ] || fail "expected \"$2\"; seed.sh said: $out"
  echo "$last"
}

# Makes an account and its clinic as sign-up does (clinic_create as the signed-in account) and prints the clinic's id.
make_clinic() {
  sql -o /dev/null <<SQL
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token, email_change_token_new, email_change
)
values (
  '$1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '$2', '', now(),
  '{"provider": "email", "providers": ["email"]}', '{}', now(), now(), '', '', '', ''
);
begin;
select set_config('request.jwt.claims', json_build_object('sub', '$1', 'role', 'authenticated')::text, true);
set local role authenticated;
select public.clinic_create('$3', 'Toronto', 'CA', 'America/Toronto', 'Catalog check');
commit;
SQL
  sql -At -c "select clinic_id from public.memberships where user_id = '$1'"
}

# Products are archived, never deleted, and a clinic keeps an active admin: both guards stand aside for this one
# transaction, on the local stack, to remove the check's two clinics (their categories and products go with them) and
# the two accounts. The check writes no ledger rows that would outlive it.
cleanup() {
  sql <<SQL
begin;
alter table public.products disable trigger products_archive_only;
alter table public.memberships disable trigger memberships_keep_an_admin;
delete from public.clinics
where id in (select clinic_id from public.memberships where user_id in ('$user_a', '$user_b'));
delete from auth.users where id in ('$user_a', '$user_b');
alter table public.products enable trigger products_archive_only;
alter table public.memberships enable trigger memberships_keep_an_admin;
commit;
SQL
}

[ -f "$file" ] || fail "there is no catalog $file"
products=$(grep -cE "^[[:space:]]*\([0-9]+, '" "$file" || true)
[ "$products" -gt 0 ] || fail "$file has no product lines"
# The categories the catalog names that sign-up does not make (MS-100 D13).
defaults=" anesthetic restorative endodontics impression preventive surgical ppe sterilization disposable other "
new_categories=0
for category in $(sed -nE "s/^[[:space:]]*\([0-9]+, '([^']*)'.*/\1/p" "$file" | tr 'A-Z ' 'a-z_' | sort -u); do
  case $defaults in *" $category "*) ;; *) new_categories=$((new_categories + 1)) ;; esac
done

trap cleanup EXIT
trap 'exit 1' INT TERM
cleanup

echo "Clinic A, as sign-up makes it"
clinic_a=$(make_clinic "$user_a" catalog-check-a@dentory.test 'Catalog check A')
expect_run "$clinic_a" "Catalog check A: added $(plural "$new_categories" category categories) and \
$(plural "$products" product products) from the $catalog catalog."
expect_run "$clinic_a" "Catalog check A: added 0 categories and 0 products from the $catalog catalog."
sql -v clinic="$clinic_a" -v admin="$user_a" -v products="$products" -v categories="$((10 + new_categories))" \
  < "$here/check.sql"

echo
echo "Clinic B, with a category renamed, a product archived and one typed in capitals"
clinic_b=$(make_clinic "$user_b" catalog-check-b@dentory.test 'Catalog check B')
sql -v a="$clinic_a" -v b="$clinic_b" <<'SQL'
create temp table check_pair as
select :'a'::uuid as a, :'b'::uuid as b,
  (select p.name from public.products p where p.clinic_id = :'a' order by p.created_at limit 1) as first_name,
  (select p.name from public.products p where p.clinic_id = :'a' order by p.created_at offset 1 limit 1) as second_name,
  (select k.name from public.products p join public.categories k on k.id = p.category_id
   where p.clinic_id = :'a' order by p.created_at limit 1) as first_category;
update public.categories k set name = r.first_category || ' (renamed)'
from check_pair r where k.clinic_id = r.b and k.name = r.first_category;
insert into public.products (clinic_id, name, unit, archived_at) select b, lower(first_name), 'units', now() from check_pair;
insert into public.products (clinic_id, name, unit) select b, upper(second_name), 'pieces' from check_pair;
SQL

# A catalog that fails part-way, here on a product's tracking mode, adds nothing: neither the category the clinic lacks
# nor any product.
out=$(sed -e "s/__CLINIC_ID__/$clinic_b/g" -e "s/'countable'/'not a mode'/g" "$file" \
  | supabase db query --local --agent no -o csv --yes 2>&1) && fail "a catalog that fails part-way ran"
case $out in
  *'invalid input value for enum tracking_mode: "not a mode"'*) ;;
  *) fail "a catalog meant to fail on a tracking mode failed otherwise: $out" ;;
esac
[ "$(sql -At -c "select count(*) from public.categories where clinic_id = '$clinic_b'")" = 10 ] \
  || fail "a catalog that failed part-way left categories behind"
[ "$(sql -At -c "select count(*) from public.products where clinic_id = '$clinic_b'")" = 2 ] \
  || fail "a catalog that failed part-way left products behind"
echo "A run that fails part-way adds nothing."

expect_run "$clinic_b" "Catalog check B: added $(plural "$((new_categories + 1))" category categories) and \
$(plural "$((products - 2))" product products) from the $catalog catalog."
expect_run "$clinic_b" "Catalog check B: added 0 categories and 0 products from the $catalog catalog."
sql -v a="$clinic_a" -v b="$clinic_b" -v products="$products" <<'SQL'
create temp table check_pair as
select :'a'::uuid as a, :'b'::uuid as b, :products::integer as products,
  (select p.name from public.products p where p.clinic_id = :'a' order by p.created_at limit 1) as first_name,
  (select p.name from public.products p where p.clinic_id = :'a' order by p.created_at offset 1 limit 1) as second_name,
  (select k.name from public.products p join public.categories k on k.id = p.category_id
   where p.clinic_id = :'a' order by p.created_at limit 1) as first_category;
do $$
declare
  r record;
  v_category public.categories;
begin
  select * into r from check_pair;
  if (select count(*) from public.products where clinic_id = r.b) <> r.products then
    raise exception 'Clinic B does not hold the catalog''s % products once each', r.products;
  end if;
  if (select count(*) from public.products
      where clinic_id = r.b and lower(name) = lower(r.first_name) and archived_at is not null) <> 1
     or exists (select 1 from public.products
                where clinic_id = r.b and lower(name) = lower(r.first_name) and archived_at is null)
  then
    raise exception 'The archived % came back', r.first_name;
  end if;
  if (select count(*) from public.products
      where clinic_id = r.b and lower(name) = lower(r.second_name) and unit = 'pieces' and name = upper(r.second_name)) <> 1
     or (select count(*) from public.products where clinic_id = r.b and lower(name) = lower(r.second_name)) <> 1
  then
    raise exception 'The clinic''s own % was changed or doubled', upper(r.second_name);
  end if;
  select * into v_category from public.categories where clinic_id = r.b and name = r.first_category;
  if v_category.id is null or v_category.position <> 11 then
    raise exception 'The missing category % was not added after the clinic''s last one', r.first_category;
  end if;
  if not exists (select 1 from public.categories where clinic_id = r.b and name = r.first_category || ' (renamed)') then
    raise exception 'The renamed category was changed';
  end if;
  if exists (select 1 from public.products p join public.products q on lower(q.name) = lower(p.name)
             join public.categories k on k.id = q.category_id
             where p.clinic_id = r.a and q.clinic_id = r.b and k.name = r.first_category || ' (renamed)') then
    raise exception 'Products went into the renamed category instead of the one the catalog names';
  end if;
end;
$$;
SQL
echo "The archived product stayed archived, the clinic's own product unchanged, the missing category added last."

echo
out=$(CLINIC_ID=$unknown TARGET=local sh "$here/seed.sh" 2>&1) && fail "a clinic id no clinic has was accepted"
case $out in *"No clinic has the id $unknown: nothing was added."*) ;; *) fail "an unknown clinic: $out" ;; esac
echo "An unknown clinic id is refused."
out=$(CLINIC_ID=not-a-uuid sh "$here/seed.sh" 2>&1) && fail "a malformed clinic id was accepted"
case $out in *"is not a clinic id"*) ;; *) fail "a malformed clinic id: $out" ;; esac
echo "A malformed clinic id is refused before anything is sent."

echo
echo "catalog-check: the $catalog catalog passed ($products products)."
