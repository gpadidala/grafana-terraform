###############################################################################
# RBAC Module - Custom Roles and Role Assignments
# Phase 7: Grafana Enterprise RBAC for AIOps Observability Platform
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

variable "team_ids" {
  description = "Map of team name keys to Grafana team IDs"
  type        = map(number)
  # Expected keys:
  #   executive_leadership
  #   sre_oncall
  #   devops_engineering
  #   application_engineering
  #   network_engineering
}

variable "folder_uids" {
  description = "Map of folder name keys to Grafana folder UIDs"
  type        = map(string)
  # Expected keys:
  #   home, l0_executive, l1_domain, l2_service, l3_debug, network
}

# -----------------------------------------------------------------------------
# Locals - Permissions Matrix and Role-to-Team Mapping
# -----------------------------------------------------------------------------

locals {
  # ---- Role definitions with full permissions matrix ----
  roles = {
    "executive:viewer" = {
      name        = "custom:executive:viewer"
      description = "Executive leadership read-only view of high-level dashboards. No explore, annotations, or alerting write access."
      uid         = "custom-executive-viewer"
      permissions = [
        { action = "dashboards:read", scope = "folders:uid:${var.folder_uids["home"]}" },
        { action = "dashboards:read", scope = "folders:uid:${var.folder_uids["l0_executive"]}" },
        { action = "dashboards:read", scope = "folders:uid:${var.folder_uids["l1_domain"]}" },
        { action = "folders:read", scope = "folders:uid:${var.folder_uids["home"]}" },
        { action = "folders:read", scope = "folders:uid:${var.folder_uids["l0_executive"]}" },
        { action = "folders:read", scope = "folders:uid:${var.folder_uids["l1_domain"]}" },
      ]
    }

    "sre:power" = {
      name        = "custom:sre:power"
      description = "SRE power-user role with full dashboard CRUD, explore, annotations write, and alerting read/write across all folders."
      uid         = "custom-sre-power"
      permissions = [
        # Dashboard CRUD - all folders
        { action = "dashboards:read", scope = "dashboards:*" },
        { action = "dashboards:write", scope = "dashboards:*" },
        { action = "dashboards:create", scope = "folders:*" },
        { action = "dashboards:delete", scope = "dashboards:*" },
        # Folder read - all folders
        { action = "folders:read", scope = "folders:*" },
        # Explore access
        { action = "datasources:explore", scope = "*" },
        { action = "datasources:query", scope = "*" },
        # Annotations write
        { action = "annotations:read", scope = "annotations:*" },
        { action = "annotations:write", scope = "annotations:*" },
        { action = "annotations:create", scope = "annotations:*" },
        { action = "annotations:delete", scope = "annotations:*" },
        # Alerting read/write
        { action = "alert.rules:read", scope = "folders:*" },
        { action = "alert.rules:write", scope = "folders:*" },
        { action = "alert.rules:create", scope = "folders:*" },
        { action = "alert.silences:read", scope = "folders:*" },
        { action = "alert.silences:write", scope = "folders:*" },
        { action = "alert.silences:create", scope = "folders:*" },
        { action = "alert.notifications:read", scope = "" },
      ]
    }

    "developer:standard" = {
      name        = "custom:developer:standard"
      description = "Application developer role with read access to service-level dashboards, explore, and annotation create. No dashboard create/delete or alerting write."
      uid         = "custom-developer-standard"
      permissions = [
        # Dashboard read - specific folders only
        { action = "dashboards:read", scope = "folders:uid:${var.folder_uids["home"]}" },
        { action = "dashboards:read", scope = "folders:uid:${var.folder_uids["l1_domain"]}" },
        { action = "dashboards:read", scope = "folders:uid:${var.folder_uids["l2_service"]}" },
        { action = "dashboards:read", scope = "folders:uid:${var.folder_uids["l3_debug"]}" },
        # Folder read - specific folders only
        { action = "folders:read", scope = "folders:uid:${var.folder_uids["home"]}" },
        { action = "folders:read", scope = "folders:uid:${var.folder_uids["l1_domain"]}" },
        { action = "folders:read", scope = "folders:uid:${var.folder_uids["l2_service"]}" },
        { action = "folders:read", scope = "folders:uid:${var.folder_uids["l3_debug"]}" },
        # Explore access
        { action = "datasources:explore", scope = "*" },
        { action = "datasources:query", scope = "*" },
        # Annotations - create only
        { action = "annotations:read", scope = "annotations:*" },
        { action = "annotations:create", scope = "annotations:*" },
        # Alerting - read only
        { action = "alert.rules:read", scope = "folders:*" },
        { action = "alert.silences:read", scope = "folders:*" },
        { action = "alert.notifications:read", scope = "" },
      ]
    }

    "network:engineer" = {
      name        = "custom:network:engineer"
      description = "Network engineering role with read access to domain and network dashboards, write access to the network folder, and explore."
      uid         = "custom-network-engineer"
      permissions = [
        # Dashboard read - domain and network folders
        { action = "dashboards:read", scope = "folders:uid:${var.folder_uids["l1_domain"]}" },
        { action = "dashboards:read", scope = "folders:uid:${var.folder_uids["network"]}" },
        # Dashboard write - network folder only
        { action = "dashboards:write", scope = "folders:uid:${var.folder_uids["network"]}" },
        # Folder read
        { action = "folders:read", scope = "folders:uid:${var.folder_uids["l1_domain"]}" },
        { action = "folders:read", scope = "folders:uid:${var.folder_uids["network"]}" },
        # Explore access
        { action = "datasources:explore", scope = "*" },
        { action = "datasources:query", scope = "*" },
      ]
    }
  }

  # ---- Role-to-Team assignment mapping ----
  role_team_assignments = {
    "executive:viewer" = {
      team_ids = [var.team_ids["executive_leadership"]]
    }
    "sre:power" = {
      team_ids = [
        var.team_ids["sre_oncall"],
        var.team_ids["devops_engineering"],
      ]
    }
    "developer:standard" = {
      team_ids = [var.team_ids["application_engineering"]]
    }
    "network:engineer" = {
      team_ids = [var.team_ids["network_engineering"]]
    }
  }
}

# -----------------------------------------------------------------------------
# Resources - Custom RBAC Roles
# -----------------------------------------------------------------------------

resource "grafana_role" "custom" {
  for_each = local.roles

  org_id      = var.org_id
  uid         = each.value.uid
  name        = each.value.name
  description = each.value.description
  global      = false

  dynamic "permissions" {
    for_each = each.value.permissions
    content {
      action = permissions.value.action
      scope  = permissions.value.scope
    }
  }
}

# -----------------------------------------------------------------------------
# Resources - Role Assignments to Teams
# -----------------------------------------------------------------------------

resource "grafana_role_assignment" "teams" {
  for_each = local.role_team_assignments

  org_id   = var.org_id
  role_uid = grafana_role.custom[each.key].uid
  team_ids = each.value.team_ids
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "role_uids" {
  description = "Map of role keys to their Grafana UIDs"
  value = {
    for key, role in grafana_role.custom : key => role.uid
  }
}

output "role_assignment_ids" {
  description = "Map of role assignment keys to their resource IDs"
  value = {
    for key, assignment in grafana_role_assignment.teams : key => assignment.id
  }
}
