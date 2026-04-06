<p align="center">
  <img src="docs/images/grafana-terraform-banner.png" alt="Grafana Enterprise Terraform" width="800"/>
</p>

<h1 align="center">Grafana Enterprise Terraform</h1>

<p align="center">
  <strong>100% Grafana-as-Code. Zero ClickOps. Every resource managed through Terraform.</strong>
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> &bull;
  <a href="#architecture">Architecture</a> &bull;
  <a href="#modules">Modules</a> &bull;
  <a href="#usage-guide">Usage Guide</a> &bull;
  <a href="#cicd">CI/CD</a> &bull;
  <a href="#videos">Videos</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Terraform-%3E%3D1.5.0-7B42BC?style=for-the-badge&logo=terraform" alt="Terraform">
  <img src="https://img.shields.io/badge/Grafana-Enterprise-F46800?style=for-the-badge&logo=grafana" alt="Grafana">
  <img src="https://img.shields.io/badge/Resources-30%2F30-00C853?style=for-the-badge" alt="Coverage">
  <img src="https://img.shields.io/badge/Version-1.0.0-blue?style=for-the-badge" alt="Version">
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge" alt="License">
</p>

---

## What Is This?

This Terraform codebase manages **every single Grafana resource type** available in the Grafana Terraform Provider. Nothing is done manually. Every click in the Grafana UI has a corresponding Terraform resource. Everything is versioned, auditable, and reproducible.

**30 resource types. 15 modules. 8 deployment phases. Zero manual configuration.**

Built for Fortune 500 scale: 5,000+ users across C-suite executives, VPs, Directors, Engineering Managers, SREs, DevOps, Network Engineers, Security Operations, and Developers.

<p align="center">
  <img src="docs/images/resource-coverage-overview.png" alt="30/30 Resource Coverage" width="700"/>
</p>

---

## Demo Videos

> Short walkthrough videos demonstrating key workflows.

| Video | Description | Duration |
|-------|-------------|----------|
| [<img src="docs/images/video-thumb-quickstart.png" width="120"/>](docs/videos/01-quickstart-setup.mp4) | **Quick Start Setup** - From zero to deployed in 5 minutes | 5 min |
| [<img src="docs/images/video-thumb-plan-apply.png" width="120"/>](docs/videos/02-plan-and-apply.mp4) | **Plan & Apply** - Running `make plan` and `make apply` with environment configs | 3 min |
| [<img src="docs/images/video-thumb-dashboard-export.png" width="120"/>](docs/videos/03-dashboard-export.mp4) | **Dashboard Export & Templatize** - Exporting existing dashboards and converting to templates | 4 min |
| [<img src="docs/images/video-thumb-cicd.png" width="120"/>](docs/videos/04-cicd-pipeline.mp4) | **CI/CD Pipeline** - PR validation, auto-staging deploy, manual prod promote | 6 min |
| [<img src="docs/images/video-thumb-lgtm-correlation.png" width="120"/>](docs/videos/05-lgtm-correlation.mp4) | **LGTM Correlation** - Click a metric spike, see the trace, see the logs, see the profile | 3 min |
| [<img src="docs/images/video-thumb-alerting.png" width="120"/>](docs/videos/06-alerting-setup.mp4) | **Alerting Setup** - Contact points, routing policies, and alert rules in action | 4 min |

---

## Screenshots

### Home Dashboard
<p align="center">
  <img src="docs/images/screenshot-home-dashboard.png" alt="Platform Home Dashboard" width="800"/>
  <br/><em>Platform Home with service health, quick navigation, and deployment annotations</em>
</p>

### Executive Command Center
<p align="center">
  <img src="docs/images/screenshot-executive-dashboard.png" alt="Executive Command Center" width="800"/>
  <br/><em>Business health at a glance - SLO compliance, availability trends, cost overview</em>
</p>

### Terraform Plan Output
<p align="center">
  <img src="docs/images/screenshot-terraform-plan.png" alt="Terraform Plan" width="800"/>
  <br/><em>terraform plan showing 30 resource types across all 8 phases</em>
</p>

### Folder & Permission Matrix
<p align="center">
  <img src="docs/images/screenshot-folder-permissions.png" alt="Folder Permissions" width="800"/>
  <br/><em>11 folders with team-based permission matrix (Admin/Edit/View)</em>
</p>

### Alerting Pipeline
<p align="center">
  <img src="docs/images/screenshot-alerting-routing.png" alt="Alert Routing" width="800"/>
  <br/><em>Severity-based routing: Critical to PagerDuty, Warning to Slack, Info to Email</em>
</p>

### LGTM Correlation Flow
<p align="center">
  <img src="docs/images/screenshot-lgtm-correlation.png" alt="LGTM Correlation" width="800"/>
  <br/><em>Metrics -> Traces -> Logs -> Profiles - all wired in Terraform</em>
</p>

### CI/CD Pipeline
<p align="center">
  <img src="docs/images/screenshot-cicd-pipeline.png" alt="CI/CD Pipeline" width="800"/>
  <br/><em>GitHub Actions: validate -> plan -> apply staging -> manual prod promote</em>
</p>

### Make Help
<p align="center">
  <img src="docs/images/screenshot-make-help.png" alt="Makefile Help" width="800"/>
  <br/><em>One-command operations with the Makefile</em>
</p>

---

## Architecture

### 8-Phase Deployment Order

Every resource is deployed in strict dependency order to avoid race conditions:

```
Phase 1: Organizations
    +-- grafana_organization
         |
Phase 2: Service Accounts + Users
    +-- grafana_service_account + tokens + permissions
    +-- grafana_user (admins, editors, viewers, break-glass)
         |
Phase 3: Teams
    +-- grafana_team (9 platform teams + custom)
    +-- grafana_team_external_group (SSO mapping)
         |
Phase 4: Folders + Data Sources
    +-- grafana_folder (11 folders, L0->L3 hierarchy)
    +-- grafana_folder_permission (team-based access)
    +-- grafana_data_source (Mimir, Loki, Tempo, Pyroscope, Alertmanager)
         |
Phase 5: Dashboards + Library Panels
    +-- grafana_dashboard (auto-discovered from /dashboards/*.json)
    +-- grafana_library_panel (breadcrumbs, stats, tables, DS status)
         |
Phase 6: Alerting
    +-- grafana_contact_point (Slack, PagerDuty, Email)
    +-- grafana_notification_policy (severity routing)
    +-- grafana_message_template (custom formats)
    +-- grafana_mute_timing (maintenance windows)
    +-- grafana_rule_group (alert rules)
         |
Phase 7: Permissions + RBAC
    +-- grafana_role (Executive, SRE, Developer, Network)
    +-- grafana_role_assignment (role -> team)
    +-- grafana_dashboard_permission (per-dashboard overrides)
    +-- grafana_dashboard_permission_item (granular items)
    +-- grafana_dashboard_public (public sharing)
         |
Phase 8: SSO + Reports + Playlists + Preferences
    +-- grafana_sso_settings (OAuth2 / GitHub / Google / Azure AD)
    +-- grafana_report (weekly exec, monthly SLO, daily SRE)
    +-- grafana_playlist (NOC, lobby, SRE displays)
    +-- grafana_organization_preferences (default home, theme, timezone)
    +-- grafana_team_preferences (9 teams -> 9 different home pages)
    +-- grafana_annotation (deployment marker)
```

### Data Source Correlations (LGTM + Pyroscope)

All 5 data sources are pre-wired with cross-linking:

```
Mimir (Metrics)                          Loki (Logs)
  +-- exemplarTraceIdDestinations          +-- derivedFields (traceID regex)
  |     \--> Tempo                         |     \--> Tempo
  +-- recording rules for SLO             |
                                           |
              Tempo (Traces)  <------------+
                +-- tracesToLogsV2     --> Loki
                +-- tracesToMetrics    --> Mimir
                +-- tracesToProfiles   --> Pyroscope
                +-- serviceMap         --> Mimir
                +-- nodeGraph          --> enabled
                +-- lokiSearch         --> Loki
                                           |
              Pyroscope (Profiles) <-------+
                +-- linked via Tempo's tracesToProfiles
```

**Result**: Click a metric spike -> see the trace -> see the logs -> see the CPU profile. All in one flow.

---

## Resource Coverage (30/30)

### Admin Level Activities (26 Resources)

| # | Terraform Resource | Module | Purpose |
|---|---|---|---|
| 1 | `grafana_organization` | `modules/organizations` | Multi-tenant org isolation |
| 2 | `grafana_service_account` | `modules/service-accounts` | API access identities |
| 3 | `grafana_service_account_token` | `modules/service-accounts` | Token generation for each SA |
| 4 | `grafana_service_account_permission` | `modules/service-accounts` | Fine-grained SA folder/dashboard access |
| 5 | `grafana_user` | `modules/users` | Local user provisioning |
| 6 | `grafana_team` | `modules/teams` | 9 default platform teams + custom |
| 7 | `grafana_team_external_group` | `modules/teams` | SSO/LDAP group mapping |
| 8 | `grafana_folder` | `modules/folders` | 11 folders (L0->L3 hierarchy) |
| 9 | `grafana_folder_permission` | `modules/folders` | Team-based folder access |
| 10 | `grafana_folder_permission_item` | `modules/folders` | Granular per-item permissions |
| 11 | `grafana_data_source` | `modules/datasources` | Mimir, Loki, Tempo, Pyroscope, Alertmanager |
| 12 | `grafana_data_source_config` | `modules/datasources` | Secure credential configuration |
| 13 | `grafana_dashboard` | `modules/dashboards` | Auto-discovered JSON deployment |
| 14 | `grafana_dashboard_permission` | `modules/dashboard-permissions` | Per-dashboard access overrides |
| 15 | `grafana_dashboard_permission_item` | `modules/dashboard-permissions` | Granular per-item permissions |
| 16 | `grafana_dashboard_public` | `modules/dashboard-permissions` | Public sharing (NOC/status pages) |
| 17 | `grafana_library_panel` | `modules/library-panels` | Reusable panels (breadcrumbs, stats) |
| 18 | `grafana_contact_point` | `modules/alerting` | Slack, PagerDuty, Email channels |
| 19 | `grafana_notification_policy` | `modules/alerting` | Severity-based alert routing |
| 20 | `grafana_message_template` | `modules/alerting` | Custom alert message templates |
| 21 | `grafana_mute_timing` | `modules/alerting` | Maintenance windows & deploy freezes |
| 22 | `grafana_rule_group` | `modules/alerting` | Alert rules (error rate, SLO burn) |
| 23 | `grafana_role` | `modules/rbac` | Custom RBAC roles |
| 24 | `grafana_role_assignment` | `modules/rbac` | Role -> Team assignment |
| 25 | `grafana_sso_settings` | `modules/sso` | OAuth2/GitHub/Google/Azure AD/SAML |
| 26 | `grafana_report` | `modules/reports` | Scheduled PDF reports (Enterprise) |

### User Level Activities (4 Resources)

| # | Terraform Resource | Module | Purpose |
|---|---|---|---|
| 27 | `grafana_organization_preferences` | `modules/preferences` | Default home dashboard, theme, timezone |
| 28 | `grafana_team_preferences` | `modules/preferences` | Per-team home dashboards |
| 29 | `grafana_annotation` | `modules/preferences` | Deployment & incident markers |
| 30 | `grafana_playlist` | `modules/playlists` | NOC wall, executive lobby, SRE displays |

---

## Modules

### Project Structure

```
grafana-terraform/
|
+-- main.tf                              # Master orchestration (8-phase deployment)
+-- provider.tf                          # Grafana provider configuration
+-- variables.tf                         # All input variables
+-- outputs.tf                           # All outputs (URLs, UIDs, tokens)
+-- versions.tf                          # Provider version constraints + backend
|
+-- modules/
|   +-- organizations/main.tf            # [Phase 1] Org creation & multi-tenancy
|   +-- service-accounts/
|   |   +-- main.tf                      # [Phase 2] SA creation + token generation
|   |   +-- permissions.tf               # [Phase 2] Fine-grained SA permissions
|   +-- users/main.tf                    # [Phase 2] Local user provisioning
|   +-- teams/main.tf                    # [Phase 3] Team creation + SSO group mapping
|   +-- folders/main.tf                  # [Phase 4] Folder hierarchy + permissions
|   +-- datasources/main.tf             # [Phase 4] LGTM + Pyroscope data sources
|   +-- dashboards/main.tf              # [Phase 5] Dashboard deployment with versioning
|   +-- library-panels/main.tf          # [Phase 5] Reusable shared panels
|   +-- alerting/main.tf                # [Phase 6] Contact points, routing, rules
|   +-- rbac/main.tf                    # [Phase 7] Custom roles + assignments
|   +-- dashboard-permissions/main.tf   # [Phase 7] Per-dashboard access control
|   +-- sso/main.tf                     # [Phase 8] SSO/OAuth configuration
|   +-- reports/main.tf                 # [Phase 8] Scheduled PDF reports
|   +-- playlists/main.tf              # [Phase 8] Dashboard rotation playlists
|   +-- preferences/main.tf            # [Phase 8] Org/team preferences + annotations
|
+-- dashboards/                          # Dashboard JSON files (auto-discovered)
|   +-- home/home-page.json
|   +-- L0-executive/executive-command-center.json
|   +-- L1-domain/                       # Domain overview dashboards
|   +-- L2-service/                      # Per-service dashboards
|   +-- L3-debug/                        # Deep-dive debug dashboards
|
+-- environments/
|   +-- prod/terraform.tfvars            # Production configuration
|   +-- prod/backend.tf                  # S3 remote state for prod
|   +-- staging/terraform.tfvars         # Staging configuration
|   +-- dev/terraform.tfvars             # Dev configuration (localhost)
|
+-- scripts/
|   +-- export-dashboards.sh             # Export dashboards from Grafana API
|   +-- templatize-dashboards.sh         # Replace hardcoded UIDs with TF vars
|   +-- version-bump.sh                 # Semver version bump (major/minor/patch)
|
+-- ci/github-actions.yml               # CI/CD pipeline
+-- Makefile                             # One-command operations
+-- VERSION                              # Current version (1.0.0)
+-- .gitignore                           # Secrets, state, backup exclusions
```

---

## Quick Start

### Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| [Terraform](https://www.terraform.io/downloads) | >= 1.5.0 | Infrastructure as Code |
| [Grafana](https://grafana.com/) | >= 10.0 | Observability platform |
| [jq](https://stedolan.github.io/jq/) | >= 1.6 | JSON processing (for scripts) |
| [curl](https://curl.se/) | any | API calls (for export script) |
| [make](https://www.gnu.org/software/make/) | any | Build automation |

### Step 1: Clone & Configure

```bash
git clone https://github.com/gpadidala/grafana-terraform.git
cd grafana-terraform
```

### Step 2: Set Your Credentials

```bash
# Option A: Environment variables
export GRAFANA_URL="https://grafana.company.com"
export GRAFANA_AUTH="glsa_xxxxxxxxxxxx"

# Option B: Edit environment tfvars
vim environments/dev/terraform.tfvars
```

### Step 3: Initialize & Plan

```bash
# Dev environment (localhost)
make init ENV=dev
make plan ENV=dev
```

<p align="center">
  <img src="docs/images/screenshot-make-plan.png" alt="make plan output" width="700"/>
  <br/><em>Terraform plan showing all resources to be created</em>
</p>

### Step 4: Apply

```bash
make apply ENV=dev VERSION=1.0.0
```

<p align="center">
  <img src="docs/images/screenshot-make-apply.png" alt="make apply output" width="700"/>
  <br/><em>Terraform apply creating all 30 resource types</em>
</p>

That's it! Your entire Grafana instance is now managed by Terraform.

---

## Usage Guide

### Makefile Commands

```
make help               # Show all available commands
make init ENV=dev       # Initialize Terraform for an environment
make validate           # Validate Terraform configuration
make plan ENV=staging   # Generate execution plan
make apply ENV=prod VERSION=1.2.0    # Apply changes
make destroy ENV=dev    # Tear down (with confirmation)
make export             # Export dashboards from running Grafana
make templatize         # Convert exported dashboards to templates
make version-bump TYPE=minor         # Bump version (major/minor/patch)
make lint               # Run tflint + JSON validation
make docs               # Generate terraform-docs
make clean              # Remove .terraform, plan files
```

<p align="center">
  <img src="docs/images/screenshot-make-help.png" alt="make help" width="700"/>
</p>

---

### Export Existing Dashboards

If you already have dashboards in Grafana, export them first:

```bash
export GRAFANA_URL="https://grafana.company.com"
export GRAFANA_TOKEN="glsa_xxxxxxxxxxxx"

# Export all dashboards
make export
```

This fetches every dashboard via the Grafana API and saves them organized by folder:

```
dashboards/
  +-- home/home-page.json
  +-- L0-executive/executive-command-center.json
  +-- L1-domain/domain-overview.json
  +-- L2-service/checkout-service.json
  +-- L3-debug/pod-debug.json
```

### Templatize Dashboard JSON

Replace hardcoded UIDs with Terraform template variables:

```bash
make templatize
```

**Before:**
```json
{
  "datasource": {
    "type": "prometheus",
    "uid": "abc123xyz"
  }
}
```

**After:**
```json
{
  "datasource": {
    "type": "prometheus",
    "uid": "${datasource_mimir_uid}"
  }
}
```

---

### Environment Management

Three pre-configured environments:

| Environment | Grafana URL | Features | Use Case |
|-------------|-------------|----------|----------|
| **dev** | `http://localhost:3000` | Alerting only | Local development |
| **staging** | `https://grafana-staging.company.com` | Alerting + RBAC | Pre-production testing |
| **prod** | `https://grafana.company.com` | All features enabled | Production |

```bash
# Switch environments
make plan ENV=staging
make plan ENV=prod

# Compare plans across environments
make plan ENV=staging > staging.plan
make plan ENV=prod > prod.plan
diff staging.plan prod.plan
```

---

### Feature Flags

Control what gets deployed via `terraform.tfvars`:

```hcl
enable_alerting = true     # Alert rules, contact points, routing
enable_rbac     = true     # Custom roles + assignments (Enterprise)
enable_sso      = true     # SSO/OAuth configuration
enable_reports  = true     # Scheduled PDF reports (Enterprise)
```

Disable a feature and it cleanly skips those modules:

```bash
# Deploy without SSO (e.g., in staging)
# Set enable_sso = false in environments/staging/terraform.tfvars
make apply ENV=staging
```

---

### Version Management

```bash
# Check current version
cat VERSION
# 1.0.0

# Bump patch version (1.0.0 -> 1.0.1)
make version-bump TYPE=patch

# Bump minor version (1.0.1 -> 1.1.0)
make version-bump TYPE=minor

# Bump major version (1.1.0 -> 2.0.0)
make version-bump TYPE=major

# Deploy with version
make apply ENV=prod VERSION=$(cat VERSION)
```

Each deployment creates an annotation on dashboards:

```
"Terraform deployment v1.1.0 [prod]"
```

---

### Adding New Dashboards

1. Create your dashboard JSON file:

```bash
# Add to the appropriate tier folder
vim dashboards/L2-service/my-new-service.json
```

2. Use template variables for data sources:

```json
{
  "datasource": {
    "type": "prometheus",
    "uid": "${datasource_mimir_uid}"
  }
}
```

3. Plan and apply:

```bash
make plan ENV=dev
make apply ENV=dev
```

The dashboards module auto-discovers all `*.json` files in the `dashboards/` directory. No Terraform changes needed.

---

### Adding New Teams

Edit `environments/<env>/terraform.tfvars`:

```hcl
teams = [
  # ... existing teams ...
  {
    name         = "ml-engineering"
    display_name = "ML Engineering"
    email        = "ml-team@company.com"
    members      = ["alice@company.com", "bob@company.com"]
    sso_group    = "grafana-ml-team"
  }
]
```

Then apply:

```bash
make plan ENV=prod
make apply ENV=prod
```

---

### Customizing Alert Rules

Edit `modules/alerting/main.tf` to add new rule groups or modify thresholds:

```hcl
resource "grafana_rule_group" "custom_alerts" {
  name             = "my-service-alerts"
  folder_uid       = var.folder_uid
  interval_seconds = 60

  rule {
    name      = "High Latency - My Service"
    condition = "C"
    for       = "5m"
    
    labels = {
      severity = "warning"
    }
    
    # ... data and condition blocks
  }
}
```

---

### Configuring SSO

Edit your environment's tfvars:

```hcl
# Generic OAuth2
sso_provider    = "generic_oauth"
oauth_auth_url  = "https://idp.company.com/authorize"
oauth_token_url = "https://idp.company.com/token"
oauth_api_url   = "https://idp.company.com/userinfo"
allowed_domains = ["company.com"]

# Role mapping via JMESPath
role_attribute_path = "contains(groups[*], 'grafana-admin') && 'Admin' || contains(groups[*], 'grafana-editor') && 'Editor' || 'Viewer'"
```

Supported providers: `generic_oauth`, `github`, `gitlab`, `azuread`, `okta`, `google`

---

## Security Model

### Service Accounts (4 Tiers)

| Account | Role | Access Pattern |
|---------|------|---------------|
| `sa-terraform-deployer` | Admin | Full access to all folders |
| `sa-cicd-pipeline` | Editor | Edit L2/L3, View L0/L1 |
| `sa-reporter` | Viewer | View Home/L0/L1 only |
| `sa-alerting-engine` | Editor | Admin alerting folder, View all |

### RBAC Custom Roles (4 Roles)

| Role | Assigned To | Access |
|------|------------|--------|
| `executive:viewer` | Executive Leadership | View L0 + L1 + Home only |
| `sre:power` | SRE + DevOps | Full read/write all dashboards, alerts, explore |
| `developer:standard` | App Engineering | View Home/L1/L2/L3, Explore, Annotate |
| `network:engineer` | Network Engineering | View/Edit Network folder, Explore |

### Folder Permission Matrix

| Folder | Platform Admin | SRE | DevOps | Executive | App Eng | Network | Security | Data | Cloud |
|--------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| Home | Admin | View | View | View | View | View | View | View | View |
| Executive (L0) | Admin | - | - | View | - | - | - | - | - |
| Domain (L1) | Admin | Edit | - | View | View | - | - | - | - |
| Service (L2) | Admin | Edit | Edit | - | View | - | - | - | - |
| Deep Dive (L3) | Admin | Edit | Edit | - | - | - | - | - | - |
| SRE | Admin | Admin | - | - | - | - | - | - | - |
| Network | Admin | View | - | - | - | Admin | - | - | - |
| Security | Admin | - | - | - | - | - | Admin | - | - |
| Cloud & Cost | Admin | - | - | View | - | - | - | - | Edit |
| Data Pipelines | Admin | - | - | - | - | - | - | Admin | - |
| Alerting | Admin | Edit | - | - | - | - | - | - | - |

---

## Team Home Dashboards

Each team lands on the dashboard most relevant to their role:

| Team | Home Dashboard | Rationale |
|------|---------------|-----------|
| Executive Leadership | Executive Command Center | Business health at a glance |
| SRE & On-Call | SRE On-Call Dashboard | Active incidents + alerts |
| DevOps Engineering | Infrastructure Overview | Cluster/node/pod health |
| Network Engineering | Network Health | BGP, latency, DNS, VPN |
| Security Operations | Security Overview | Audit logs, auth failures |
| Application Engineering | Application Overview | Service golden signals |
| Data Platform | Data Pipeline Overview | Kafka, ETL, queue depths |
| Cloud Infrastructure | Cloud & Cost Overview | AWS/GCP billing, utilization |
| Platform Administrators | Home Page | Full platform portal |

---

## Scheduled Reports (Enterprise)

| Report | Frequency | Recipients | Dashboard |
|--------|-----------|------------|-----------|
| Weekly Executive Summary | Monday 8 AM | exec-team, VP engineering | Executive Command Center |
| Monthly SLO Compliance | 1st of month, 9 AM | engineering-leadership | SLO Overview |
| Daily Incident Summary | Daily 7:30 AM | sre-team | Incident Management |

---

## Playlists (TV/NOC Displays)

| Playlist | Interval | Mode | Dashboards |
|----------|----------|------|------------|
| NOC Wall Display | 1 min | Kiosk TV | Command Center -> Infra -> Apps -> Network |
| Executive Lobby | 2 min | Kiosk TV | Home -> SLO -> Cost |
| SRE On-Call | 30 sec | Kiosk TV | All tagged `domain:sre` |

---

<a name="cicd"></a>

## CI/CD Pipeline

```
PR Created --> Validate (fmt + JSON) --> Plan (post diff to PR)
                                              |
PR Merged to main --> Plan --> Apply to staging
                                    |
Manual trigger --> Plan --> Apply to prod (with version tag)
                                    |
                              Slack notification
```

<p align="center">
  <img src="docs/images/screenshot-pr-plan-comment.png" alt="PR Plan Comment" width="700"/>
  <br/><em>Terraform plan posted as a PR comment for review</em>
</p>

### Pipeline Jobs

| Job | Trigger | What It Does |
|-----|---------|-------------|
| **validate** | Every PR | `terraform fmt -check`, `terraform validate`, JSON lint |
| **plan** | Every PR | `terraform plan`, posts output as PR comment |
| **apply-staging** | Merge to main | Auto-applies to staging environment |
| **apply-prod** | Manual dispatch | Applies to production with version input |
| **notify** | After apply | Sends Slack notification (success/failure) |

---

## Troubleshooting

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| `Provider authentication error` | Invalid or expired token | Regenerate SA token in Grafana |
| `Resource already exists` | Resource created outside Terraform | Run `terraform import` |
| `Folder permission conflict` | Overlapping permission rules | Check `folder_permissions` in tfvars |
| `Dashboard JSON invalid` | Malformed template variable | Validate with `jq . < dashboard.json` |
| `SSO callback error` | Wrong redirect URI | Verify `oauth_auth_url` and callback in IdP |
| `Report not generating` | Enterprise license required | Ensure Grafana Enterprise is licensed |

### Import Existing Resources

If you have existing Grafana resources to bring under Terraform management:

```bash
# Import an existing folder
terraform import 'module.folders.grafana_folder.this["home"]' "folder-uid-here"

# Import an existing data source
terraform import 'module.datasources.grafana_data_source.mimir' "datasource-id-here"

# Import an existing team
terraform import 'module.teams.grafana_team.this["sre"]' "team-id-here"
```

### State Management

```bash
# List all managed resources
terraform state list

# Show a specific resource
terraform state show 'module.folders.grafana_folder.this["home"]'

# Move a resource (after refactoring)
terraform state mv 'old.resource.path' 'new.resource.path'
```

---

## Contributing

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/my-feature`
3. Make changes and test in dev: `make plan ENV=dev`
4. Commit your changes: `git commit -am 'Add my feature'`
5. Push to the branch: `git push origin feature/my-feature`
6. Submit a pull request

### Code Standards

- All Terraform files must pass `terraform fmt`
- All dashboard JSON must be valid (test with `jq .`)
- New modules must include variables, outputs, and validation blocks
- Feature flags for optional Enterprise features

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

<p align="center">
  <strong>Every click in Grafana has a Terraform resource. Nothing is manual. Everything is versioned. Everything is auditable.</strong>
</p>

<p align="center">
  Built with Terraform + Grafana Enterprise<br/>
  <a href="https://github.com/gpadidala/grafana-terraform">github.com/gpadidala/grafana-terraform</a>
</p>
