#!/usr/bin/env bash
#
# export-dashboards.sh
# Exports all Grafana dashboards via the HTTP API, organized by folder.
#
# Required environment variables:
#   GRAFANA_URL   - Base URL of the Grafana instance (e.g. https://grafana.example.com)
#   GRAFANA_TOKEN - Service account token with dashboards:read scope
#
# Usage:
#   export GRAFANA_URL=https://grafana.example.com
#   export GRAFANA_TOKEN=glsa_xxxxxxxxxxxx
#   ./scripts/export-dashboards.sh
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
DASHBOARDS_DIR="${DASHBOARDS_DIR:-dashboards}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${PROJECT_ROOT}/${DASHBOARDS_DIR}"

# Standard folder structure for the observability platform
STANDARD_FOLDERS=("L0-executive" "L1-domain" "L2-service" "L3-debug" "home")

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
if [[ -z "${GRAFANA_URL:-}" ]]; then
  echo "ERROR: GRAFANA_URL environment variable is not set." >&2
  exit 1
fi

if [[ -z "${GRAFANA_TOKEN:-}" ]]; then
  echo "ERROR: GRAFANA_TOKEN environment variable is not set." >&2
  exit 1
fi

for cmd in curl jq; do
  if ! command -v "${cmd}" &>/dev/null; then
    echo "ERROR: Required command '${cmd}' is not installed." >&2
    exit 1
  fi
done

# Strip trailing slash from URL
GRAFANA_URL="${GRAFANA_URL%/}"

# ---------------------------------------------------------------------------
# Helper: authenticated GET request
# ---------------------------------------------------------------------------
grafana_get() {
  local endpoint="$1"
  local response http_code body

  response=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer ${GRAFANA_TOKEN}" \
    -H "Content-Type: application/json" \
    "${GRAFANA_URL}${endpoint}")

  http_code=$(echo "${response}" | tail -n1)
  body=$(echo "${response}" | sed '$d')

  if [[ "${http_code}" -lt 200 || "${http_code}" -ge 300 ]]; then
    echo "ERROR: API request to ${endpoint} returned HTTP ${http_code}" >&2
    echo "  Response: ${body}" >&2
    return 1
  fi

  echo "${body}"
}

# ---------------------------------------------------------------------------
# Sanitize folder/file names for the filesystem
# ---------------------------------------------------------------------------
sanitize_name() {
  local name="$1"
  # Replace spaces and special characters with hyphens, lowercase
  echo "${name}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//'
}

# ---------------------------------------------------------------------------
# Create standard directory structure
# ---------------------------------------------------------------------------
echo "=============================================="
echo " Grafana Dashboard Export"
echo "=============================================="
echo "  Source:  ${GRAFANA_URL}"
echo "  Output:  ${OUTPUT_DIR}"
echo "=============================================="
echo ""

mkdir -p "${OUTPUT_DIR}"
for folder in "${STANDARD_FOLDERS[@]}"; do
  mkdir -p "${OUTPUT_DIR}/${folder}"
done
echo "[INFO] Created standard folder structure."

# ---------------------------------------------------------------------------
# Fetch folder list to build UID -> name mapping
# ---------------------------------------------------------------------------
echo "[INFO] Fetching folder list..."
FOLDERS_JSON=$(grafana_get "/api/folders") || exit 1

declare -A FOLDER_MAP
while IFS=$'\t' read -r fuid ftitle; do
  sanitized=$(sanitize_name "${ftitle}")
  FOLDER_MAP["${fuid}"]="${sanitized}"
done < <(echo "${FOLDERS_JSON}" | jq -r '.[] | [.uid, .title] | @tsv')

echo "[INFO] Found ${#FOLDER_MAP[@]} folders."

# ---------------------------------------------------------------------------
# Fetch all dashboards
# ---------------------------------------------------------------------------
echo "[INFO] Fetching dashboard list..."
SEARCH_JSON=$(grafana_get "/api/search?type=dash-db&limit=5000") || exit 1

DASHBOARD_COUNT=$(echo "${SEARCH_JSON}" | jq 'length')
echo "[INFO] Found ${DASHBOARD_COUNT} dashboards to export."
echo ""

if [[ "${DASHBOARD_COUNT}" -eq 0 ]]; then
  echo "[WARN] No dashboards found. Exiting."
  exit 0
fi

# ---------------------------------------------------------------------------
# Export each dashboard
# ---------------------------------------------------------------------------
SUCCESS_COUNT=0
ERROR_COUNT=0
EXPORTED_FILES=()

echo "${SEARCH_JSON}" | jq -c '.[]' | while IFS= read -r item; do
  uid=$(echo "${item}" | jq -r '.uid')
  title=$(echo "${item}" | jq -r '.title')
  folder_uid=$(echo "${item}" | jq -r '.folderUid // empty')
  folder_title=$(echo "${item}" | jq -r '.folderTitle // "General"')

  # Determine target folder
  if [[ -n "${folder_uid}" && -n "${FOLDER_MAP[${folder_uid}]+_}" ]]; then
    target_folder="${FOLDER_MAP[${folder_uid}]}"
  else
    target_folder=$(sanitize_name "${folder_title}")
  fi

  # Map to standard folders if possible (case-insensitive prefix match)
  matched_standard=""
  for std_folder in "${STANDARD_FOLDERS[@]}"; do
    if [[ "${target_folder}" == "${std_folder}"* ]] || [[ "${target_folder}" == "$(echo "${std_folder}" | tr '[:upper:]' '[:lower:]')"* ]]; then
      matched_standard="${std_folder}"
      break
    fi
  done

  if [[ -n "${matched_standard}" ]]; then
    target_folder="${matched_standard}"
  fi

  # Create target directory
  target_dir="${OUTPUT_DIR}/${target_folder}"
  mkdir -p "${target_dir}"

  # Sanitize filename
  filename=$(sanitize_name "${title}")
  filepath="${target_dir}/${filename}.json"

  echo -n "  Exporting: ${title} -> ${target_folder}/${filename}.json ... "

  # Fetch full dashboard JSON
  if dashboard_json=$(grafana_get "/api/dashboards/uid/${uid}"); then
    # Extract the dashboard body, strip id/version/meta but keep uid
    echo "${dashboard_json}" | jq '{
      dashboard: (.dashboard | del(.id, .version) | . + {uid: .uid}),
      folderId: .meta.folderId,
      folderUid: .meta.folderUid,
      overwrite: true
    } | del(.dashboard.meta)' > "${filepath}"

    echo "OK"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    echo "FAILED"
    ERROR_COUNT=$((ERROR_COUNT + 1))
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=============================================="
echo " Export Complete"
echo "=============================================="

# Count actual exported files
TOTAL_EXPORTED=$(find "${OUTPUT_DIR}" -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "  Dashboards exported: ${TOTAL_EXPORTED}"
echo ""
echo "  Directory structure:"
for folder in "${STANDARD_FOLDERS[@]}"; do
  count=$(find "${OUTPUT_DIR}/${folder}" -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [[ "${count}" -gt 0 ]]; then
    echo "    ${folder}/  (${count} dashboards)"
  fi
done

# List any dashboards that landed outside the standard folders
OTHER_COUNT=$(find "${OUTPUT_DIR}" -maxdepth 2 -name "*.json" -type f 2>/dev/null | while read -r f; do
  parent=$(basename "$(dirname "$f")")
  matched=false
  for std in "${STANDARD_FOLDERS[@]}"; do
    if [[ "${parent}" == "${std}" ]]; then matched=true; break; fi
  done
  if ! $matched; then echo "$f"; fi
done | wc -l | tr -d ' ')

if [[ "${OTHER_COUNT}" -gt 0 ]]; then
  echo "    (other)/  (${OTHER_COUNT} dashboards)"
fi

echo ""
echo "=============================================="
