#--------------------------------------------------------------
# Phase 2: Service Account Provisioning
# Grafana Enterprise Terraform Module - Service Accounts
#
# Creates service accounts with role-based access and generates
# API tokens for automation workflows.
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
  description = "The Grafana organization ID to create service accounts in"
  type        = number
}

variable "service_accounts" {
  description = "Map of service account key to configuration (role, is_disabled)"
  type = map(object({
    role        = string
    is_disabled = bool
  }))

  default = {
    "sa-terraform-deployer" = {
      role        = "Admin"
      is_disabled = false
    }
    "sa-cicd-pipeline" = {
      role        = "Editor"
      is_disabled = false
    }
    "sa-reporter" = {
      role        = "Viewer"
      is_disabled = false
    }
    "sa-alerting-engine" = {
      role        = "Editor"
      is_disabled = false
    }
  }

  validation {
    condition     = alltrue([for sa in var.service_accounts : contains(["Admin", "Editor", "Viewer"], sa.role)])
    error_message = "Service account role must be one of: Admin, Editor, Viewer."
  }
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------

locals {
  # Normalize service account keys for consistent referencing
  sa_keys = keys(var.service_accounts)
}

# -----------------------------------------------------------------------------
# Resources
# -----------------------------------------------------------------------------

resource "grafana_service_account" "this" {
  for_each = var.service_accounts

  org_id      = var.org_id
  name        = each.key
  role        = each.value.role
  is_disabled = each.value.is_disabled
}

resource "grafana_service_account_token" "this" {
  for_each = var.service_accounts

  org_id             = var.org_id
  name               = "${each.key}-token"
  service_account_id = grafana_service_account.this[each.key].id
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "service_account_ids" {
  description = "Map of service account name to its ID"
  value = {
    for key, sa in grafana_service_account.this : key => sa.id
  }
}

output "service_account_tokens" {
  description = "Map of service account name to its API token (sensitive)"
  sensitive   = true
  value = {
    for key, token in grafana_service_account_token.this : key => token.key
  }
}
