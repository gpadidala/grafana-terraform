#--------------------------------------------------------------
# Phase 1: Organization Management
# Grafana Enterprise Terraform Module - Organizations
#
# Creates and manages Grafana organizations with admin users.
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

variable "org_name" {
  description = "Name of the Grafana organization"
  type        = string

  validation {
    condition     = length(var.org_name) >= 2 && length(var.org_name) <= 128
    error_message = "Organization name must be between 2 and 128 characters."
  }
}

variable "admin_users" {
  description = "List of admin user email addresses for this organization"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for email in var.admin_users : can(regex("^[^@]+@[^@]+\\.[^@]+$", email))])
    error_message = "All admin_users entries must be valid email addresses."
  }
}

# -----------------------------------------------------------------------------
# Resources
# -----------------------------------------------------------------------------

resource "grafana_organization" "main" {
  name    = var.org_name
  admins  = var.admin_users
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "org_id" {
  description = "The ID of the created Grafana organization"
  value       = grafana_organization.main.org_id
}
