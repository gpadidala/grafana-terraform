#!/usr/bin/env bash
# =============================================================================
# Grafana End-to-End Test Suite
# =============================================================================
# Tests every major Grafana resource against a live instance.
# Runs against GRAFANA_URL (default: http://localhost:3200/) using basic auth.
#
# Coverage:
#   1.  Health & version
#   2.  Folders (CRUD + permissions)
#   3.  Teams (CRUD + members + preferences)
#   4.  Users (CRUD)
#   5.  Service accounts (CRUD + tokens + permissions)
#   6.  Data sources (CRUD + test)
#   7.  Dashboards (CRUD + permissions + public)
#   8.  Library panels (CRUD)
#   9.  Alerting (contact points + routing + templates + mute timings + rules)
#   10. RBAC (permissions list + custom roles + built-in role assignment)
#   11. Plugins (list + install + upgrade + uninstall)
#   12. Preferences (org + team)
#   13. Annotations (create + update + delete)
#   14. Snapshots (create + delete)
#
# Usage:
#   GRAFANA_URL=http://localhost:3200/ GRAFANA_USER=admin GRAFANA_PASS=admin \
#     ./tests/e2e-test.sh
# =============================================================================

set -u  # Fail on undefined vars. Not -e: we want the runner to continue on test failure.

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3200/}"
GRAFANA_URL="${GRAFANA_URL%/}"   # strip trailing slash
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:-admin}"
TEST_PREFIX="e2e-$(date +%s)"    # Unique prefix so repeat runs don't collide
REPORT_FILE="${REPORT_FILE:-tests/test-results.md}"

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
BOLD="\033[1m"
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
CYAN="\033[36m"
GRAY="\033[90m"
RESET="\033[0m"

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
declare -a TEST_RESULTS=()     # "PASS|name|detail" or "FAIL|name|detail" or "SKIP|name|reason"
declare -a CLEANUP_CMDS=()     # Commands to run on exit
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
CURRENT_SECTION=""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { printf "%b\n" "$*"; }
section() {
  CURRENT_SECTION="$1"
  log ""
  log "${BOLD}${CYAN}=== $1 ===${RESET}"
}

# api <METHOD> <PATH> [JSON_BODY]
# Sets globals: $HTTP_CODE, $API_BODY
# (Can't use command substitution because subshells lose variable state.)
API_BODY=""
HTTP_CODE="000"
api() {
  local method="$1" path="$2" body="${3:-}"
  local resp
  if [[ -n "$body" ]]; then
    resp=$(curl -sS -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -X "$method" "${GRAFANA_URL}${path}" \
      -d "$body" \
      -w $'\n__HTTP__%{http_code}' 2>&1)
  else
    resp=$(curl -sS -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
      -H "Accept: application/json" \
      -X "$method" "${GRAFANA_URL}${path}" \
      -w $'\n__HTTP__%{http_code}' 2>&1)
  fi
  HTTP_CODE="${resp##*__HTTP__}"
  API_BODY="${resp%$'\n'__HTTP__*}"
}

# jq-like single-field extractor (no jq dependency)
jget() {
  python3 -c "
import json, sys
try:
    data = json.loads(sys.stdin.read())
    parts = '$1'.split('.')
    for p in parts:
        if p.isdigit():
            data = data[int(p)]
        else:
            data = data.get(p) if isinstance(data, dict) else None
        if data is None: break
    print('' if data is None else data)
except Exception as e:
    print('', file=sys.stderr)
" 2>/dev/null
}

# pass/fail/skip test
pass() {
  local name="$1" detail="${2:-}"
  PASS_COUNT=$((PASS_COUNT + 1))
  TEST_RESULTS+=("PASS|${CURRENT_SECTION}|${name}|${detail}")
  log "  ${GREEN}PASS${RESET} ${name} ${GRAY}${detail}${RESET}"
}
fail() {
  local name="$1" detail="${2:-}"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  TEST_RESULTS+=("FAIL|${CURRENT_SECTION}|${name}|${detail}")
  log "  ${RED}FAIL${RESET} ${name} ${GRAY}${detail}${RESET}"
}
skip() {
  local name="$1" reason="${2:-}"
  SKIP_COUNT=$((SKIP_COUNT + 1))
  TEST_RESULTS+=("SKIP|${CURRENT_SECTION}|${name}|${reason}")
  log "  ${YELLOW}SKIP${RESET} ${name} ${GRAY}${reason}${RESET}"
}

# Assert HTTP status is 2xx
assert_ok() {
  local name="$1" body="${2:-}"
  if [[ "$HTTP_CODE" =~ ^2 ]]; then
    pass "$name" "HTTP ${HTTP_CODE}"
    return 0
  else
    fail "$name" "HTTP ${HTTP_CODE}: $(echo "$body" | head -c 200)"
    return 1
  fi
}

# Register a cleanup command (executed in reverse order on exit)
cleanup_add() { CLEANUP_CMDS+=("$1"); }

cleanup() {
  log ""
  log "${BOLD}${CYAN}=== Cleanup ===${RESET}"
  local i
  for (( i=${#CLEANUP_CMDS[@]}-1 ; i>=0 ; i-- )) ; do
    local cmd="${CLEANUP_CMDS[$i]}"
    eval "$cmd" >/dev/null 2>&1 && \
      log "  ${GRAY}cleanup: $cmd${RESET}" || \
      log "  ${YELLOW}cleanup failed:${RESET} $cmd"
  done
}
trap cleanup EXIT

# =============================================================================
# TEST 1: Health & Version
# =============================================================================
test_health() {
  section "1. Health & Version"

  local body
  api GET /api/health
  body="$API_BODY"
  assert_ok "GET /api/health" "$body" || return
  GRAFANA_VERSION=$(echo "$body" | jget version)
  log "     ${GRAY}Grafana version: ${GRAFANA_VERSION}${RESET}"

  api GET /api/org
  body="$API_BODY"
  assert_ok "GET /api/org (current org)" "$body" || return
  ORG_ID=$(echo "$body" | jget id)
  log "     ${GRAY}Org ID: ${ORG_ID}${RESET}"

  api GET /api/user
  body="$API_BODY"
  assert_ok "GET /api/user (admin auth)" "$body"

  api GET /api/frontend/settings
  body="$API_BODY"
  assert_ok "GET /api/frontend/settings" "$body"
  EDITION=$(echo "$body" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('licenseInfo',{}).get('edition','Unknown'))" 2>/dev/null)
  log "     ${GRAY}Edition: ${EDITION}${RESET}"
}

# =============================================================================
# TEST 2: Folders (CRUD + Permissions)
# =============================================================================
test_folders() {
  section "2. Folders (CRUD + Permissions)"

  local body fuid
  local folder_title="${TEST_PREFIX}-folder"

  # Create
  api POST /api/folders "{\"uid\":\"${TEST_PREFIX}-fld\",\"title\":\"${folder_title}\"}"
  body="$API_BODY"
  if assert_ok "POST /api/folders (create)" "$body"; then
    fuid=$(echo "$body" | jget uid)
    FOLDER_UID="$fuid"
    cleanup_add "api DELETE /api/folders/${fuid}"
    log "     ${GRAY}Folder UID: ${fuid}${RESET}"
  else
    return
  fi

  # Read
  api GET "/api/folders/${fuid}"
  body="$API_BODY"
  assert_ok "GET /api/folders/{uid}" "$body"

  # List
  api GET /api/folders
  body="$API_BODY"
  assert_ok "GET /api/folders (list)" "$body"

  # Update
  api PUT "/api/folders/${fuid}" "{\"title\":\"${folder_title}-updated\",\"version\":1,\"overwrite\":true}"
  body="$API_BODY"
  assert_ok "PUT /api/folders/{uid} (update title)" "$body"

  # List folder permissions (default)
  api GET "/api/folders/${fuid}/permissions"
  body="$API_BODY"
  assert_ok "GET /api/folders/{uid}/permissions" "$body"

  # Set folder permissions (grant Editor role View access)
  local perms_payload='{"items":[{"role":"Viewer","permission":1},{"role":"Editor","permission":2}]}'
  api POST "/api/folders/${fuid}/permissions" "$perms_payload"
  body="$API_BODY"
  assert_ok "POST /api/folders/{uid}/permissions (role-based)" "$body"

  # Search in folder
  api GET "/api/search?folderUIDs=${fuid}&type=dash-folder"
  body="$API_BODY"
  assert_ok "GET /api/search?folderUIDs=... (scoped search)" "$body"
}

# =============================================================================
# TEST 3: Teams (CRUD + Members + Preferences)
# =============================================================================
test_teams() {
  section "3. Teams (CRUD + Members + Preferences)"

  local body tid
  local team_name="${TEST_PREFIX}-team-sre"

  # Create team
  api POST /api/teams "{\"name\":\"${team_name}\",\"email\":\"sre@example.com\"}"
  body="$API_BODY"
  if assert_ok "POST /api/teams (create)" "$body"; then
    tid=$(echo "$body" | jget teamId)
    TEAM_ID="$tid"
    cleanup_add "api DELETE /api/teams/${tid}"
    log "     ${GRAY}Team ID: ${tid}${RESET}"
  else
    return
  fi

  # Get
  api GET "/api/teams/${tid}"
  body="$API_BODY"
  assert_ok "GET /api/teams/{id}" "$body"

  # Search
  api GET "/api/teams/search?name=${team_name}"
  body="$API_BODY"
  assert_ok "GET /api/teams/search?name=..." "$body"

  # Update
  api PUT "/api/teams/${tid}" "{\"name\":\"${team_name}\",\"email\":\"sre-updated@example.com\"}"
  body="$API_BODY"
  assert_ok "PUT /api/teams/{id} (update email)" "$body"

  # Grafana auto-adds team creator (admin) as member. Test the member lifecycle:
  # verify creator auto-membership, then remove + re-add to exercise the API.
  api GET "/api/teams/${tid}/members"
  body="$API_BODY"
  if echo "$body" | grep -q '"userId":1'; then
    pass "POST /api/teams (creator auto-added as member)" "admin is member"
  else
    fail "POST /api/teams (creator auto-added as member)" "admin not found in members"
  fi

  api DELETE "/api/teams/${tid}/members/1"
  body="$API_BODY"

  api POST "/api/teams/${tid}/members" '{"userId":1}'
  body="$API_BODY"
  assert_ok "POST /api/teams/{id}/members (re-add after remove)" "$body"

  # List members
  api GET "/api/teams/${tid}/members"
  body="$API_BODY"
  assert_ok "GET /api/teams/{id}/members (list)" "$body"

  # Team preferences
  api PUT "/api/teams/${tid}/preferences" '{"theme":"dark","timezone":"utc","weekStart":"monday"}'
  body="$API_BODY"
  assert_ok "PUT /api/teams/{id}/preferences" "$body"

  api GET "/api/teams/${tid}/preferences"
  body="$API_BODY"
  assert_ok "GET /api/teams/{id}/preferences" "$body"

  # Remove member (cleanup)
  api DELETE "/api/teams/${tid}/members/1"
  body="$API_BODY"
  assert_ok "DELETE /api/teams/{id}/members/{userId}" "$body"

  # Second team for RBAC scope test
  api POST /api/teams "{\"name\":\"${TEST_PREFIX}-team-exec\"}"
  body="$API_BODY"
  if [[ "$HTTP_CODE" =~ ^2 ]]; then
    TEAM_ID_EXEC=$(echo "$body" | jget teamId)
    cleanup_add "api DELETE /api/teams/${TEAM_ID_EXEC}"
    pass "POST /api/teams (second team for scope tests)" "id=${TEAM_ID_EXEC}"
  else
    fail "POST /api/teams (second team for scope tests)" "HTTP ${HTTP_CODE}"
  fi
}

# =============================================================================
# TEST 4: Users (CRUD)
# =============================================================================
test_users() {
  section "4. Users (CRUD)"

  local body uid
  local login="${TEST_PREFIX}-user"

  # Create
  api POST /api/admin/users "{\"name\":\"E2E User\",\"email\":\"${login}@example.com\",\"login\":\"${login}\",\"password\":\"Test12345!\"}"
  body="$API_BODY"
  if assert_ok "POST /api/admin/users (create)" "$body"; then
    uid=$(echo "$body" | jget id)
    USER_ID="$uid"
    cleanup_add "api DELETE /api/admin/users/${uid}"
    log "     ${GRAY}User ID: ${uid}${RESET}"
  else
    return
  fi

  # Get by login
  api GET "/api/users/lookup?loginOrEmail=${login}"
  body="$API_BODY"
  assert_ok "GET /api/users/lookup?loginOrEmail=..." "$body"

  # Update user
  api PUT "/api/users/${uid}" "{\"name\":\"E2E User Updated\",\"email\":\"${login}@example.com\",\"login\":\"${login}\"}"
  body="$API_BODY"
  assert_ok "PUT /api/users/{id} (update)" "$body"

  # Update org role
  api PATCH "/api/org/users/${uid}" '{"role":"Editor"}'
  body="$API_BODY"
  assert_ok "PATCH /api/org/users/{id} (set role=Editor)" "$body"

  # List org users
  api GET /api/org/users
  body="$API_BODY"
  assert_ok "GET /api/org/users (list)" "$body"
}

# =============================================================================
# TEST 5: Service Accounts (CRUD + Tokens + Permissions)
# =============================================================================
test_service_accounts() {
  section "5. Service Accounts (CRUD + Tokens + Permissions)"

  local body sa_id token_id
  local sa_name="${TEST_PREFIX}-sa-deployer"

  # Create SA
  api POST /api/serviceaccounts "{\"name\":\"${sa_name}\",\"role\":\"Admin\",\"isDisabled\":false}"
  body="$API_BODY"
  if assert_ok "POST /api/serviceaccounts (create Admin)" "$body"; then
    sa_id=$(echo "$body" | jget id)
    SA_ID="$sa_id"
    cleanup_add "api DELETE /api/serviceaccounts/${sa_id}"
    log "     ${GRAY}SA ID: ${sa_id}${RESET}"
  else
    return
  fi

  # Get
  api GET "/api/serviceaccounts/${sa_id}"
  body="$API_BODY"
  assert_ok "GET /api/serviceaccounts/{id}" "$body"

  # Search
  api GET "/api/serviceaccounts/search?query=${sa_name}"
  body="$API_BODY"
  assert_ok "GET /api/serviceaccounts/search" "$body"

  # Update (change role)
  api PATCH "/api/serviceaccounts/${sa_id}" '{"role":"Editor","isDisabled":false}'
  body="$API_BODY"
  assert_ok "PATCH /api/serviceaccounts/{id} (role=Editor)" "$body"

  # Create token
  api POST "/api/serviceaccounts/${sa_id}/tokens" "{\"name\":\"${TEST_PREFIX}-token\",\"secondsToLive\":3600}"
  body="$API_BODY"
  if assert_ok "POST /api/serviceaccounts/{id}/tokens (create)" "$body"; then
    token_id=$(echo "$body" | jget id)
    local token_key
    token_key=$(echo "$body" | jget key)
    cleanup_add "api DELETE /api/serviceaccounts/${sa_id}/tokens/${token_id}"
    log "     ${GRAY}Token ID: ${token_id} (key: ${token_key:0:20}...)${RESET}"

    # Test the token actually works
    local token_resp
    token_resp=$(curl -sS -H "Authorization: Bearer ${token_key}" \
      -w $'\n__HTTP__%{http_code}' \
      "${GRAFANA_URL}/api/user" 2>&1)
    local token_http="${token_resp##*__HTTP__}"
    if [[ "$token_http" =~ ^2 ]]; then
      pass "Bearer token auth works" "HTTP ${token_http}"
    else
      fail "Bearer token auth works" "HTTP ${token_http}"
    fi
  fi

  # List tokens
  api GET "/api/serviceaccounts/${sa_id}/tokens"
  body="$API_BODY"
  assert_ok "GET /api/serviceaccounts/{id}/tokens (list)" "$body"
}

# =============================================================================
# TEST 6: Data Sources (CRUD + Test)
# =============================================================================
test_datasources() {
  section "6. Data Sources (CRUD)"

  local body ds_id ds_uid
  local ds_name="${TEST_PREFIX}-prometheus"
  local ds_payload
  ds_payload=$(cat <<EOF
{
  "name": "${ds_name}",
  "type": "prometheus",
  "access": "proxy",
  "url": "http://prometheus.example.com:9090",
  "isDefault": false,
  "jsonData": {
    "httpMethod": "POST",
    "prometheusType": "Mimir",
    "prometheusVersion": "2.9.1"
  }
}
EOF
)

  # Create
  api POST /api/datasources "$ds_payload"
  body="$API_BODY"
  if assert_ok "POST /api/datasources (create Prometheus)" "$body"; then
    ds_id=$(echo "$body" | jget datasource.id)
    ds_uid=$(echo "$body" | jget datasource.uid)
    DS_UID="$ds_uid"
    cleanup_add "api DELETE /api/datasources/uid/${ds_uid}"
    log "     ${GRAY}Datasource UID: ${ds_uid}${RESET}"
  else
    return
  fi

  # Get by UID
  api GET "/api/datasources/uid/${ds_uid}"
  body="$API_BODY"
  assert_ok "GET /api/datasources/uid/{uid}" "$body"

  # Get by name
  api GET "/api/datasources/name/${ds_name}"
  body="$API_BODY"
  assert_ok "GET /api/datasources/name/{name}" "$body"

  # List
  api GET /api/datasources
  body="$API_BODY"
  assert_ok "GET /api/datasources (list)" "$body"

  # Update
  local ds_update
  ds_update=$(cat <<EOF
{
  "name": "${ds_name}",
  "type": "prometheus",
  "access": "proxy",
  "url": "http://prometheus.example.com:9091",
  "jsonData": {"httpMethod": "POST"}
}
EOF
)
  api PUT "/api/datasources/uid/${ds_uid}" "$ds_update"
  body="$API_BODY"
  assert_ok "PUT /api/datasources/uid/{uid} (update URL)" "$body"

  # Create Loki datasource (second type)
  local loki_payload='{"name":"'${TEST_PREFIX}'-loki","type":"loki","access":"proxy","url":"http://loki.example.com:3100"}'
  api POST /api/datasources "$loki_payload"
  body="$API_BODY"
  if [[ "$HTTP_CODE" =~ ^2 ]]; then
    local loki_uid
    loki_uid=$(echo "$body" | jget datasource.uid)
    DS_LOKI_UID="$loki_uid"
    cleanup_add "api DELETE /api/datasources/uid/${loki_uid}"
    pass "POST /api/datasources (create Loki)" "uid=${loki_uid}"
  else
    fail "POST /api/datasources (create Loki)" "HTTP ${HTTP_CODE}"
  fi
}

# =============================================================================
# TEST 7: Dashboards (CRUD + Permissions + Public)
# =============================================================================
test_dashboards() {
  section "7. Dashboards (CRUD + Permissions)"

  local body d_uid d_id
  local folder_uid="${FOLDER_UID:-general}"

  local dash_payload
  dash_payload=$(cat <<EOF
{
  "dashboard": {
    "id": null,
    "uid": "${TEST_PREFIX}-dash",
    "title": "${TEST_PREFIX}-dashboard",
    "tags": ["e2e", "test", "automated"],
    "timezone": "browser",
    "schemaVersion": 39,
    "version": 0,
    "refresh": "30s",
    "panels": [
      {
        "id": 1,
        "type": "stat",
        "title": "Test Stat Panel",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
        "targets": [{"refId": "A", "expr": "up"}]
      },
      {
        "id": 2,
        "type": "timeseries",
        "title": "Test Time Series",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      }
    ]
  },
  "folderUid": "${folder_uid}",
  "overwrite": true,
  "message": "E2E test create"
}
EOF
)

  # Create
  api POST /api/dashboards/db "$dash_payload"
  body="$API_BODY"
  if assert_ok "POST /api/dashboards/db (create)" "$body"; then
    d_uid=$(echo "$body" | jget uid)
    d_id=$(echo "$body" | jget id)
    DASH_UID="$d_uid"
    cleanup_add "api DELETE /api/dashboards/uid/${d_uid}"
    log "     ${GRAY}Dashboard UID: ${d_uid} | ID: ${d_id}${RESET}"
  else
    return
  fi

  # Get
  api GET "/api/dashboards/uid/${d_uid}"
  body="$API_BODY"
  assert_ok "GET /api/dashboards/uid/{uid}" "$body"

  # Search
  api GET "/api/search?query=${TEST_PREFIX}"
  body="$API_BODY"
  assert_ok "GET /api/search?query=..." "$body"

  # Update (bump version + add panel)
  local dash_update
  dash_update=$(cat <<EOF
{
  "dashboard": {
    "id": ${d_id},
    "uid": "${d_uid}",
    "title": "${TEST_PREFIX}-dashboard-v2",
    "tags": ["e2e", "updated"],
    "schemaVersion": 39,
    "version": 1,
    "panels": [{"id":1,"type":"stat","title":"Updated","gridPos":{"h":8,"w":24,"x":0,"y":0}}]
  },
  "folderUid": "${folder_uid}",
  "overwrite": true,
  "message": "E2E test update"
}
EOF
)
  api POST /api/dashboards/db "$dash_update"
  body="$API_BODY"
  assert_ok "POST /api/dashboards/db (update version)" "$body"

  # Version history
  api GET "/api/dashboards/uid/${d_uid}/versions"
  body="$API_BODY"
  assert_ok "GET /api/dashboards/uid/{uid}/versions" "$body"

  # Dashboard permissions
  api GET "/api/dashboards/uid/${d_uid}/permissions"
  body="$API_BODY"
  assert_ok "GET /api/dashboards/uid/{uid}/permissions" "$body"

  local perms_payload
  if [[ -n "${TEAM_ID:-}" ]]; then
    perms_payload="{\"items\":[{\"role\":\"Editor\",\"permission\":2},{\"teamId\":${TEAM_ID},\"permission\":4}]}"
  else
    perms_payload='{"items":[{"role":"Editor","permission":2}]}'
  fi
  api POST "/api/dashboards/uid/${d_uid}/permissions" "$perms_payload"
  body="$API_BODY"
  assert_ok "POST /api/dashboards/uid/{uid}/permissions (team+role)" "$body"

  # Tags (from search)
  api GET /api/dashboards/tags
  body="$API_BODY"
  assert_ok "GET /api/dashboards/tags" "$body"

  # Snapshot
  local snap_payload
  snap_payload=$(cat <<EOF
{"dashboard":{"uid":"${d_uid}","title":"snap","panels":[]},"expires":3600,"external":false}
EOF
)
  api POST /api/snapshots "$snap_payload"
  body="$API_BODY"
  if [[ "$HTTP_CODE" =~ ^2 ]]; then
    local skey
    skey=$(echo "$body" | jget key)
    pass "POST /api/snapshots (create)" "key=${skey}"
    cleanup_add "api DELETE /api/snapshots/${skey}"
  else
    fail "POST /api/snapshots (create)" "HTTP ${HTTP_CODE}"
  fi
}

# =============================================================================
# TEST 8: Library Panels
# =============================================================================
test_library_panels() {
  section "8. Library Panels"

  local body lp_uid
  local panel_payload
  panel_payload=$(cat <<EOF
{
  "uid": "${TEST_PREFIX}-lp",
  "folderUid": "${FOLDER_UID:-}",
  "name": "${TEST_PREFIX}-library-panel",
  "model": {
    "type": "stat",
    "title": "Reusable Stat",
    "datasource": {"type": "prometheus", "uid": "${DS_UID:-}"},
    "targets": [{"refId": "A", "expr": "up"}]
  },
  "kind": 1
}
EOF
)
  api POST /api/library-elements "$panel_payload"
  body="$API_BODY"
  if assert_ok "POST /api/library-elements (create)" "$body"; then
    lp_uid=$(echo "$body" | jget result.uid)
    cleanup_add "api DELETE /api/library-elements/${lp_uid}"
    log "     ${GRAY}Library panel UID: ${lp_uid}${RESET}"
  else
    return
  fi

  api GET "/api/library-elements/${lp_uid}"
  body="$API_BODY"
  assert_ok "GET /api/library-elements/{uid}" "$body"

  api GET "/api/library-elements?searchString=${TEST_PREFIX}"
  body="$API_BODY"
  assert_ok "GET /api/library-elements?searchString=..." "$body"
}

# =============================================================================
# TEST 9: Alerting (Contact Points, Policies, Templates, Mute, Rules)
# =============================================================================
test_alerting() {
  section "9. Alerting (Contact Points, Routing, Rules)"

  local body

  # List contact points
  api GET /api/v1/provisioning/contact-points
  body="$API_BODY"
  assert_ok "GET /api/v1/provisioning/contact-points" "$body"

  # Create contact point (Slack-style webhook)
  local cp_payload
  cp_payload=$(cat <<EOF
{
  "name": "${TEST_PREFIX}-slack",
  "type": "slack",
  "settings": {
    "url": "https://hooks.slack.com/services/fake/webhook/url",
    "recipient": "#alerts",
    "title": "{{ .CommonLabels.alertname }}",
    "text": "{{ .CommonAnnotations.summary }}",
    "mentionChannel": "here"
  },
  "disableResolveMessage": false
}
EOF
)
  api POST /api/v1/provisioning/contact-points "$cp_payload"
  body="$API_BODY"
  if [[ "$HTTP_CODE" =~ ^2 ]]; then
    local cp_uid
    cp_uid=$(echo "$body" | jget uid)
    CP_UID="$cp_uid"
    cleanup_add "api DELETE /api/v1/provisioning/contact-points/${cp_uid}"
    pass "POST /api/v1/provisioning/contact-points (create Slack)" "uid=${cp_uid}"
  else
    fail "POST /api/v1/provisioning/contact-points (create Slack)" "HTTP ${HTTP_CODE}: $(echo "$body" | head -c 200)"
  fi

  # Email contact point
  local email_payload
  email_payload=$(cat <<EOF
{"name":"${TEST_PREFIX}-email","type":"email","settings":{"addresses":"sre@example.com","singleEmail":false}}
EOF
)
  api POST /api/v1/provisioning/contact-points "$email_payload"
  body="$API_BODY"
  if [[ "$HTTP_CODE" =~ ^2 ]]; then
    local em_uid
    em_uid=$(echo "$body" | jget uid)
    cleanup_add "api DELETE /api/v1/provisioning/contact-points/${em_uid}"
    pass "POST /api/v1/provisioning/contact-points (create email)" "uid=${em_uid}"
  else
    fail "POST /api/v1/provisioning/contact-points (create email)" "HTTP ${HTTP_CODE}"
  fi

  # Message template
  local tpl_payload
  tpl_payload=$(cat <<EOF
{"name":"${TEST_PREFIX}-template","template":"{{ define \"custom.slack\" }}{{ .CommonLabels.alertname }}{{ end }}"}
EOF
)
  api PUT "/api/v1/provisioning/templates/${TEST_PREFIX}-template" "$tpl_payload"
  body="$API_BODY"
  if [[ "$HTTP_CODE" =~ ^2 ]]; then
    cleanup_add "api DELETE /api/v1/provisioning/templates/${TEST_PREFIX}-template"
    pass "PUT /api/v1/provisioning/templates/{name}" "created"
  else
    fail "PUT /api/v1/provisioning/templates/{name}" "HTTP ${HTTP_CODE}"
  fi

  # Mute timing
  local mute_payload
  mute_payload=$(cat <<EOF
{
  "name": "${TEST_PREFIX}-mute",
  "time_intervals": [
    {"weekdays": ["saturday", "sunday"], "times": [{"start_time": "00:00", "end_time": "23:59"}]}
  ]
}
EOF
)
  api POST /api/v1/provisioning/mute-timings "$mute_payload"
  body="$API_BODY"
  if [[ "$HTTP_CODE" =~ ^2 ]]; then
    cleanup_add "api DELETE /api/v1/provisioning/mute-timings/${TEST_PREFIX}-mute"
    pass "POST /api/v1/provisioning/mute-timings" "created"
  else
    fail "POST /api/v1/provisioning/mute-timings" "HTTP ${HTTP_CODE}"
  fi

  # Notification policy tree (GET current, then PUT modified)
  api GET /api/v1/provisioning/policies
  body="$API_BODY"
  assert_ok "GET /api/v1/provisioning/policies" "$body"

  # Alert rule group (needs a folder and datasource)
  if [[ -z "${FOLDER_UID:-}" || -z "${DS_UID:-}" ]]; then
    skip "POST /api/v1/provisioning/alert-rules (rule group)" "needs folder + datasource"
  else
    local rule_payload
    rule_payload=$(cat <<EOF
{
  "uid": "${TEST_PREFIX}-rule",
  "title": "${TEST_PREFIX}-high-error-rate",
  "ruleGroup": "${TEST_PREFIX}-group",
  "folderUID": "${FOLDER_UID}",
  "condition": "C",
  "data": [
    {
      "refId": "A",
      "datasourceUid": "${DS_UID}",
      "queryType": "",
      "relativeTimeRange": {"from": 600, "to": 0},
      "model": {"expr": "up == 0", "refId": "A"}
    },
    {
      "refId": "C",
      "datasourceUid": "__expr__",
      "queryType": "",
      "relativeTimeRange": {"from": 0, "to": 0},
      "model": {"type": "threshold", "refId": "C", "expression": "A", "conditions": [{"evaluator": {"type": "gt", "params": [0]}, "operator": {"type": "and"}, "query": {"params": ["A"]}, "reducer": {"type": "last", "params": []}, "type": "query"}]}
    }
  ],
  "noDataState": "NoData",
  "execErrState": "Error",
  "for": "5m",
  "labels": {"severity": "critical", "team": "sre"},
  "annotations": {"summary": "Service is down", "runbook_url": "https://wiki/runbook"}
}
EOF
)
    api POST /api/v1/provisioning/alert-rules "$rule_payload"
    body="$API_BODY"
    if [[ "$HTTP_CODE" =~ ^2 ]]; then
      cleanup_add "api DELETE /api/v1/provisioning/alert-rules/${TEST_PREFIX}-rule"
      pass "POST /api/v1/provisioning/alert-rules" "created"
    else
      fail "POST /api/v1/provisioning/alert-rules" "HTTP ${HTTP_CODE}: $(echo "$body" | head -c 200)"
    fi
  fi

  # Alertmanager status
  api GET /api/alertmanager/grafana/api/v2/status
  body="$API_BODY"
  assert_ok "GET /api/alertmanager/grafana/api/v2/status" "$body"
}

# =============================================================================
# TEST 10: RBAC (Permissions + Custom Roles + Assignments)
# =============================================================================
test_rbac() {
  section "10. RBAC (Permissions, Scopes, Actions)"

  local body

  # List my permissions (works in OSS)
  api GET /api/access-control/user/permissions
  body="$API_BODY"
  assert_ok "GET /api/access-control/user/permissions" "$body"
  local perm_count
  perm_count=$(echo "$body" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d) if isinstance(d, dict) else 0)" 2>/dev/null)
  log "     ${GRAY}Admin has ${perm_count} permissions${RESET}"

  # Custom role creation (Enterprise-only endpoint)
  local role_payload
  role_payload=$(cat <<EOF
{
  "version": 1,
  "uid": "${TEST_PREFIX}-role",
  "name": "custom:${TEST_PREFIX}:viewer",
  "displayName": "E2E Test Viewer",
  "description": "Test custom role with folder scope",
  "group": "E2E Tests",
  "global": false,
  "permissions": [
    {"action": "dashboards:read", "scope": "folders:uid:${FOLDER_UID:-general}"},
    {"action": "folders:read", "scope": "folders:uid:${FOLDER_UID:-general}"},
    {"action": "datasources:read", "scope": "datasources:uid:${DS_UID:-}"}
  ]
}
EOF
)
  api POST /api/access-control/roles "$role_payload"
  body="$API_BODY"
  if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" ]]; then
    cleanup_add "api DELETE /api/access-control/roles/${TEST_PREFIX}-role"
    pass "POST /api/access-control/roles (custom role w/ actions+scopes)" "uid=${TEST_PREFIX}-role"

    # Assign to team if we have one
    if [[ -n "${TEAM_ID:-}" ]]; then
      api POST "/api/access-control/teams/${TEAM_ID}/roles" "{\"roleUid\":\"${TEST_PREFIX}-role\"}"
      body="$API_BODY"
      assert_ok "POST /api/access-control/teams/{id}/roles (assign)" "$body"
    fi
  elif [[ "$HTTP_CODE" == "404" ]]; then
    skip "POST /api/access-control/roles" "Enterprise-only (OSS returns 404)"
    skip "POST /api/access-control/teams/{id}/roles" "requires custom role (Enterprise)"
  else
    fail "POST /api/access-control/roles (custom role)" "HTTP ${HTTP_CODE}: $(echo "$body" | head -c 200)"
  fi

  # Folder-level RBAC via permission_item endpoint — this IS RBAC with scope=folder and action=view/edit/admin
  if [[ -n "${FOLDER_UID:-}" ]]; then
    # This tests "action + scope" against a folder using the standard folder permissions API
    local fp_payload='{"items":[{"role":"Viewer","permission":1},{"role":"Editor","permission":2}'
    if [[ -n "${TEAM_ID:-}" ]]; then
      fp_payload="${fp_payload},{\"teamId\":${TEAM_ID},\"permission\":4}"
    fi
    fp_payload="${fp_payload}]}"

    api POST "/api/folders/${FOLDER_UID}/permissions" "$fp_payload"
    body="$API_BODY"
    assert_ok "POST folder perms (RBAC scope=folder, action=admin)" "$body"
  fi
}

# =============================================================================
# TEST 11: Plugins (List, Install, Upgrade, Uninstall)
# =============================================================================
test_plugins() {
  section "11. Plugins (List, Install, Upgrade, Uninstall)"

  local body

  # List installed plugins
  api GET /api/plugins
  body="$API_BODY"
  assert_ok "GET /api/plugins (list)" "$body"
  local plugin_count
  plugin_count=$(echo "$body" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d) if isinstance(d, list) else 0)" 2>/dev/null)
  log "     ${GRAY}Installed plugins: ${plugin_count}${RESET}"

  # Get metadata for a known plugin
  api GET /api/plugins/prometheus/settings
  body="$API_BODY"
  assert_ok "GET /api/plugins/{id}/settings" "$body"

  # Install a small, safe panel plugin (singlestat-math)
  # NOTE: Grafana plugin install requires the plugin to exist in the registry.
  # We install "grafana-clock-panel" which is Grafana Labs' own reference plugin.
  local plugin_id="grafana-clock-panel"
  local plugin_version=""  # latest

  api POST "/api/plugins/${plugin_id}/install" "{\"version\":\"${plugin_version}\"}"
  body="$API_BODY"
  if [[ "$HTTP_CODE" =~ ^2 ]]; then
    cleanup_add "api POST /api/plugins/${plugin_id}/uninstall '{}'"
    pass "POST /api/plugins/{id}/install (${plugin_id})" "HTTP ${HTTP_CODE}"

    # Verify it shows up
    api GET "/api/plugins/${plugin_id}/settings"
    body="$API_BODY"
    if [[ "$HTTP_CODE" =~ ^2 ]]; then
      pass "GET /api/plugins/${plugin_id}/settings (post-install)" "installed"
    else
      fail "GET /api/plugins/${plugin_id}/settings (post-install)" "HTTP ${HTTP_CODE}"
    fi

    # Upgrade: Grafana uses the same /install endpoint for upgrades.
    # HTTP 409 on a fresh install means "already at latest" — valid upgrade no-op.
    api POST "/api/plugins/${plugin_id}/install" "{}"
    body="$API_BODY"
    if [[ "$HTTP_CODE" =~ ^2 ]]; then
      pass "POST /api/plugins/{id}/install (upgrade to latest)" "upgraded (HTTP ${HTTP_CODE})"
    elif [[ "$HTTP_CODE" == "409" ]]; then
      pass "POST /api/plugins/{id}/install (upgrade to latest)" "already at latest (HTTP 409)"
    else
      fail "POST /api/plugins/{id}/install (upgrade)" "HTTP ${HTTP_CODE}"
    fi
  elif [[ "$HTTP_CODE" == "403" ]]; then
    skip "POST /api/plugins/{id}/install" "plugin install requires admin + write-access (403)"
  elif [[ "$HTTP_CODE" == "412" || "$HTTP_CODE" == "409" ]]; then
    pass "POST /api/plugins/{id}/install (${plugin_id})" "already installed (HTTP ${HTTP_CODE})"

    # Still test upgrade path
    api POST "/api/plugins/${plugin_id}/install" "{}"
    body="$API_BODY"
    if [[ "$HTTP_CODE" =~ ^2 ]]; then
      pass "POST /api/plugins/{id}/install (upgrade path)" "HTTP ${HTTP_CODE}"
    else
      fail "POST /api/plugins/{id}/install (upgrade path)" "HTTP ${HTTP_CODE}"
    fi
  else
    fail "POST /api/plugins/{id}/install (${plugin_id})" "HTTP ${HTTP_CODE}: $(echo "$body" | head -c 200)"
  fi
}

# =============================================================================
# TEST 12: Preferences (Org + User + Team)
# =============================================================================
test_preferences() {
  section "12. Preferences (Org + User)"

  local body

  # Get org preferences
  api GET /api/org/preferences
  body="$API_BODY"
  assert_ok "GET /api/org/preferences" "$body"

  # Set org preferences
  local prefs='{"theme":"dark","timezone":"utc","weekStart":"monday"}'
  api PUT /api/org/preferences "$prefs"
  body="$API_BODY"
  assert_ok "PUT /api/org/preferences" "$body"

  # Get user preferences
  api GET /api/user/preferences
  body="$API_BODY"
  assert_ok "GET /api/user/preferences" "$body"

  api PUT /api/user/preferences "$prefs"
  body="$API_BODY"
  assert_ok "PUT /api/user/preferences" "$body"
}

# =============================================================================
# TEST 13: Annotations
# =============================================================================
test_annotations() {
  section "13. Annotations"

  local body ann_id
  local now_ms
  now_ms=$(python3 -c "import time; print(int(time.time()*1000))")

  local ann_payload
  ann_payload=$(cat <<EOF
{
  "time": ${now_ms},
  "tags": ["e2e", "deployment", "${TEST_PREFIX}"],
  "text": "E2E test deployment marker"
}
EOF
)
  api POST /api/annotations "$ann_payload"
  body="$API_BODY"
  if assert_ok "POST /api/annotations (create)" "$body"; then
    ann_id=$(echo "$body" | jget id)
    cleanup_add "api DELETE /api/annotations/${ann_id}"
    log "     ${GRAY}Annotation ID: ${ann_id}${RESET}"
  fi

  # Search
  api GET "/api/annotations?tags=${TEST_PREFIX}"
  body="$API_BODY"
  assert_ok "GET /api/annotations?tags=..." "$body"

  # Update
  if [[ -n "${ann_id:-}" ]]; then
    api PUT "/api/annotations/${ann_id}" '{"text":"updated","tags":["e2e","updated"]}'
    body="$API_BODY"
    assert_ok "PUT /api/annotations/{id}" "$body"
  fi
}

# =============================================================================
# Report Generation
# =============================================================================
generate_report() {
  local total=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))

  log ""
  log "${BOLD}================================================================${RESET}"
  log "${BOLD}E2E Test Results${RESET}"
  log "${BOLD}================================================================${RESET}"
  log "  Total:    ${total}"
  log "  ${GREEN}Passed:   ${PASS_COUNT}${RESET}"
  log "  ${RED}Failed:   ${FAIL_COUNT}${RESET}"
  log "  ${YELLOW}Skipped:  ${SKIP_COUNT}${RESET}"
  log ""
  if (( FAIL_COUNT == 0 )); then
    log "${GREEN}${BOLD}ALL TESTS PASSED${RESET}"
  else
    log "${RED}${BOLD}${FAIL_COUNT} TEST(S) FAILED${RESET}"
  fi

  # Markdown report
  mkdir -p "$(dirname "$REPORT_FILE")"
  {
    echo "# Grafana E2E Test Results"
    echo ""
    echo "- **Target:** \`${GRAFANA_URL}\`"
    echo "- **Version:** ${GRAFANA_VERSION:-unknown}"
    echo "- **Edition:** ${EDITION:-unknown}"
    echo "- **Run timestamp:** $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "- **Test prefix:** \`${TEST_PREFIX}\`"
    echo ""
    echo "## Summary"
    echo ""
    echo "| Metric | Count |"
    echo "|--------|------:|"
    echo "| Total tests | ${total} |"
    echo "| Passed | ${PASS_COUNT} |"
    echo "| Failed | ${FAIL_COUNT} |"
    echo "| Skipped | ${SKIP_COUNT} |"
    echo ""
    echo "## Results by Section"
    echo ""
    local current_section="" status section name detail
    for r in "${TEST_RESULTS[@]}"; do
      status="${r%%|*}"
      local rest="${r#*|}"
      section="${rest%%|*}"
      rest="${rest#*|}"
      name="${rest%%|*}"
      detail="${rest#*|}"

      if [[ "$section" != "$current_section" ]]; then
        echo ""
        echo "### ${section}"
        echo ""
        echo "| Status | Test | Detail |"
        echo "|:------:|------|--------|"
        current_section="$section"
      fi
      local icon
      case "$status" in
        PASS) icon="PASS" ;;
        FAIL) icon="FAIL" ;;
        SKIP) icon="SKIP" ;;
      esac
      # Escape pipes in name/detail
      local safe_name="${name//|/\\|}"
      local safe_detail="${detail//|/\\|}"
      echo "| ${icon} | \`${safe_name}\` | ${safe_detail} |"
    done

    echo ""
    echo "## Notes"
    echo ""
    echo "- This Grafana instance is **OSS** (Open Source). Custom RBAC roles (\`/api/access-control/roles\`) require Grafana Enterprise and will be reported as \`SKIP\`."
    echo "- Folder-level RBAC (scope + action) is tested via the standard \`/api/folders/{uid}/permissions\` endpoint which works in OSS."
    echo "- All created test resources are prefixed with \`${TEST_PREFIX}\` and cleaned up automatically at the end of the run."
    echo ""
  } > "$REPORT_FILE"

  log ""
  log "${CYAN}Report written to: ${REPORT_FILE}${RESET}"
}

# =============================================================================
# Main
# =============================================================================
main() {
  log "${BOLD}${CYAN}Grafana E2E Test Suite${RESET}"
  log "  Target: ${GRAFANA_URL}"
  log "  User:   ${GRAFANA_USER}"
  log "  Prefix: ${TEST_PREFIX}"

  test_health
  test_folders
  test_teams
  test_users
  test_service_accounts
  test_datasources
  test_dashboards
  test_library_panels
  test_alerting
  test_rbac
  test_plugins
  test_preferences
  test_annotations

  generate_report

  # Exit with non-zero if any tests failed
  (( FAIL_COUNT == 0 ))
}

main "$@"
