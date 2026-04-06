# =============================================================================
# Grafana Enterprise Terraform - Master Orchestration
# 15 modules in 8-phase dependency order covering ALL 30 provider resources
# =============================================================================

locals {
  common_tags = merge(var.default_tags, {
    environment      = var.environment
    platform_version = var.platform_version
  })
}

# =============================================================================
# Phase 1: Organization
# Foundation resource - everything else depends on this
# =============================================================================

module "organizations" {
  source = "./modules/organizations"

  org_id      = var.org_id
  environment = var.environment
  tags        = local.common_tags
}

# =============================================================================
# Phase 2: Service Accounts & Users
# Depend on the organization existing
# =============================================================================

module "service_accounts" {
  source = "./modules/service_accounts"

  org_id           = module.organizations.org_id
  service_accounts = var.service_accounts
  environment      = var.environment
  tags             = local.common_tags

  depends_on = [module.organizations]
}

module "users" {
  source = "./modules/users"

  org_id      = module.organizations.org_id
  users       = var.users
  environment = var.environment

  depends_on = [module.organizations]
}

# =============================================================================
# Phase 3: Teams
# Depend on organization and users for membership
# =============================================================================

module "teams" {
  source = "./modules/teams"

  org_id      = module.organizations.org_id
  teams       = var.teams
  user_ids    = module.users.user_ids
  environment = var.environment
  tags        = local.common_tags

  depends_on = [
    module.organizations,
    module.users,
  ]
}

# =============================================================================
# Phase 4: Folders & Data Sources
# Folders need org and teams (for initial permissions); datasources need org
# =============================================================================

module "folders" {
  source = "./modules/folders"

  org_id      = module.organizations.org_id
  folders     = var.folders
  team_ids    = module.teams.team_ids
  environment = var.environment
  tags        = local.common_tags

  depends_on = [
    module.organizations,
    module.teams,
  ]
}

module "datasources" {
  source = "./modules/datasources"

  org_id         = module.organizations.org_id
  datasource_urls = var.datasource_urls
  environment    = var.environment
  tags           = local.common_tags

  depends_on = [module.organizations]
}

# =============================================================================
# Phase 5: Dashboards & Library Panels
# Depend on folders (placement) and datasources (queries)
# =============================================================================

module "dashboards" {
  source = "./modules/dashboards"

  org_id         = module.organizations.org_id
  folder_uids    = module.folders.folder_uids
  datasource_uids = module.datasources.datasource_uids
  dashboard_dir  = var.dashboard_dir
  grafana_url    = var.grafana_url
  environment    = var.environment
  tags           = local.common_tags

  depends_on = [
    module.folders,
    module.datasources,
  ]
}

module "library_panels" {
  source = "./modules/library_panels"

  org_id            = module.organizations.org_id
  folder_uids       = module.folders.folder_uids
  datasource_uids   = module.datasources.datasource_uids
  library_panel_dir = var.library_panel_dir
  environment       = var.environment
  tags              = local.common_tags

  depends_on = [
    module.folders,
    module.datasources,
  ]
}

# =============================================================================
# Phase 6: Alerting
# Depends on folders, datasources, and contact info
# Conditionally deployed via enable_alerting feature flag
# =============================================================================

module "alerting" {
  source = "./modules/alerting"
  count  = var.enable_alerting ? 1 : 0

  org_id                    = module.organizations.org_id
  folder_uids               = module.folders.folder_uids
  datasource_uids           = module.datasources.datasource_uids
  slack_webhook_url         = var.slack_webhook_url
  pagerduty_integration_key = var.pagerduty_integration_key
  alert_email_addresses     = var.alert_email_addresses
  environment               = var.environment
  tags                      = local.common_tags

  depends_on = [
    module.folders,
    module.datasources,
  ]
}

# =============================================================================
# Phase 7: RBAC & Dashboard Permissions
# RBAC depends on teams; permissions depend on dashboards, teams, folders
# =============================================================================

module "rbac" {
  source = "./modules/rbac"
  count  = var.enable_rbac ? 1 : 0

  org_id   = module.organizations.org_id
  team_ids = module.teams.team_ids
  teams    = var.teams
  environment = var.environment
  tags     = local.common_tags

  depends_on = [module.teams]
}

module "dashboard_permissions" {
  source = "./modules/dashboard_permissions"

  org_id        = module.organizations.org_id
  dashboard_uids = module.dashboards.dashboard_uids
  folder_uids   = module.folders.folder_uids
  team_ids      = module.teams.team_ids
  teams         = var.teams
  environment   = var.environment
  tags          = local.common_tags

  depends_on = [
    module.dashboards,
    module.teams,
    module.folders,
  ]
}

# =============================================================================
# Phase 8: SSO, Reports, Playlists, Preferences
# Final phase - depends on most prior resources
# =============================================================================

module "sso" {
  source = "./modules/sso"
  count  = var.enable_sso ? 1 : 0

  org_id              = module.organizations.org_id
  oauth_client_id     = var.oauth_client_id
  oauth_client_secret = var.oauth_client_secret
  oauth_auth_url      = var.oauth_auth_url
  oauth_token_url     = var.oauth_token_url
  allowed_domains     = var.allowed_domains
  teams               = var.teams
  environment         = var.environment
  tags                = local.common_tags

  depends_on = [module.organizations]
}

module "reports" {
  source = "./modules/reports"
  count  = var.enable_reports ? 1 : 0

  org_id           = module.organizations.org_id
  dashboard_uids   = module.dashboards.dashboard_uids
  report_recipients = var.report_recipients
  environment      = var.environment
  tags             = local.common_tags

  depends_on = [module.dashboards]
}

module "playlists" {
  source = "./modules/playlists"

  org_id        = module.organizations.org_id
  playlists     = var.playlists
  dashboard_uids = module.dashboards.dashboard_uids
  environment   = var.environment
  tags          = local.common_tags

  depends_on = [module.dashboards]
}

module "preferences" {
  source = "./modules/preferences"

  org_id          = module.organizations.org_id
  org_preferences = var.org_preferences
  team_ids        = module.teams.team_ids
  dashboard_uids  = module.dashboards.dashboard_uids
  folder_uids     = module.folders.folder_uids
  environment     = var.environment
  tags            = local.common_tags

  depends_on = [
    module.teams,
    module.dashboards,
    module.folders,
  ]
}
