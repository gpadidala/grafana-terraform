###############################################################################
# Dashboard Permissions Module - Per-Dashboard ACLs and Public Sharing
# Phase 7: Grafana Enterprise Permissions for AIOps Observability Platform
###############################################################################

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
  description = "Grafana organization ID"
  type        = number
  default     = 1
}

variable "dashboard_uids" {
  description = "Map of dashboard name keys to Grafana dashboard UIDs"
  type        = map(string)
}

variable "team_ids" {
  description = "Map of team name keys to Grafana team IDs"
  type        = map(number)
}

variable "dashboard_permissions" {
  description = <<-EOT
    Per-dashboard team access overrides. Each key is a dashboard name (must exist
    in var.dashboard_uids). The value is a list of team permission objects.
    Permission values: "View", "Edit", "Admin".
    If override_folder_permissions is true, folder-inherited permissions are replaced.
  EOT
  type = map(object({
    override_folder_permissions = optional(bool, false)
    team_permissions = list(object({
      team_key   = string
      permission = string
    }))
  }))
  default = {}

  validation {
    condition = alltrue([
      for dk, dv in var.dashboard_permissions : alltrue([
        for tp in dv.team_permissions : contains(["View", "Edit", "Admin"], tp.permission)
      ])
    ])
    error_message = "Each team permission must be one of: View, Edit, Admin."
  }
}

variable "user_permission_overrides" {
  description = <<-EOT
    Granular per-user permission overrides on individual dashboards.
    Each entry grants a specific user a permission on a specific dashboard.
  EOT
  type = list(object({
    dashboard_key = string
    user_id       = number
    permission    = string
  }))
  default = []

  validation {
    condition = alltrue([
      for item in var.user_permission_overrides : contains(["View", "Edit", "Admin"], item.permission)
    ])
    error_message = "Each user permission must be one of: View, Edit, Admin."
  }
}

variable "public_dashboards" {
  description = <<-EOT
    List of dashboards to expose via Grafana public dashboard sharing.
    Intended for NOC displays and status pages.
  EOT
  type = list(object({
    dashboard_key            = string
    uid                      = string
    is_enabled               = optional(bool, true)
    time_selection_enabled   = optional(bool, false)
    annotations_enabled      = optional(bool, false)
    share                    = optional(string, "public")
  }))
  default = []
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------

locals {
  # Map permission string names to Grafana numeric codes
  permission_codes = {
    "View"  = 1
    "Edit"  = 2
    "Admin" = 4
  }

  # Flatten team permissions into a list for grafana_dashboard_permission_item
  flattened_team_permissions = flatten([
    for dk, dv in var.dashboard_permissions : [
      for tp in dv.team_permissions : {
        key            = "${dk}--team-${tp.team_key}"
        dashboard_uid  = var.dashboard_uids[dk]
        team_id        = var.team_ids[tp.team_key]
        permission     = tp.permission
      }
    ]
  ])

  flattened_team_permissions_map = {
    for item in local.flattened_team_permissions : item.key => item
  }

  # Flatten user overrides into a map for grafana_dashboard_permission_item
  flattened_user_overrides = {
    for idx, item in var.user_permission_overrides :
    "${item.dashboard_key}--user-${item.user_id}" => {
      dashboard_uid = var.dashboard_uids[item.dashboard_key]
      user_id       = item.user_id
      permission    = item.permission
    }
  }

  # Public dashboards keyed by dashboard_key for for_each
  public_dashboards_map = {
    for pd in var.public_dashboards : pd.dashboard_key => pd
  }
}

# -----------------------------------------------------------------------------
# Resources - Per-Dashboard Team Permission Overrides
# -----------------------------------------------------------------------------

resource "grafana_dashboard_permission" "team_overrides" {
  for_each = {
    for dk, dv in var.dashboard_permissions : dk => dv
    if dv.override_folder_permissions
  }

  org_id        = var.org_id
  dashboard_uid = var.dashboard_uids[each.key]

  dynamic "permissions" {
    for_each = each.value.team_permissions
    content {
      team_id    = var.team_ids[permissions.value.team_key]
      permission = local.permission_codes[permissions.value.permission]
    }
  }
}

# -----------------------------------------------------------------------------
# Resources - Granular Per-Item Permission Overrides (Teams)
# -----------------------------------------------------------------------------

resource "grafana_dashboard_permission_item" "team_items" {
  for_each = {
    for dk, dv in var.dashboard_permissions : dk => dv
    if !dv.override_folder_permissions
  }

  org_id        = var.org_id
  dashboard_uid = var.dashboard_uids[each.key]
  team          = var.team_ids[each.value.team_permissions[0].team_key]
  permission    = each.value.team_permissions[0].permission
}

# For dashboards with multiple non-overriding team permissions, use the
# flattened map so each team gets its own resource instance.
resource "grafana_dashboard_permission_item" "team_granular" {
  for_each = local.flattened_team_permissions_map

  org_id        = var.org_id
  dashboard_uid = each.value.dashboard_uid
  team          = each.value.team_id
  permission    = each.value.permission
}

# -----------------------------------------------------------------------------
# Resources - Granular Per-User Permission Overrides
# -----------------------------------------------------------------------------

resource "grafana_dashboard_permission_item" "user_overrides" {
  for_each = local.flattened_user_overrides

  org_id        = var.org_id
  dashboard_uid = each.value.dashboard_uid
  user          = each.value.user_id
  permission    = each.value.permission
}

# -----------------------------------------------------------------------------
# Resources - Public Dashboard Sharing (NOC / Status Pages)
# -----------------------------------------------------------------------------

resource "grafana_dashboard_public" "public" {
  for_each = local.public_dashboards_map

  org_id        = var.org_id
  dashboard_uid = var.dashboard_uids[each.key]
  uid           = each.value.uid
  is_enabled    = each.value.is_enabled
  share         = each.value.share

  time_selection_enabled = each.value.time_selection_enabled
  annotations_enabled    = each.value.annotations_enabled
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "public_dashboard_urls" {
  description = "Map of dashboard keys to their public access tokens and UIDs"
  value = {
    for key, pd in grafana_dashboard_public.public : key => {
      uid           = pd.uid
      access_token  = pd.access_token
      dashboard_uid = pd.dashboard_uid
      is_enabled    = pd.is_enabled
    }
  }
}

output "permission_ids" {
  description = "List of all dashboard permission resource IDs"
  value = concat(
    [for key, perm in grafana_dashboard_permission.team_overrides : perm.id],
    [for key, item in grafana_dashboard_permission_item.team_granular : item.id],
    [for key, item in grafana_dashboard_permission_item.user_overrides : item.id],
  )
}
