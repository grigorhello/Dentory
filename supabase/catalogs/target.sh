# Sourced by seed.sh and demo-history.sh: checks CLINIC_ID and TARGET as the Makefile passes them and sets clinic_id
# (lower case), target (local or linked) and destination (where the statement goes, for the line each script prints).
# TARGET=linked is the project this clone is linked to (`supabase link --project-ref <ref>`), reached through the
# Management API with the CLI's own login: no database password or key is read, passed or printed. Stops with the
# reason before anything is sent.

clinic_id=${CLINIC_ID:-}
target=${TARGET:-local}

uuid='^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$'
if ! printf '%s\n' "$clinic_id" | grep -Eq "$uuid"; then
  echo "CLINIC_ID=\"$clinic_id\" is not a clinic id: pass CLINIC_ID=<uuid>, as the clinics table has it." >&2
  exit 1
fi
clinic_id=$(printf '%s' "$clinic_id" | tr 'A-F' 'a-f')
case $target in
  local) destination='the local stack' ;;
  linked)
    ref=$(cat supabase/.temp/project-ref 2>/dev/null || true)
    [ -n "$ref" ] || { echo "This clone is not linked to a project: run supabase link --project-ref <ref> first." >&2; exit 1; }
    destination="the linked project $ref"
    ;;
  *) echo "TARGET=\"$target\": use local or linked." >&2; exit 1 ;;
esac
