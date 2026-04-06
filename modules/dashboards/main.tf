#--------------------------------------------------------------
# Phase 5: Dashboard Provisioning
# Grafana Enterprise Terraform Module - Dashboards
#
# Auto-discovers and deploys dashboard JSON files from a
# structured directory. Maps sub-directories to Grafana
# folders and injects datasource/folder UIDs via templatefile().
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
  description = "The Grafana organization ID to deploy dashboards into"
  type        = number
}

variable "dashboards_path" {
  description = "Absolute or relative path to the root dashboards directory containing sub-folders (home, L0-executive, L1-domain, L2-service, L3-debug)"
  type        = string

  validation {
    condition     = length(var.dashboards_path) > 0
    error_message = "dashboards_path must not be empty."
  }
}

variable "folder_uids" {
  description = "Map of folder name to Grafana folder UID (e.g. { home = \"abc123\", l0-executive = \"def456\" })"
  type        = map(string)

  validation {
    condition     = length(var.folder_uids) > 0
    error_message = "folder_uids must contain at least one entry."
  }
}

variable "datasource_uids" {
  description = "Map of datasource name to UID (e.g. { mimir = \"uid1\", loki = \"uid2\", tempo = \"uid3\", pyroscope = \"uid4\" })"
  type        = map(string)

  validation {
    condition     = length(var.datasource_uids) > 0
    error_message = "datasource_uids must contain at least one entry."
  }
}

variable "platform_version" {
  description = "Platform release version tag included in the dashboard deploy message"
  type        = string
  default     = "0.0.0"

  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+", var.platform_version))
    error_message = "platform_version must follow semantic versioning (e.g. 1.2.3)."
  }
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------

locals {
  # Directory name to folder UID mapping.
  # Keys are the sub-directory names found under dashboards_path.
  dir_to_folder_uid = {
    "home"         = lookup(var.folder_uids, "home", null)
    "L0-executive" = lookup(var.folder_uids, "l0-executive", null)
    "L1-domain"    = lookup(var.folder_uids, "l1-domain", null)
    "L2-service"   = lookup(var.folder_uids, "l2-service", null)
    "L3-debug"     = lookup(var.folder_uids, "l3-debug", null)
  }

  # Discover all JSON files under the dashboards path.
  # fileset returns paths relative to the base path, e.g. "home/overview.json"
  discovered_files = fileset(var.dashboards_path, "**/*.json")

  # Build a flat map keyed by "dir/filename" with all metadata needed for deployment.
  dashboard_map = {
    for file_path in local.discovered_files : file_path => {
      full_path  = "${var.dashboards_path}/${file_path}"
      dir_name   = dirname(file_path)
      file_name  = basename(file_path)
      folder_uid = lookup(local.dir_to_folder_uid, dirname(file_path), null)
    }
  }

  # Filter out entries whose directory did not map to a known folder UID.
  valid_dashboards = {
    for key, meta in local.dashboard_map : key => meta
    if meta.folder_uid != null
  }
}

# -----------------------------------------------------------------------------
# Resources
# -----------------------------------------------------------------------------

resource "grafana_dashboard" "this" {
  for_each = local.valid_dashboards

  org_id    = var.org_id
  folder    = each.value.folder_uid
  overwrite = true

  config_json = templatefile(each.value.full_path, merge(
    # Inject every datasource UID as ds_<name>
    { for name, uid in var.datasource_uids : "ds_${name}" => uid },
    # Inject every folder UID as folder_<name>
    { for name, uid in var.folder_uids : "folder_${name}" => uid },
    # Inject the platform version
    { platform_version = var.platform_version }
  ))

  message = "Deployed by Terraform - platform v${var.platform_version}"
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "dashboard_uids" {
  description = "Map of dashboard file path to its Grafana UID"
  value = {
    for key, dash in grafana_dashboard.this : key => dash.uid
  }
}

output "dashboard_urls" {
  description = "Map of dashboard file path to its Grafana URL"
  value = {
    for key, dash in grafana_dashboard.this : key => dash.url
  }
}
