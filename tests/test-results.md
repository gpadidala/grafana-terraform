# Grafana E2E Test Results

- **Target:** `http://localhost:3200`
- **Version:** 11.6.4
- **Edition:** Open Source
- **Run timestamp:** 2026-04-14 16:31:13 MST
- **Test prefix:** `e2e-1776209468`

## Summary

| Metric | Count |
|--------|------:|
| Total tests | 76 |
| Passed | 74 |
| Failed | 0 |
| Skipped | 2 |

## Results by Section


### 1. Health & Version

| Status | Test | Detail |
|:------:|------|--------|
| PASS | `GET /api/health` | HTTP 200 |
| PASS | `GET /api/org (current org)` | HTTP 200 |
| PASS | `GET /api/user (admin auth)` | HTTP 200 |
| PASS | `GET /api/frontend/settings` | HTTP 200 |

### 2. Folders (CRUD + Permissions)

| Status | Test | Detail |
|:------:|------|--------|
| PASS | `POST /api/folders (create)` | HTTP 200 |
| PASS | `GET /api/folders/{uid}` | HTTP 200 |
| PASS | `GET /api/folders (list)` | HTTP 200 |
| PASS | `PUT /api/folders/{uid} (update title)` | HTTP 200 |
| PASS | `GET /api/folders/{uid}/permissions` | HTTP 200 |
| PASS | `POST /api/folders/{uid}/permissions (role-based)` | HTTP 200 |
| PASS | `GET /api/search?folderUIDs=... (scoped search)` | HTTP 200 |

### 3. Teams (CRUD + Members + Preferences)

| Status | Test | Detail |
|:------:|------|--------|
| PASS | `POST /api/teams (create)` | HTTP 200 |
| PASS | `GET /api/teams/{id}` | HTTP 200 |
| PASS | `GET /api/teams/search?name=...` | HTTP 200 |
| PASS | `PUT /api/teams/{id} (update email)` | HTTP 200 |
| PASS | `POST /api/teams (creator auto-added as member)` | admin is member |
| PASS | `POST /api/teams/{id}/members (re-add after remove)` | HTTP 200 |
| PASS | `GET /api/teams/{id}/members (list)` | HTTP 200 |
| PASS | `PUT /api/teams/{id}/preferences` | HTTP 200 |
| PASS | `GET /api/teams/{id}/preferences` | HTTP 200 |
| PASS | `DELETE /api/teams/{id}/members/{userId}` | HTTP 200 |
| PASS | `POST /api/teams (second team for scope tests)` | id=4 |

### 4. Users (CRUD)

| Status | Test | Detail |
|:------:|------|--------|
| PASS | `POST /api/admin/users (create)` | HTTP 200 |
| PASS | `GET /api/users/lookup?loginOrEmail=...` | HTTP 200 |
| PASS | `PUT /api/users/{id} (update)` | HTTP 200 |
| PASS | `PATCH /api/org/users/{id} (set role=Editor)` | HTTP 200 |
| PASS | `GET /api/org/users (list)` | HTTP 200 |

### 5. Service Accounts (CRUD + Tokens + Permissions)

| Status | Test | Detail |
|:------:|------|--------|
| PASS | `POST /api/serviceaccounts (create Admin)` | HTTP 201 |
| PASS | `GET /api/serviceaccounts/{id}` | HTTP 200 |
| PASS | `GET /api/serviceaccounts/search` | HTTP 200 |
| PASS | `PATCH /api/serviceaccounts/{id} (role=Editor)` | HTTP 200 |
| PASS | `POST /api/serviceaccounts/{id}/tokens (create)` | HTTP 200 |
| PASS | `Bearer token auth works` | HTTP 200 |
| PASS | `GET /api/serviceaccounts/{id}/tokens (list)` | HTTP 200 |

### 6. Data Sources (CRUD)

| Status | Test | Detail |
|:------:|------|--------|
| PASS | `POST /api/datasources (create Prometheus)` | HTTP 200 |
| PASS | `GET /api/datasources/uid/{uid}` | HTTP 200 |
| PASS | `GET /api/datasources/name/{name}` | HTTP 200 |
| PASS | `GET /api/datasources (list)` | HTTP 200 |
| PASS | `PUT /api/datasources/uid/{uid} (update URL)` | HTTP 200 |
| PASS | `POST /api/datasources (create Loki)` | uid=afj3zacpo9bswb |

### 7. Dashboards (CRUD + Permissions)

| Status | Test | Detail |
|:------:|------|--------|
| PASS | `POST /api/dashboards/db (create)` | HTTP 200 |
| PASS | `GET /api/dashboards/uid/{uid}` | HTTP 200 |
| PASS | `GET /api/search?query=...` | HTTP 200 |
| PASS | `POST /api/dashboards/db (update version)` | HTTP 200 |
| PASS | `GET /api/dashboards/uid/{uid}/versions` | HTTP 200 |
| PASS | `GET /api/dashboards/uid/{uid}/permissions` | HTTP 200 |
| PASS | `POST /api/dashboards/uid/{uid}/permissions (team+role)` | HTTP 200 |
| PASS | `GET /api/dashboards/tags` | HTTP 200 |
| PASS | `POST /api/snapshots (create)` | key=TVfaU1G40V6PIdxoTzqn49AAcZqZy4mf |

### 8. Library Panels

| Status | Test | Detail |
|:------:|------|--------|
| PASS | `POST /api/library-elements (create)` | HTTP 200 |
| PASS | `GET /api/library-elements/{uid}` | HTTP 200 |
| PASS | `GET /api/library-elements?searchString=...` | HTTP 200 |

### 9. Alerting (Contact Points, Routing, Rules)

| Status | Test | Detail |
|:------:|------|--------|
| PASS | `GET /api/v1/provisioning/contact-points` | HTTP 200 |
| PASS | `POST /api/v1/provisioning/contact-points (create Slack)` | uid=cfj3zadzvdq0wa |
| PASS | `POST /api/v1/provisioning/contact-points (create email)` | uid=ffj3zae417mrkd |
| PASS | `PUT /api/v1/provisioning/templates/{name}` | created |
| PASS | `POST /api/v1/provisioning/mute-timings` | created |
| PASS | `GET /api/v1/provisioning/policies` | HTTP 200 |
| PASS | `POST /api/v1/provisioning/alert-rules` | created |
| PASS | `GET /api/alertmanager/grafana/api/v2/status` | HTTP 200 |

### 10. RBAC (Permissions, Scopes, Actions)

| Status | Test | Detail |
|:------:|------|--------|
| PASS | `GET /api/access-control/user/permissions` | HTTP 200 |
| SKIP | `POST /api/access-control/roles` | Enterprise-only (OSS returns 404) |
| SKIP | `POST /api/access-control/teams/{id}/roles` | requires custom role (Enterprise) |
| PASS | `POST folder perms (RBAC scope=folder, action=admin)` | HTTP 200 |

### 11. Plugins (List, Install, Upgrade, Uninstall)

| Status | Test | Detail |
|:------:|------|--------|
| PASS | `GET /api/plugins (list)` | HTTP 200 |
| PASS | `GET /api/plugins/{id}/settings` | HTTP 200 |
| PASS | `POST /api/plugins/{id}/install (grafana-clock-panel)` | HTTP 200 |
| PASS | `GET /api/plugins/grafana-clock-panel/settings (post-install)` | installed |
| PASS | `POST /api/plugins/{id}/install (upgrade to latest)` | already at latest (HTTP 409) |

### 12. Preferences (Org + User)

| Status | Test | Detail |
|:------:|------|--------|
| PASS | `GET /api/org/preferences` | HTTP 200 |
| PASS | `PUT /api/org/preferences` | HTTP 200 |
| PASS | `GET /api/user/preferences` | HTTP 200 |
| PASS | `PUT /api/user/preferences` | HTTP 200 |

### 13. Annotations

| Status | Test | Detail |
|:------:|------|--------|
| PASS | `POST /api/annotations (create)` | HTTP 200 |
| PASS | `GET /api/annotations?tags=...` | HTTP 200 |
| PASS | `PUT /api/annotations/{id}` | HTTP 200 |

## Notes

- This Grafana instance is **OSS** (Open Source). Custom RBAC roles (`/api/access-control/roles`) require Grafana Enterprise and will be reported as `SKIP`.
- Folder-level RBAC (scope + action) is tested via the standard `/api/folders/{uid}/permissions` endpoint which works in OSS.
- All created test resources are prefixed with `e2e-1776209468` and cleaned up automatically at the end of the run.

