#!/bin/sh
# `make seed-demo-history CLINIC_ID=<uuid> [TARGET=local|linked] [DRY_RUN=1]`: about six weeks of stock history
# (demo-history.sql) into one clinic that holds the general-practice catalog and never stocked it, on the local stack
# (TARGET=local, the default) or on the hosted project this clone is linked to (TARGET=linked, through the Management
# API with the CLI's own login: no database password or key is read, passed or printed). It prints where it writes,
# then runs the statement's checks alone and prints what it would write, or the refusal, which stops it; DRY_RUN=1
# stops there in any case. Then it sends the statement for real, which checks everything again and writes all of it or
# nothing, and prints what the clinic reads. The ledger is append-only: what it writes stays in the clinic for good,
# so it is for demo clinics only. README.md beside this file says more.
set -eu

here=$(dirname "$0")
# CLINIC_ID and TARGET, checked as seed.sh checks them.
. "$here/target.sh"
dry_run=${DRY_RUN:-}
esc=$(printf '\033')

# A statement of this folder, with the clinic's id and the dry-run switch in it. --yes: the hosted target is chosen on
# purpose with TARGET=linked, and CLI versions that ask before writing to a hosted project would stop a run without a
# terminal. -o csv keeps the answer the same for people and agents.
send() {
  sed -e "s/__CLINIC_ID__/$clinic_id/g" -e "s/__DRY_RUN__/$2/g" "$here/$1" \
    | supabase db query "--$target" --agent no -o csv --yes
}

# An answer without the CLI's colours and its "Connecting to" line.
plain() {
  printf '%s\n' "$1" | sed -e "s/${esc}\[[0-9;]*m//g" | grep -v '^Connecting to' || true
}

# The message of a refused statement, without the CLI's words around it; the whole answer when it reads otherwise.
reason() {
  message=$(plain "$1" | sed -n 's/^failed to execute query: error: //p')
  if [ -n "$message" ]; then printf '%s\n' "$message"; else plain "$1"; fi
}

echo "Demo history for clinic $clinic_id on $destination." >&2

# The checks alone: the statement stops after them, with what it would write or with the refusal.
if preview=$(send demo-history.sql true 2>&1); then
  echo "The dry run did not stop after its checks; it said:" >&2
  printf '%s\n' "$preview" >&2
  exit 1
fi
what=$(plain "$preview" | sed -n 's/.*DEMO HISTORY PREVIEW: //p')
if [ -z "$what" ]; then
  reason "$preview" >&2
  exit 1
fi
printf '%s\n' "$what"
if [ -n "$dry_run" ]; then
  echo "DRY_RUN: nothing was written."
  exit 0
fi

if ! answer=$(send demo-history.sql false 2>&1); then
  reason "$answer" >&2
  exit 1
fi
echo "Written. The clinic now reads:"
if ! summary=$(send demo-history-summary.sql false 2>&1); then
  echo "The history is written, but what the clinic reads could not be shown:" >&2
  reason "$summary" >&2
  exit 1
fi
# One line a row, without the header and CSV's quotes.
plain "$summary" | sed 1d | sed -e '/^".*"$/{' -e 's/^"//' -e 's/"$//' -e 's/""/"/g' -e '}' -e 's/^/  /'
