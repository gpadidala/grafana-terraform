#!/usr/bin/env bash
#
# templatize-dashboards.sh
# Replaces hardcoded datasource and folder UIDs in exported Grafana dashboard
# JSON files with Terraform template variables.
#
# The script scans all .json files under the dashboards/ directory and produces
# .json.tmpl files (Terraform templatefile-compatible) with placeholders like:
#   ${datasource_mimir_uid}
#   ${datasource_loki_uid}
#   ${datasource_tempo_uid}
#   ${datasource_pyroscope_uid}
#   ${folder_<name>_uid}
#
# Prerequisites: jq >= 1.6
#
# Usage:
#   ./scripts/templatize-dashboards.sh
#   ./scripts/templatize-dashboards.sh --in-place   # Overwrite .json files instead of creating .json.tmpl
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DASHBOARDS_DIR="${PROJECT_ROOT}/${DASHBOARDS_DIR:-dashboards}"

IN_PLACE=false
if [[ "${1:-}" == "--in-place" ]]; then
  IN_PLACE=true
fi

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not installed." >&2
  exit 1
fi

if [[ ! -d "${DASHBOARDS_DIR}" ]]; then
  echo "ERROR: Dashboards directory not found at ${DASHBOARDS_DIR}" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Datasource type -> template variable mapping
# ---------------------------------------------------------------------------
# Maps Grafana datasource type strings to Terraform template variable names.
# Edit this associative array to support additional datasource types.
declare -A DS_TYPE_MAP=(
  ["prometheus"]="datasource_mimir_uid"
  ["mimir"]="datasource_mimir_uid"
  ["loki"]="datasource_loki_uid"
  ["tempo"]="datasource_tempo_uid"
  ["pyroscope"]="datasource_pyroscope_uid"
)

# ---------------------------------------------------------------------------
# Phase 1: Discover datasource UIDs used across all dashboards
# ---------------------------------------------------------------------------
echo "=============================================="
echo " Dashboard Templatization"
echo "=============================================="
echo "  Source: ${DASHBOARDS_DIR}"
echo "  Mode:  $(if $IN_PLACE; then echo 'in-place (.json overwrite)'; else echo 'template (.json.tmpl)'; fi)"
echo "=============================================="
echo ""

echo "[INFO] Scanning dashboards for datasource references..."

# Collect all unique datasource UIDs and their types from dashboard JSON files.
# Datasources appear in panels as:
#   { "datasource": { "type": "prometheus", "uid": "abc123" } }
# We also handle the legacy string-uid format.
declare -A UID_TO_VAR
declare -A UID_TO_ORIGINAL

DASHBOARD_FILES=$(find "${DASHBOARDS_DIR}" -name "*.json" -type f | sort)
FILE_COUNT=$(echo "${DASHBOARD_FILES}" | grep -c . || true)

if [[ "${FILE_COUNT}" -eq 0 ]]; then
  echo "[WARN] No .json files found in ${DASHBOARDS_DIR}. Nothing to templatize."
  exit 0
fi

echo "[INFO] Found ${FILE_COUNT} dashboard files."

# Extract datasource uid+type pairs from every JSON file
while IFS= read -r filepath; do
  # Extract all datasource objects that have both type and uid fields
  while IFS=$'\t' read -r ds_type ds_uid; do
    # Skip template variables, empty strings, and special UIDs
    if [[ -z "${ds_uid}" ]] || [[ "${ds_uid}" == "null" ]] || [[ "${ds_uid}" == "--"* ]] || [[ "${ds_uid}" == '${'* ]]; then
      continue
    fi
    # Skip "grafana" built-in datasource
    if [[ "${ds_type}" == "grafana" ]] || [[ "${ds_type}" == "datasource" ]]; then
      continue
    fi

    # Normalize the type for mapping
    ds_type_lower=$(echo "${ds_type}" | tr '[:upper:]' '[:lower:]')

    # Check if the type maps to a known template variable
    for pattern in "${!DS_TYPE_MAP[@]}"; do
      if [[ "${ds_type_lower}" == *"${pattern}"* ]]; then
        template_var="${DS_TYPE_MAP[${pattern}]}"
        UID_TO_VAR["${ds_uid}"]="${template_var}"
        UID_TO_ORIGINAL["${ds_uid}"]="${ds_type}"
        break
      fi
    done
  done < <(jq -r '
    .. | objects | select(.datasource? // empty)
    | if (.datasource | type) == "object" then
        [(.datasource.type // ""), (.datasource.uid // "")] | @tsv
      elif (.datasource | type) == "string" then
        ["unknown", .datasource] | @tsv
      else
        empty
      end
  ' "${filepath}" 2>/dev/null || true)
done <<< "${DASHBOARD_FILES}"

echo "[INFO] Discovered ${#UID_TO_VAR[@]} unique datasource UIDs to templatize."
echo ""

if [[ ${#UID_TO_VAR[@]} -gt 0 ]]; then
  echo "  Datasource UID Mappings:"
  for uid in "${!UID_TO_VAR[@]}"; do
    printf "    %-40s -> \${%s}  (type: %s)\n" "${uid}" "${UID_TO_VAR[${uid}]}" "${UID_TO_ORIGINAL[${uid}]}"
  done
  echo ""
fi

# ---------------------------------------------------------------------------
# Phase 2: Discover folder UIDs
# ---------------------------------------------------------------------------
declare -A FOLDER_UID_TO_VAR

while IFS= read -r filepath; do
  folder_uid=$(jq -r '.folderUid // empty' "${filepath}" 2>/dev/null || true)
  if [[ -n "${folder_uid}" && "${folder_uid}" != "null" ]]; then
    # Derive a variable name from the parent directory name
    parent_dir=$(basename "$(dirname "${filepath}")")
    safe_name=$(echo "${parent_dir}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g' | sed 's/__*/_/g' | sed 's/^_//;s/_$//')
    FOLDER_UID_TO_VAR["${folder_uid}"]="folder_${safe_name}_uid"
  fi
done <<< "${DASHBOARD_FILES}"

if [[ ${#FOLDER_UID_TO_VAR[@]} -gt 0 ]]; then
  echo "  Folder UID Mappings:"
  for uid in "${!FOLDER_UID_TO_VAR[@]}"; do
    printf "    %-40s -> \${%s}\n" "${uid}" "${FOLDER_UID_TO_VAR[${uid}]}"
  done
  echo ""
fi

# ---------------------------------------------------------------------------
# Phase 3: Apply replacements
# ---------------------------------------------------------------------------
echo "[INFO] Applying template substitutions..."
echo ""

TOTAL_DS_REPLACEMENTS=0
TOTAL_FOLDER_REPLACEMENTS=0
FILES_MODIFIED=0

while IFS= read -r filepath; do
  filename=$(basename "${filepath}")
  relpath="${filepath#${PROJECT_ROOT}/}"

  if $IN_PLACE; then
    output_path="${filepath}"
  else
    output_path="${filepath}.tmpl"
  fi

  content=$(cat "${filepath}")
  file_replacements=0

  # Replace datasource UIDs
  for uid in "${!UID_TO_VAR[@]}"; do
    template_var="${UID_TO_VAR[${uid}]}"
    # Count occurrences before replacement
    occurrences=$(echo "${content}" | grep -o "\"${uid}\"" | wc -l | tr -d ' ')
    if [[ "${occurrences}" -gt 0 ]]; then
      content=$(echo "${content}" | sed "s|\"${uid}\"|\"\\${${template_var}}\"|g")
      file_replacements=$((file_replacements + occurrences))
      TOTAL_DS_REPLACEMENTS=$((TOTAL_DS_REPLACEMENTS + occurrences))
    fi
  done

  # Replace folder UIDs
  for uid in "${!FOLDER_UID_TO_VAR[@]}"; do
    template_var="${FOLDER_UID_TO_VAR[${uid}]}"
    occurrences=$(echo "${content}" | grep -o "\"${uid}\"" | wc -l | tr -d ' ')
    if [[ "${occurrences}" -gt 0 ]]; then
      content=$(echo "${content}" | sed "s|\"${uid}\"|\"\\${${template_var}}\"|g")
      file_replacements=$((file_replacements + occurrences))
      TOTAL_FOLDER_REPLACEMENTS=$((TOTAL_FOLDER_REPLACEMENTS + occurrences))
    fi
  done

  if [[ "${file_replacements}" -gt 0 ]]; then
    echo "${content}" > "${output_path}"
    FILES_MODIFIED=$((FILES_MODIFIED + 1))
    echo "  [OK] ${relpath} -> ${file_replacements} replacements"
  else
    # Still create the .tmpl file even if no replacements, for consistency
    if ! $IN_PLACE; then
      cp "${filepath}" "${output_path}"
    fi
    echo "  [--] ${relpath} -> no replacements needed"
  fi
done <<< "${DASHBOARD_FILES}"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=============================================="
echo " Templatization Complete"
echo "=============================================="
echo "  Files scanned:           ${FILE_COUNT}"
echo "  Files modified:          ${FILES_MODIFIED}"
echo "  Datasource replacements: ${TOTAL_DS_REPLACEMENTS}"
echo "  Folder UID replacements: ${TOTAL_FOLDER_REPLACEMENTS}"
echo "  Total replacements:      $((TOTAL_DS_REPLACEMENTS + TOTAL_FOLDER_REPLACEMENTS))"
echo ""
if ! $IN_PLACE; then
  TMPL_COUNT=$(find "${DASHBOARDS_DIR}" -name "*.json.tmpl" -type f 2>/dev/null | wc -l | tr -d ' ')
  echo "  Template files created:  ${TMPL_COUNT}"
fi
echo "=============================================="
