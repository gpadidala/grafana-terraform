#--------------------------------------------------------------
# Phase 8: Scheduled Reports
# Grafana Enterprise Terraform Module - Reports
#
# Creates scheduled PDF/CSV reports for executive, SLO, and
# incident dashboards. Reports are emailed on configurable
# cadences (daily, weekly, monthly).
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

variable "reports" {
  description = "Map of report definitions keyed by slug"
  type = map(object({
    name            = string
    dashboard_uid   = string
    recipients      = list(string)
    frequency       = string
    time_range_from = string
    time_range_to   = string
    orientation     = optional(string, "landscape")
    layout          = optional(string, "grid")
    formats         = optional(list(string), ["pdf"])
    workdays_only   = optional(bool, false)
    day_of_month    = optional(string, "")
  }))

  default = {
    "weekly-executive-summary" = {
      name            = "Weekly Executive Summary"
      dashboard_uid   = "executive-command-center"
      recipients      = ["exec@ops.internal", "vp-engineering@ops.internal"]
      frequency       = "weekly"
      time_range_from = "now-7d"
      time_range_to   = "now"
      orientation     = "landscape"
      layout          = "grid"
      formats         = ["pdf"]
      workdays_only   = true
      day_of_month    = ""
    }

    "monthly-slo-compliance" = {
      name            = "Monthly SLO Compliance Report"
      dashboard_uid   = "slo-overview"
      recipients      = ["engineering-leads@ops.internal", "vp-engineering@ops.internal"]
      frequency       = "monthly"
      time_range_from = "now-30d"
      time_range_to   = "now"
      orientation     = "landscape"
      layout          = "grid"
      formats         = ["pdf", "csv"]
      workdays_only   = false
      day_of_month    = "1"
    }

    "daily-incident-summary" = {
      name            = "Daily Incident Summary"
      dashboard_uid   = "incident-management"
      recipients      = ["sre-oncall@ops.internal", "sre-leads@ops.internal"]
      frequency       = "daily"
      time_range_from = "now-24h"
      time_range_to   = "now"
      orientation     = "landscape"
      layout          = "grid"
      formats         = ["pdf"]
      workdays_only   = true
      day_of_month    = ""
    }
  }

  validation {
    condition     = length(var.reports) > 0
    error_message = "At least one report must be defined."
  }
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------

locals {
  # Build a flat recipients string per report (comma-separated)
  report_recipients = {
    for slug, report in var.reports : slug => join(";", report.recipients)
  }
}

# -----------------------------------------------------------------------------
# Resources
# -----------------------------------------------------------------------------

resource "grafana_report" "this" {
  for_each = var.reports

  org_id        = var.org_id
  name          = each.value.name
  dashboard_uid = each.value.dashboard_uid
  recipients    = local.report_recipients[each.key]
  formats       = each.value.formats
  orientation   = each.value.orientation
  layout        = each.value.layout

  schedule {
    frequency     = each.value.frequency
    workdays_only = each.value.workdays_only

    # Only set start_date; Grafana uses it as the anchor for recurring schedules
    start_date = timestamp()
  }

  time_range {
    from = each.value.time_range_from
    to   = each.value.time_range_to
  }

  lifecycle {
    # start_date is set once at creation time; ignore subsequent drift
    ignore_changes = [schedule[0].start_date]
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "report_ids" {
  description = "Map of report slug to Grafana report ID"
  value = {
    for slug, report in grafana_report.this : slug => report.id
  }
}

output "report_names" {
  description = "List of all provisioned report names"
  value       = [for slug, report in grafana_report.this : report.name]
}
