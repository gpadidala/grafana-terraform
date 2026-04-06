#--------------------------------------------------------------
# Phase 2: Service Account Permissions
# Grafana Enterprise Terraform Module - SA Permissions
#
# Applies fine-grained folder/dashboard permissions per service
# account based on a least-privilege permissions matrix.
#--------------------------------------------------------------

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------

variable "folder_uids" {
  description = "Map of folder logical name to its UID (passed from folders module)"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------

locals {
  # -------------------------------------------------------------------------
  # Permissions matrix
  #
  # Each entry maps a service account key to a list of permission objects.
  #   permission = "Admin" | "Edit" | "View"
  #
  # Folder categories (logical names expected in var.folder_uids):
  #   Home, L0, L1, L2, L3, Alerting
  # -------------------------------------------------------------------------

  all_folder_keys     = keys(var.folder_uids)
  overview_folders    = [for k in local.all_folder_keys : k if contains(["Home", "L0", "L1"], k)]
  operational_folders = [for k in local.all_folder_keys : k if contains(["L2", "L3"], k)]
  non_alerting        = [for k in local.all_folder_keys : k if k != "Alerting"]

  # deployer: Admin on ALL folders
  deployer_permissions = {
    for folder_key in local.all_folder_keys : folder_key => {
      folder_uid = var.folder_uids[folder_key]
      permission = "Admin"
    }
  }

  # cicd: Edit on L2/L3 folders, View on L0/L1/Home
  cicd_permissions = merge(
    {
      for folder_key in local.operational_folders : folder_key => {
        folder_uid = var.folder_uids[folder_key]
        permission = "Edit"
      }
    },
    {
      for folder_key in local.overview_folders : folder_key => {
        folder_uid = var.folder_uids[folder_key]
        permission = "View"
      }
    }
  )

  # reporter: View on Home/L0/L1
  reporter_permissions = {
    for folder_key in local.overview_folders : folder_key => {
      folder_uid = var.folder_uids[folder_key]
      permission = "View"
    }
  }

  # alerting-engine: Admin on Alerting folder, View on all others
  alerting_permissions = merge(
    contains(local.all_folder_keys, "Alerting") ? {
      "Alerting" = {
        folder_uid = var.folder_uids["Alerting"]
        permission = "Admin"
      }
    } : {},
    {
      for folder_key in local.non_alerting : folder_key => {
        folder_uid = var.folder_uids[folder_key]
        permission = "View"
      }
    }
  )

  # Flatten into a single map keyed by "sa-key/folder-key" for for_each
  permission_entries = merge(
    {
      for folder_key, perm in local.deployer_permissions :
      "sa-terraform-deployer/${folder_key}" => merge(perm, {
        service_account_id = grafana_service_account.this["sa-terraform-deployer"].id
      })
    },
    {
      for folder_key, perm in local.cicd_permissions :
      "sa-cicd-pipeline/${folder_key}" => merge(perm, {
        service_account_id = grafana_service_account.this["sa-cicd-pipeline"].id
      })
    },
    {
      for folder_key, perm in local.reporter_permissions :
      "sa-reporter/${folder_key}" => merge(perm, {
        service_account_id = grafana_service_account.this["sa-reporter"].id
      })
    },
    {
      for folder_key, perm in local.alerting_permissions :
      "sa-alerting-engine/${folder_key}" => merge(perm, {
        service_account_id = grafana_service_account.this["sa-alerting-engine"].id
      })
    }
  )
}

# -----------------------------------------------------------------------------
# Resources
# -----------------------------------------------------------------------------

resource "grafana_folder_permission_item" "service_account" {
  for_each = length(var.folder_uids) > 0 ? local.permission_entries : {}

  org_id     = var.org_id
  folder_uid = each.value.folder_uid
  permission = each.value.permission

  user = tostring(each.value.service_account_id)
}
