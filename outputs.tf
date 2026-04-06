# =============================================================================
# Grafana Enterprise Terraform - Outputs
# =============================================================================

# -----------------------------------------------------------------------------
# Organization
# -----------------------------------------------------------------------------

output "organization_id" {
  description = "The Grafana organization ID managed by this configuration"
  value       = module.organizations.org_id
}

# -----------------------------------------------------------------------------
# Service Accounts
# -----------------------------------------------------------------------------

output "service_account_tokens" {
  description = "Map of service account name to its API token (sensitive)"
  value       = module.service_accounts.tokens
  sensitive   = true
}

output "service_account_ids" {
  description = "Map of service account name to its numeric ID"
  value       = module.service_accounts.ids
}

# -----------------------------------------------------------------------------
# Folders
# -----------------------------------------------------------------------------

output "folder_uids" {
  description = "Map of folder name to its UID for use in dashboards and alerts"
  value       = module.folders.folder_uids
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

output "datasource_uids" {
  description = "Map of data source name to its UID for use in dashboards"
  value       = module.datasources.datasource_uids
}

# -----------------------------------------------------------------------------
# Dashboards
# -----------------------------------------------------------------------------

output "dashboard_urls" {
  description = "Map of dashboard title to its full URL"
  value       = module.dashboards.dashboard_urls
}

output "dashboard_uids" {
  description = "Map of dashboard title to its UID"
  value       = module.dashboards.dashboard_uids
}

# -----------------------------------------------------------------------------
# Teams
# -----------------------------------------------------------------------------

output "team_ids" {
  description = "Map of team name to its numeric ID"
  value       = module.teams.team_ids
}

# -----------------------------------------------------------------------------
# RBAC (conditional)
# -----------------------------------------------------------------------------

output "rbac_role_uids" {
  description = "Map of custom RBAC role name to its UID (only when RBAC is enabled)"
  value       = var.enable_rbac ? module.rbac[0].role_uids : {}
}

# -----------------------------------------------------------------------------
# SSO (conditional)
# -----------------------------------------------------------------------------

output "sso_status" {
  description = "SSO configuration status and provider details (only when SSO is enabled)"
  value = var.enable_sso ? {
    enabled       = true
    provider_type = "oauth2"
    auth_url      = var.oauth_auth_url
    client_id     = var.oauth_client_id
  } : {
    enabled       = false
    provider_type = ""
    auth_url      = ""
    client_id     = ""
  }
}

# -----------------------------------------------------------------------------
# Alerting (conditional)
# -----------------------------------------------------------------------------

output "alerting_contact_point_ids" {
  description = "Map of contact point name to ID (only when alerting is enabled)"
  value       = var.enable_alerting ? module.alerting[0].contact_point_ids : {}
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

output "deployment_summary" {
  description = "High-level summary of what was deployed"
  value = {
    environment      = var.environment
    platform_version = var.platform_version
    grafana_url      = var.grafana_url
    features = {
      alerting = var.enable_alerting
      rbac     = var.enable_rbac
      sso      = var.enable_sso
      reports  = var.enable_reports
    }
    resource_counts = {
      teams        = length(var.teams)
      folders      = length(var.folders)
      service_accs = length(var.service_accounts)
    }
  }
}
