#!/bin/sh
# `make seed-catalog CLINIC_ID=<uuid> [CATALOG=general-practice] [TARGET=local|linked]`: puts the clinic's id into the
# starting catalog supabase/catalogs/$CATALOG.sql and sends it with `supabase db query`, to the local stack
# (TARGET=local, the default) or to the hosted project this clone is linked to (TARGET=linked, through the Management
# API with the CLI's own login: no database password or key is read, passed or printed). Prints what the catalog
# added; the catalog itself refuses an id no clinic has, and adds nothing when any part of it fails. README.md beside
# this file says when to run it and what the clinic sees afterwards.
set -eu

catalog=${CATALOG:-general-practice}
here=$(dirname "$0")
file="$here/$catalog.sql"
# CLINIC_ID and TARGET, checked as demo-history.sh checks them.
. "$here/target.sh"

case $catalog in
  '' | *[!a-z0-9-]*) echo "CATALOG=\"$catalog\" is not a catalog name: use the name of a file in $here." >&2; exit 1 ;;
esac
[ -f "$file" ] || { echo "There is no catalog $file." >&2; exit 1; }
echo "Adding the $catalog catalog to clinic $clinic_id on $destination." >&2

# --yes: the hosted target is chosen on purpose with TARGET=linked; CLI versions that ask before writing to a hosted
# project would otherwise stop a run without a terminal. -o csv keeps the answer the same for people and agents.
answer=$(sed "s/__CLINIC_ID__/$clinic_id/g" "$file" | supabase db query "--$target" --agent no -o csv --yes)

header=$(printf '%s\n' "$answer" | sed -n 1p)
row=$(printf '%s\n' "$answer" | sed -n 2p)
if [ "$header" != "categories_added,products_added,clinic" ] || [ -z "$row" ]; then
  echo "The catalog ran, but its answer is not the one expected; it was:" >&2
  printf '%s\n' "$answer" >&2
  exit 1
fi
categories=${row%%,*}
rest=${row#*,}
products=${rest%%,*}
name=${rest#*,}
# CSV quotes a clinic name holding a comma or a quote.
case $name in \"*\") name=$(printf '%s' "$name" | sed -e 's/^"//' -e 's/"$//' -e 's/""/"/g') ;; esac
[ "$categories" = 1 ] && categories_word=category || categories_word=categories
[ "$products" = 1 ] && products_word=product || products_word=products
echo "$name: added $categories $categories_word and $products $products_word from the $catalog catalog."
