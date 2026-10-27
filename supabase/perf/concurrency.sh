#!/bin/sh
# MS-150 · `make perf-concurrency`: PERF_CLIENTS clients at once in the load-test clinic, PERF_TRANSACTIONS stock
# changes each (pgbench in the database container). Three changes in four start a procedure from a random template as
# a random member, every supply at its default and a new bottle of each multi-use one (procedure-start.pgbench); the
# others open a bottle of one of those products from its page (bottle-open.pgbench). concurrency-check.sql then counts
# what was written and compares every product's stock with its ledger: the run fails on a deadlock, a lost change or a
# ledger that does not end at the stock. Local stack only; run it after `make db-reset seed-load`.
set -eu

container=${DB_CONTAINER:-supabase_db_Dentory}
clients=${PERF_CLIENTS:-8}
transactions=${PERF_TRANSACTIONS:-20}
here=$(dirname "$0")

sql() {
  docker exec -i "$container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q "$@"
}

sql -o /dev/null < "$here/concurrency-setup.sql"
for script in procedure-start bottle-open; do
  docker exec -i "$container" sh -c "cat > /tmp/$script.pgbench" < "$here/$script.pgbench"
done
since=$(sql -At -c "select now()")

docker exec "$container" pgbench -U postgres -d postgres -n -c "$clients" -j "$clients" -t "$transactions" \
  --failures-detailed -f /tmp/procedure-start.pgbench@3 -f /tmp/bottle-open.pgbench@1

sql -v since="$since" -v expected="$((clients * transactions))" < "$here/concurrency-check.sql"
