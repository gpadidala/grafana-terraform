###############################################################################
# Grafana Folder Module - Phase 4
# Creates L0-L3 dashboard hierarchy folders with team-based RBAC permissions
###############################################################################

terraform {
  required_providers {
    grafana = {
      source = "grafana/grafana"
    }
  }
}

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------

variable "org_id" {
  description = "Grafana organization ID"
  type        = string
}

variable "team_ids" {
  description = "Map of team name to Grafana team ID"
  type        = map(string)
  default     = {}
  # Expected keys: platform_admin, sre, devops, executive, app_eng, network, security, data, cloud
}

variable "folders" {
  description = "List of folder definitions with title and uid"
  type = list(object({
    title = string
    uid   = string
  }))
  default = [
    { title = "Home", uid = "home" },
    { title = "Executive Command Center (L0)", uid = "l0-executive" },
    { title = "Domain Overview (L1)", uid = "l1-domain" },
    { title = "Service Dashboards (L2)", uid = "l2-service" },
    { title = "Deep Dive Debug (L3)", uid = "l3-debug" },
    { title = "SRE", uid = "sre" },
    { title = "Network", uid = "network" },
    { title = "Security", uid = "security" },
    { title = "Cloud & Cost", uid = "cloud-cost" },
    { title = "Data Pipelines", uid = "data-pipelines" },
    { title = "Alerting", uid = "alerting" },
  ]
}

variable "folder_permissions" {
  description = "Override map of folder uid to list of permission objects. If empty, the default permission matrix is used."
  type = map(list(object({
    team_key   = string
    permission = string
  })))
  default = {}
}

variable "user_permission_overrides" {
  description = "Map of folder uid to list of per-user permission items for granular overrides"
  type = map(list(object({
    user_id    = string
    permission = string
  })))
  default = {}
}

# ---------------------------------------------------------------------------
# Locals - Permission Matrix
# ---------------------------------------------------------------------------

locals {
  # Build a map keyed by folder uid for easy lookup
  folder_map = { for f in var.folders : f.uid => f }

  # Default team-based permission matrix
  # Permission values: "Admin", "Edit", "View"
  # Only teams with explicit access are listed; omitted teams get no access.
  default_permission_matrix = {
    "home" = [
      { team_key = "platform_admin", permission = "Admin" },
      { team_key = "sre", permission = "View" },
      { team_key = "devops", permission = "View" },
      { team_key = "executive", permission = "View" },
      { team_key = "app_eng", permission = "View" },
      { team_key = "network", permission = "View" },
      { team_key = "security", permission = "View" },
      { team_key = "data", permission = "View" },
      { team_key = "cloud", permission = "View" },
    ]
    "l0-executive" = [
      { team_key = "platform_admin", permission = "Admin" },
      { team_key = "executive", permission = "View" },
    ]
    "l1-domain" = [
      { team_key = "platform_admin", permission = "Admin" },
      { team_key = "sre", permission = "Edit" },
      { team_key = "executive", permission = "View" },
      { team_key = "app_eng", permission = "View" },
    ]
    "l2-service" = [
      { team_key = "platform_admin", permission = "Admin" },
      { team_key = "sre", permission = "Edit" },
      { team_key = "devops", permission = "Edit" },
      { team_key = "app_eng", permission = "View" },
    ]
    "l3-debug" = [
      { team_key = "platform_admin", permission = "Admin" },
      { team_key = "sre", permission = "Edit" },
      { team_key = "devops", permission = "Edit" },
    ]
    "sre" = [
      { team_key = "platform_admin", permission = "Admin" },
      { team_key = "sre", permission = "Admin" },
    ]
    "network" = [
      { team_key = "platform_admin", permission = "Admin" },
      { team_key = "sre", permission = "View" },
      { team_key = "network", permission = "Admin" },
    ]
    "security" = [
      { team_key = "platform_admin", permission = "Admin" },
      { team_key = "security", permission = "Admin" },
    ]
    "cloud-cost" = [
      { team_key = "platform_admin", permission = "Admin" },
      { team_key = "executive", permission = "View" },
      { team_key = "cloud", permission = "Edit" },
    ]
    "data-pipelines" = [
      { team_key = "platform_admin", permission = "Admin" },
      { team_key = "data", permission = "Admin" },
    ]
    "alerting" = [
      { team_key = "platform_admin", permission = "Admin" },
      { team_key = "sre", permission = "Edit" },
    ]
  }

  # Merge: use override if provided, otherwise fall back to default matrix
  effective_permissions = {
    for uid, _ in local.folder_map : uid => lookup(
      var.folder_permissions, uid, lookup(local.default_permission_matrix, uid, [])
    )
  }

  # Flatten permission entries for grafana_folder_permission_item
  permission_items_flat = flatten([
    for folder_uid, perms in local.effective_permissions : [
      for perm in perms : {
        folder_uid = folder_uid
        team_key   = perm.team_key
        permission = perm.permission
      }
    ]
  ])

  # Flatten user permission overrides
  user_overrides_flat = flatten([
    for folder_uid, overrides in var.user_permission_overrides : [
      for override in overrides : {
        folder_uid = folder_uid
        user_id    = override.user_id
        permission = override.permission
      }
    ]
  ])
}

# ---------------------------------------------------------------------------
# Resources - Folders
# ---------------------------------------------------------------------------

resource "grafana_folder" "this" {
  for_each = local.folder_map

  org_id = var.org_id
  title  = each.value.title
  uid    = each.value.uid

  lifecycle {
    prevent_destroy = true
  }
}

# ---------------------------------------------------------------------------
# Resources - Folder Permissions (full replacement per folder)
# ---------------------------------------------------------------------------

resource "grafana_folder_permission" "this" {
  for_each = {
    for uid, perms in local.effective_permissions : uid => perms
    if length(perms) > 0
  }

  org_id     = var.org_id
  folder_uid = grafana_folder.this[each.key].uid

  dynamic "permissions" {
    for_each = [
      for p in each.value : p
      if contains(keys(var.team_ids), p.team_key)
    ]
    content {
      team_id    = var.team_ids[permissions.value.team_key]
      permission = permissions.value.permission
    }
  }
}

# ---------------------------------------------------------------------------
# Resources - Granular Per-Item Permissions (user overrides)
# ---------------------------------------------------------------------------

resource "grafana_folder_permission_item" "user_overrides" {
  for_each = {
    for item in local.user_overrides_flat :
    "${item.folder_uid}:user:${item.user_id}" => item
  }

  org_id     = var.org_id
  folder_uid = grafana_folder.this[each.value.folder_uid].uid
  user       = each.value.user_id
  permission = each.value.permission
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "folder_uids" {
  description = "Map of folder title to UID"
  value = {
    for k, v in grafana_folder.this : v.title => v.uid
  }
}

output "folder_ids" {
  description = "Map of folder title to numeric Grafana ID"
  value = {
    for k, v in grafana_folder.this : v.title => v.id
  }
}
