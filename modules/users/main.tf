#--------------------------------------------------------------
# Phase 3: User Provisioning
# Grafana Enterprise Terraform Module - Users
#
# Provisions local Grafana users with role assignments.
# For production, SSO/LDAP is preferred; these serve as
# break-glass and service-oriented accounts.
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
  description = "The Grafana organization ID to associate users with"
  type        = number
}

variable "users" {
  description = "Map of login name to user configuration"
  type = map(object({
    name               = string
    email              = string
    password_sensitive = string
    is_admin           = bool
  }))

  default = {
    "platform-admin" = {
      name               = "Platform Administrator"
      email              = "platform-admin@ops.internal"
      password_sensitive = ""
      is_admin           = true
    }
    "sre-admin" = {
      name               = "SRE Administrator"
      email              = "sre-admin@ops.internal"
      password_sensitive = ""
      is_admin           = true
    }
    "break-glass-admin" = {
      name               = "Break Glass Administrator"
      email              = "break-glass@ops.internal"
      password_sensitive = ""
      is_admin           = true
    }
    "editor-user" = {
      name               = "Editor User"
      email              = "editor@ops.internal"
      password_sensitive = ""
      is_admin           = false
    }
    "viewer-user" = {
      name               = "Viewer User"
      email              = "viewer@ops.internal"
      password_sensitive = ""
      is_admin           = false
    }
  }

  sensitive = true

  validation {
    condition     = alltrue([for u in var.users : can(regex("^[^@]+@[^@]+\\.[^@]+$", u.email))])
    error_message = "All user email addresses must be valid."
  }
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------

locals {
  # Separate admin and non-admin users for auditing/output clarity
  admin_logins = [for login, cfg in var.users : login if cfg.is_admin]
  user_logins  = [for login, cfg in var.users : login if !cfg.is_admin]
}

# -----------------------------------------------------------------------------
# Resources
# -----------------------------------------------------------------------------

resource "grafana_user" "this" {
  for_each = var.users

  login    = each.key
  name     = each.value.name
  email    = each.value.email
  password = each.value.password_sensitive
  is_admin = each.value.is_admin
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "user_ids" {
  description = "Map of user login to Grafana user ID"
  value = {
    for login, user in grafana_user.this : login => user.user_id
  }
}

output "admin_logins" {
  description = "List of admin user logins for reference"
  value       = local.admin_logins
}

output "user_logins" {
  description = "List of non-admin user logins for reference"
  value       = local.user_logins
}
