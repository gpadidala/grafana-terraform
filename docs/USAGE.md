# Grafana Enterprise Terraform - Complete Usage Guide

> Step-by-step guide for every operation you'll need.

---

## Table of Contents

- [Initial Setup](#initial-setup)
- [Day-to-Day Operations](#day-to-day-operations)
- [Dashboard Management](#dashboard-management)
- [Team & User Management](#team--user-management)
- [Alerting Configuration](#alerting-configuration)
- [RBAC & Permissions](#rbac--permissions)
- [SSO Configuration](#sso-configuration)
- [Reports & Playlists](#reports--playlists)
- [Environment Promotion](#environment-promotion)
- [Disaster Recovery](#disaster-recovery)
- [Advanced Operations](#advanced-operations)

---

## Initial Setup

### 1. Prerequisites Check

```bash
# Verify all tools are installed
terraform version    # >= 1.5.0
jq --version         # >= 1.6
curl --version       # any
make --version       # any
```

### 2. Clone the Repository

```bash
git clone https://github.com/gpadidala/grafana-terraform.git
cd grafana-terraform
```

### 3. Configure Your Environment

#### For Local Development (Dev)

```bash
# The dev environment is pre-configured for localhost
# Just start your local Grafana:
docker run -d -p 3000:3000 grafana/grafana-enterprise:latest

# Create a service account token in Grafana UI:
# Configuration -> Service Accounts -> Add -> Admin role -> Generate token

# Set credentials
export TF_VAR_grafana_url="http://localhost:3000"
export TF_VAR_grafana_auth="glsa_your_token_here"
```

#### For Staging / Production

```bash
# Edit the environment-specific tfvars
vim environments/staging/terraform.tfvars
vim environments/prod/terraform.tfvars

# Required values:
#   grafana_url      = "https://grafana.company.com"
#   mimir_url        = "https://mimir.company.com/prometheus"
#   loki_url         = "https://loki.company.com"
#   tempo_url        = "https://tempo.company.com"
#   pyroscope_url    = "https://pyroscope.company.com"
#   alertmanager_url = "https://mimir.company.com/alertmanager"

# Set sensitive values via environment variables (never in tfvars!)
export TF_VAR_grafana_auth="glsa_xxxxxxxxxxxx"
export TF_VAR_slack_webhook_url="https://hooks.slack.com/services/xxx"
export TF_VAR_pagerduty_integration_key="xxxxxxxxxxxxxxxx"
export TF_VAR_oauth_client_secret="xxxxxxxxxxxxxxxx"
```

### 4. Initialize Terraform

```bash
# For dev (local backend)
make init ENV=dev

# For staging/prod (S3 backend)
make init ENV=staging
make init ENV=prod
```

### 5. First Deployment

```bash
# Always plan first
make plan ENV=dev

# Review the plan output carefully, then apply
make apply ENV=dev VERSION=1.0.0
```

### 6. Verify Deployment

After apply, check the outputs:

```bash
terraform output

# Key outputs:
#   organization_id      = 1
#   folder_uids          = { "home" = "home", "l0-executive" = "l0-executive", ... }
#   datasource_uids      = { "mimir" = "ds-mimir", "loki" = "ds-loki", ... }
#   dashboard_urls       = { "home-page" = "/d/home-page/platform-home", ... }
#   team_ids             = { "sre" = 1, "devops" = 2, ... }
```

Open your Grafana URL and verify:
- Home dashboard is set
- All folders are created
- Data sources are connected (green checkmarks)
- Teams are configured

---

## Day-to-Day Operations

### Planning Changes

```bash
# Always plan before applying
make plan ENV=staging

# Save plan to file for review
terraform plan -var-file=environments/staging/terraform.tfvars \
  -out=staging.tfplan

# Show saved plan
terraform show staging.tfplan
```

### Applying Changes

```bash
# Apply with latest version
make apply ENV=staging VERSION=$(cat VERSION)

# Apply a saved plan
terraform apply staging.tfplan
```

### Checking Current State

```bash
# List all managed resources
terraform state list

# Count resources by type
terraform state list | sed 's/\[.*//' | sort | uniq -c | sort -rn

# Show a specific resource
terraform state show 'module.folders.grafana_folder.this["home"]'
```

### Version Bumping

```bash
# Patch release (bug fixes): 1.0.0 -> 1.0.1
make version-bump TYPE=patch

# Minor release (new features): 1.0.1 -> 1.1.0
make version-bump TYPE=minor

# Major release (breaking changes): 1.1.0 -> 2.0.0
make version-bump TYPE=major

# Deploy with new version
make apply ENV=prod VERSION=$(cat VERSION)
```

---

## Dashboard Management

### Export from Existing Grafana

```bash
export GRAFANA_URL="https://grafana.company.com"
export GRAFANA_TOKEN="glsa_xxxxxxxxxxxx"

# Export all dashboards
make export

# What happens:
# 1. Lists all dashboards via /api/search
# 2. Downloads each dashboard JSON via /api/dashboards/uid/{uid}
# 3. Strips id, version, meta fields
# 4. Organizes by folder into dashboards/ directory
```

### Templatize Exported Dashboards

```bash
make templatize

# What happens:
# 1. Scans all JSON files in dashboards/
# 2. Replaces hardcoded Mimir/Prometheus UIDs with ${datasource_mimir_uid}
# 3. Replaces hardcoded Loki UIDs with ${datasource_loki_uid}
# 4. Replaces hardcoded Tempo UIDs with ${datasource_tempo_uid}
# 5. Replaces hardcoded Pyroscope UIDs with ${datasource_pyroscope_uid}
# 6. Replaces folder UIDs with ${folder_<name>_uid}
```

### Add a New Dashboard

1. Create your dashboard JSON in the correct tier folder:

```bash
# L0 = Executive (business metrics, SLOs)
# L1 = Domain (service group overview)
# L2 = Service (per-service golden signals)
# L3 = Debug (deep-dive troubleshooting)

vim dashboards/L2-service/my-new-service.json
```

2. Use template variables for all data sources:

```json
{
  "panels": [
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${datasource_mimir_uid}"
      },
      "targets": [
        {
          "expr": "rate(http_requests_total{service=\"my-service\"}[5m])"
        }
      ]
    }
  ]
}
```

3. Deploy:

```bash
make plan ENV=dev    # See the new dashboard in the plan
make apply ENV=dev
```

### Dashboard Template Variables

These variables are automatically injected by the dashboards module:

| Variable | Value | Use For |
|----------|-------|---------|
| `${ds_mimir}` | Mimir datasource UID | Prometheus/Mimir queries |
| `${ds_loki}` | Loki datasource UID | Log queries |
| `${ds_tempo}` | Tempo datasource UID | Trace queries |
| `${ds_pyroscope}` | Pyroscope datasource UID | Profile queries |
| `${folder_home}` | Home folder UID | Folder references |
| `${folder_l0_executive}` | L0 folder UID | Folder references |
| `${folder_l1_domain}` | L1 folder UID | Folder references |
| `${folder_l2_service}` | L2 folder UID | Folder references |
| `${folder_l3_debug}` | L3 folder UID | Folder references |
| `${platform_version}` | Current version | Version display |

---

## Team & User Management

### Add a New Team

In your environment's `terraform.tfvars`:

```hcl
teams = [
  # Existing teams...
  {
    name         = "ml-engineering"
    display_name = "ML Engineering"
    email        = "ml-team@company.com"
    members      = ["alice@company.com", "bob@company.com"]
    sso_group    = "grafana-ml-team"   # Optional: SSO group mapping
  }
]
```

### Add a New User

```hcl
users = {
  "new-admin" = {
    name     = "New Admin User"
    email    = "admin@company.com"
    login    = "new-admin"
    is_admin = true
  }
}
```

### Map SSO Groups to Teams

Each team can be linked to an SSO/LDAP group:

```hcl
teams = [
  {
    name      = "sre"
    sso_group = "cn=grafana-sre,ou=groups,dc=company,dc=com"  # LDAP DN
  },
  {
    name      = "executive-leadership"
    sso_group = "grafana-executives"  # OAuth group claim
  }
]
```

---

## Alerting Configuration

### Add a New Contact Point

Edit `modules/alerting/main.tf`:

```hcl
resource "grafana_contact_point" "teams_webhook" {
  name = "microsoft-teams"

  teams {
    url     = var.teams_webhook_url
    title   = "{{ .CommonLabels.alertname }}"
    message = "{{ .CommonAnnotations.summary }}"
  }
}
```

### Add a New Alert Rule

```hcl
resource "grafana_rule_group" "my_service_alerts" {
  name             = "my-service-alerts"
  folder_uid       = var.folder_uid
  interval_seconds = 60

  rule {
    name      = "High Error Rate - My Service"
    condition = "C"
    for       = "5m"

    labels = {
      severity = "critical"
      service  = "my-service"
    }

    annotations = {
      summary     = "Error rate above 5% for my-service"
      description = "Current error rate: {{ $values.A }}%"
      runbook_url = "https://wiki.company.com/runbooks/my-service-errors"
    }

    data {
      ref_id         = "A"
      datasource_uid = var.datasource_uid

      relative_time_range {
        from = 600
        to   = 0
      }

      model = jsonencode({
        expr = "sum(rate(http_requests_total{service=\"my-service\",status=~\"5..\"}[5m])) / sum(rate(http_requests_total{service=\"my-service\"}[5m])) * 100"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "__expr__"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "threshold"
        conditions = [{ evaluator = { type = "gt", params = [5] } }]
      })
    }
  }
}
```

### Add a Maintenance Window

```hcl
resource "grafana_mute_timing" "quarterly_maintenance" {
  name = "quarterly-maintenance"

  intervals {
    months   = ["3", "6", "9", "12"]
    days_of_month = ["15"]
    times {
      start = "02:00"
      end   = "06:00"
    }
  }
}
```

---

## RBAC & Permissions

### Add a Custom Role

Edit `modules/rbac/main.tf`:

```hcl
# Add to the local.roles map:
locals {
  roles = {
    # ... existing roles ...
    "ml:engineer" = {
      description = "ML Engineering team role"
      permissions = [
        { action = "dashboards:read",  scope = "folders:uid:l2-service" },
        { action = "dashboards:read",  scope = "folders:uid:data-pipelines" },
        { action = "dashboards:write", scope = "folders:uid:data-pipelines" },
        { action = "datasources:explore", scope = "" },
      ]
    }
  }
}
```

### Override Dashboard Permissions

To give a specific team special access to a single dashboard:

```hcl
# In your tfvars
dashboard_permissions = {
  "special-dashboard-uid" = {
    override_folder_permissions = true
    teams = [
      { team_key = "sre",       permission = "Admin" },
      { team_key = "ml-team",   permission = "Edit" },
      { team_key = "executive", permission = "View" },
    ]
  }
}
```

---

## SSO Configuration

### OAuth2 (Generic)

```hcl
sso_provider         = "generic_oauth"
oauth_client_id      = "grafana-client-id"
oauth_auth_url       = "https://idp.company.com/authorize"
oauth_token_url      = "https://idp.company.com/token"
oauth_api_url        = "https://idp.company.com/userinfo"
oauth_scopes         = "openid profile email groups"
allowed_domains      = ["company.com"]
role_attribute_path  = "contains(groups[*], 'grafana-admin') && 'Admin' || contains(groups[*], 'grafana-editor') && 'Editor' || 'Viewer'"
```

### GitHub

```hcl
sso_provider    = "github"
oauth_client_id = "github-app-client-id"
oauth_auth_url  = "https://github.com/login/oauth/authorize"
oauth_token_url = "https://github.com/login/oauth/access_token"
oauth_api_url   = "https://api.github.com/user"
```

### Azure AD

```hcl
sso_provider    = "azuread"
oauth_client_id = "azure-app-client-id"
oauth_auth_url  = "https://login.microsoftonline.com/TENANT_ID/oauth2/v2.0/authorize"
oauth_token_url = "https://login.microsoftonline.com/TENANT_ID/oauth2/v2.0/token"
```

### Google

```hcl
sso_provider    = "google"
oauth_client_id = "google-client-id.apps.googleusercontent.com"
oauth_auth_url  = "https://accounts.google.com/o/oauth2/v2/auth"
oauth_token_url = "https://oauth2.googleapis.com/token"
allowed_domains = ["company.com"]
```

---

## Reports & Playlists

### Add a New Scheduled Report

In your tfvars:

```hcl
reports = {
  "weekly-security" = {
    name          = "Weekly Security Report"
    dashboard_uid = "security-overview"
    recipients    = ["security-team@company.com", "ciso@company.com"]
    frequency     = "weekly"
    time_range_from = "now-7d"
    time_range_to   = "now"
    orientation   = "landscape"
    layout        = "grid"
    formats       = ["pdf"]
  }
}
```

### Add a New Playlist

```hcl
playlists = {
  "dev-team-display" = {
    name     = "Dev Team Display"
    interval = "1m"
    items = [
      { title = "App Overview", uid = "app-overview" },
      { title = "CI/CD Status", uid = "cicd-status" },
      { title = "Error Tracker", uid = "error-tracker" },
    ]
  }
}
```

---

## Environment Promotion

### Dev -> Staging -> Production Workflow

```bash
# 1. Develop and test in dev
make plan ENV=dev
make apply ENV=dev VERSION=1.1.0

# 2. Promote to staging
make plan ENV=staging VERSION=1.1.0
make apply ENV=staging VERSION=1.1.0

# 3. Verify in staging (manual QA or automated tests)

# 4. Promote to production
make plan ENV=prod VERSION=1.1.0
# Review the plan carefully!
make apply ENV=prod VERSION=1.1.0

# 5. Tag the release
git tag -a v1.1.0 -m "Release v1.1.0"
git push origin v1.1.0
```

### Rollback

```bash
# Option 1: Revert to previous version
git checkout v1.0.0
make apply ENV=prod VERSION=1.0.0

# Option 2: Target specific resources
terraform apply -target=module.dashboards -var-file=environments/prod/terraform.tfvars
```

---

## Disaster Recovery

### Backup State

```bash
# State is stored in S3 with versioning enabled
# To manually backup:
terraform state pull > backup-$(date +%Y%m%d).tfstate
```

### Restore from Scratch

If you need to rebuild from scratch:

```bash
# 1. Initialize with fresh state
make init ENV=prod

# 2. Import existing resources (if Grafana instance still has them)
terraform import 'module.organizations.grafana_organization.main' 1

# 3. Apply to recreate everything
make apply ENV=prod VERSION=$(cat VERSION)
```

### Partial Recovery

```bash
# Recreate only specific modules
terraform apply -target=module.alerting -var-file=environments/prod/terraform.tfvars
terraform apply -target=module.dashboards -var-file=environments/prod/terraform.tfvars
```

---

## Advanced Operations

### Refresh State Without Applying

```bash
terraform apply -refresh-only -var-file=environments/prod/terraform.tfvars
```

### Move Resources Between Modules

```bash
terraform state mv 'module.old_module.resource_name' 'module.new_module.resource_name'
```

### Debug Terraform

```bash
# Enable verbose logging
export TF_LOG=DEBUG
make plan ENV=dev

# Log to file
export TF_LOG_PATH=terraform-debug.log
make plan ENV=dev
```

### Validate JSON Dashboards

```bash
# Validate all dashboard JSON files
for f in dashboards/**/*.json; do
  echo -n "Checking $f... "
  jq empty "$f" 2>/dev/null && echo "OK" || echo "INVALID"
done
```

### Generate Documentation

```bash
# Install terraform-docs
brew install terraform-docs

# Generate docs for all modules
make docs
```

---

## Quick Reference Card

| What | Command |
|------|---------|
| Initialize | `make init ENV=dev` |
| Plan changes | `make plan ENV=staging` |
| Apply changes | `make apply ENV=prod VERSION=1.0.0` |
| Destroy | `make destroy ENV=dev` |
| Export dashboards | `make export` |
| Templatize | `make templatize` |
| Bump version | `make version-bump TYPE=minor` |
| Validate | `make validate` |
| Lint | `make lint` |
| Clean | `make clean` |
| Show help | `make help` |
| List state | `terraform state list` |
| Show outputs | `terraform output` |

---

*For questions, issues, or contributions, see the main [README](../README.md).*
