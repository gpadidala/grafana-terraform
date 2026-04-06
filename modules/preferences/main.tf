#--------------------------------------------------------------
# Phase 8: Organization & Team Preferences
# Grafana Enterprise Terraform Module - Preferences
#
# Sets org-wide defaults (theme, timezone, home dashboard),
# per-team home dashboard preferences, and creates a
# deployment annotation marker on the home dashboard.
#--------------------------------------------------------------

terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = ">= 3.0.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------

variable "org_id" {
  description = "The Grafana organization ID"
  type        = number
}

variable "team_ids" {
  description = "Map of team slug to Grafana team ID (output from the teams module)"
  type        = map(number)
}

variable "team_home_dashboards" {
  description = "Map of team slug to the dashboard UID that should be the team's home page"
  type        = map(string)

  default = {
    "executive-leadership"    = "executive-command-center"
    "sre-oncall"              = "sre-oncall-dashboard"
    "devops-engineering"      = "infrastructure-overview"
    "network-engineering"     = "network-health"
    "security-operations"     = "security-overview"
    "application-engineering" = "application-overview"
    "data-platform"           = "data-pipeline-overview"
    "cloud-infrastructure"    = "cloud-cost-overview"
    "platform-administrators" = "home-page"
  }
}

variable "home_dashboard_uid" {
  description = "Dashboard UID to set as the organization-wide home page"
  type        = string
  default     = "home-page"
}

variable "default_theme" {
  description = "Default Grafana UI theme (dark, light, system)"
  type        = string
  default     = "dark"

  validation {
    condition     = contains(["dark", "light", "system"], var.default_theme)
    error_message = "default_theme must be one of: dark, light, system."
  }
}

variable "default_timezone" {
  description = "Default timezone for the organization (e.g. utc, browser, America/New_York)"
  type        = string
  default     = "utc"
}

variable "week_start" {
  description = "First day of the week (monday, sunday, saturday)"
  type        = string
  default     = "monday"

  validation {
    condition     = contains(["monday", "sunday", "saturday"], var.week_start)
    error_message = "week_start must be one of: monday, sunday, saturday."
  }
}

variable "platform_version" {
  description = "Platform release version used in the deployment annotation"
  type        = string
  default     = "1.0.0"
}

variable "environment" {
  description = "Deployment environment name (production, staging, development)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["production", "staging", "development"], var.environment)
    error_message = "environment must be one of: production, staging, development."
  }
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------

locals {
  # Only create team preferences for teams that exist in both maps
  team_preferences = {
    for team_slug, dashboard_uid in var.team_home_dashboards : team_slug => {
      team_id       = var.team_ids[team_slug]
      dashboard_uid = dashboard_uid
    }
    if contains(keys(var.team_ids), team_slug)
  }
}

# -----------------------------------------------------------------------------
# Resources
# -----------------------------------------------------------------------------

# --- Organization-wide preferences -------------------------------------------

resource "grafana_organization_preferences" "this" {
  org_id             = var.org_id
  home_dashboard_uid = var.home_dashboard_uid
  theme              = var.default_theme
  timezone           = var.default_timezone
  week_start         = var.week_start
}

# --- Per-team home dashboard preferences -------------------------------------

resource "grafana_team_preferences" "this" {
  for_each = local.team_preferences

  org_id             = var.org_id
  team_id            = each.value.team_id
  home_dashboard_uid = each.value.dashboard_uid
  theme              = var.default_theme
  timezone           = var.default_timezone
}

# --- Deployment annotation marker --------------------------------------------

resource "grafana_annotation" "deployment" {
  org_id        = var.org_id
  text          = "Terraform deployment v${var.platform_version}"
  tags          = ["deployment", "terraform", var.environment]
  dashboard_uid = var.home_dashboard_uid
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "org_preferences_id" {
  description = "The ID of the organization preferences resource"
  value       = grafana_organization_preferences.this.id
}

output "team_preferences_ids" {
  description = "Map of team slug to team preferences resource ID"
  value = {
    for slug, prefs in grafana_team_preferences.this : slug => prefs.id
  }
}

output "annotation_id" {
  description = "The ID of the deployment annotation"
  value       = grafana_annotation.deployment.id
}
