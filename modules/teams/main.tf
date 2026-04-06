#--------------------------------------------------------------
# Phase 3: Team Provisioning
# Grafana Enterprise Terraform Module - Teams
#
# Creates platform teams with membership and optional SSO/LDAP
# external group mappings for federated identity.
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
  description = "The Grafana organization ID to create teams in"
  type        = number
}

variable "teams" {
  description = "List of team definitions with optional SSO group mapping"
  type = list(object({
    name         = string
    display_name = string
    email        = string
    members      = list(string)
    sso_group    = optional(string, "")
  }))

  default = [
    {
      name         = "platform-administrators"
      display_name = "Platform Administrators"
      email        = "platform-admins@ops.internal"
      members      = []
      sso_group    = ""
    },
    {
      name         = "sre-oncall"
      display_name = "SRE & On-Call"
      email        = "sre-oncall@ops.internal"
      members      = []
      sso_group    = ""
    },
    {
      name         = "devops-engineering"
      display_name = "DevOps Engineering"
      email        = "devops@ops.internal"
      members      = []
      sso_group    = ""
    },
    {
      name         = "executive-leadership"
      display_name = "Executive Leadership"
      email        = "exec@ops.internal"
      members      = []
      sso_group    = ""
    },
    {
      name         = "application-engineering"
      display_name = "Application Engineering"
      email        = "app-eng@ops.internal"
      members      = []
      sso_group    = ""
    },
    {
      name         = "network-engineering"
      display_name = "Network Engineering"
      email        = "net-eng@ops.internal"
      members      = []
      sso_group    = ""
    },
    {
      name         = "security-operations"
      display_name = "Security Operations"
      email        = "secops@ops.internal"
      members      = []
      sso_group    = ""
    },
    {
      name         = "data-platform"
      display_name = "Data Platform"
      email        = "data-platform@ops.internal"
      members      = []
      sso_group    = ""
    },
    {
      name         = "cloud-infrastructure"
      display_name = "Cloud Infrastructure"
      email        = "cloud-infra@ops.internal"
      members      = []
      sso_group    = ""
    },
  ]
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------

locals {
  # Convert list to map keyed by team name for for_each iteration
  teams_map = {
    for team in var.teams : team.name => team
  }

  # Filter teams that have SSO group mappings configured
  teams_with_sso = {
    for name, team in local.teams_map : name => team
    if team.sso_group != null && team.sso_group != ""
  }
}

# -----------------------------------------------------------------------------
# Resources
# -----------------------------------------------------------------------------

resource "grafana_team" "this" {
  for_each = local.teams_map

  org_id  = var.org_id
  name    = each.value.display_name
  email   = each.value.email
  members = each.value.members
}

resource "grafana_team_external_group" "this" {
  for_each = local.teams_with_sso

  team_id = grafana_team.this[each.key].id
  groups  = [each.value.sso_group]
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "team_ids" {
  description = "Map of team name to Grafana team ID"
  value = {
    for name, team in grafana_team.this : name => team.id
  }
}

output "teams_with_sso_mapping" {
  description = "List of team names that have SSO/LDAP group mappings"
  value       = keys(local.teams_with_sso)
}
