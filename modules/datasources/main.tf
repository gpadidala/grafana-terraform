###############################################################################
# Grafana Data Source Module - Phase 4
# Creates LGTM + Pyroscope data sources with full cross-linking correlations
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

variable "mimir_url" {
  description = "URL of the Mimir (Prometheus-compatible) endpoint"
  type        = string
}

variable "loki_url" {
  description = "URL of the Loki endpoint"
  type        = string
}

variable "tempo_url" {
  description = "URL of the Tempo endpoint"
  type        = string
}

variable "pyroscope_url" {
  description = "URL of the Pyroscope endpoint"
  type        = string
}

variable "alertmanager_url" {
  description = "URL of the Alertmanager endpoint"
  type        = string
}

variable "datasource_auth_headers" {
  description = "Optional map of datasource name to auth config for secure credentials"
  type = map(object({
    basic_auth_enabled  = optional(bool, false)
    basic_auth_username = optional(string, "")
    basic_auth_password = optional(string, "")
    custom_headers      = optional(map(string), {})
  }))
  default   = {}
  sensitive = true
}

# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------

locals {
  # Names used as stable keys throughout the module
  mimir_name        = "Mimir"
  loki_name         = "Loki"
  tempo_name        = "Tempo"
  pyroscope_name    = "Pyroscope"
  alertmanager_name = "Alertmanager"

  # Deterministic UIDs - used for cross-linking to avoid circular dependency
  # between resources (e.g. Mimir -> Tempo and Tempo -> Mimir).
  mimir_uid        = "ds-mimir"
  loki_uid         = "ds-loki"
  tempo_uid        = "ds-tempo"
  pyroscope_uid    = "ds-pyroscope"
  alertmanager_uid = "ds-alertmanager"
}

# ---------------------------------------------------------------------------
# Data Sources
# ---------------------------------------------------------------------------

# --- Mimir (Prometheus type) -----------------------------------------------

resource "grafana_data_source" "mimir" {
  org_id = var.org_id
  name   = local.mimir_name
  type   = "prometheus"
  url    = var.mimir_url
  uid    = local.mimir_uid

  is_default = true

  json_data_encoded = jsonencode({
    httpMethod = "POST"
    exemplarTraceIdDestinations = [
      {
        datasourceUid = local.tempo_uid
        name          = "traceID"
      }
    ]
    manageAlerts      = true
    prometheusType    = "Mimir"
    prometheusVersion = "2.x"
    timeInterval      = "15s"
  })

  basic_auth_enabled  = try(var.datasource_auth_headers[local.mimir_name].basic_auth_enabled, false)
  basic_auth_username = try(var.datasource_auth_headers[local.mimir_name].basic_auth_username, "")
}

# --- Loki ------------------------------------------------------------------

resource "grafana_data_source" "loki" {
  org_id = var.org_id
  name   = local.loki_name
  type   = "loki"
  url    = var.loki_url
  uid    = local.loki_uid

  json_data_encoded = jsonencode({
    maxLines = 1000
    derivedFields = [
      {
        matcherRegex  = "(?:traceID|trace_id|traceId)[\"=:]\\s*[\"']?([a-fA-F0-9]+)[\"']?"
        name          = "TraceID"
        url           = ""
        datasourceUid   = local.tempo_uid
        urlDisplayLabel = "View Trace"
      }
    ]
  })

  basic_auth_enabled  = try(var.datasource_auth_headers[local.loki_name].basic_auth_enabled, false)
  basic_auth_username = try(var.datasource_auth_headers[local.loki_name].basic_auth_username, "")
}

# --- Tempo -----------------------------------------------------------------

resource "grafana_data_source" "tempo" {
  org_id = var.org_id
  name   = local.tempo_name
  type   = "tempo"
  url    = var.tempo_url
  uid    = local.tempo_uid

  json_data_encoded = jsonencode({
    tracesToLogsV2 = {
      datasourceUid        = local.loki_uid
      filterByTraceID      = true
      filterBySpanID       = true
      spanStartTimeShift   = "-1h"
      spanEndTimeShift     = "1h"
      tags = [
        { key = "service.name", value = "service_name" }
      ]
    }
    tracesToMetrics = {
      datasourceUid = local.mimir_uid
      spanStartTimeShift = "-1h"
      spanEndTimeShift   = "1h"
      tags = [
        { key = "service.name", value = "service" }
      ]
      queries = [
        {
          name  = "Request Rate"
          query = "sum(rate(traces_spanmetrics_calls_total{$$__tags}[5m]))"
        },
        {
          name  = "Error Rate"
          query = "sum(rate(traces_spanmetrics_calls_total{$$__tags, status_code=\"STATUS_CODE_ERROR\"}[5m]))"
        }
      ]
    }
    tracesToProfiles = {
      datasourceUid    = local.pyroscope_uid
      profileTypeId    = "process_cpu:cpu:nanoseconds:cpu:nanoseconds"
      customQuery      = true
      query            = "{service_name=\"$${__span.tags.service.name}\"}"
      tags = [
        { key = "service.name", value = "service_name" }
      ]
    }
    serviceMap = {
      datasourceUid = local.mimir_uid
    }
    nodeGraph = {
      enabled = true
    }
    lokiSearch = {
      datasourceUid = local.loki_uid
    }
    search = {
      hide = false
    }
    spanBar = {
      type = "Tag"
      tag  = "http.path"
    }
  })

  basic_auth_enabled  = try(var.datasource_auth_headers[local.tempo_name].basic_auth_enabled, false)
  basic_auth_username = try(var.datasource_auth_headers[local.tempo_name].basic_auth_username, "")
}

# --- Pyroscope -------------------------------------------------------------

resource "grafana_data_source" "pyroscope" {
  org_id = var.org_id
  name   = local.pyroscope_name
  type   = "grafana-pyroscope-datasource"
  url    = var.pyroscope_url
  uid    = local.pyroscope_uid

  json_data_encoded = jsonencode({})

  basic_auth_enabled  = try(var.datasource_auth_headers[local.pyroscope_name].basic_auth_enabled, false)
  basic_auth_username = try(var.datasource_auth_headers[local.pyroscope_name].basic_auth_username, "")
}

# --- Alertmanager ----------------------------------------------------------

resource "grafana_data_source" "alertmanager" {
  org_id = var.org_id
  name   = local.alertmanager_name
  type   = "alertmanager"
  url    = var.alertmanager_url
  uid    = local.alertmanager_uid

  json_data_encoded = jsonencode({
    implementation           = "mimir"
    handleGrafanaManagedAlerts = true
  })

  basic_auth_enabled  = try(var.datasource_auth_headers[local.alertmanager_name].basic_auth_enabled, false)
  basic_auth_username = try(var.datasource_auth_headers[local.alertmanager_name].basic_auth_username, "")
}

# ---------------------------------------------------------------------------
# Secure Credentials via grafana_data_source_config
# ---------------------------------------------------------------------------

resource "grafana_data_source_config" "mimir" {
  count = contains(keys(var.datasource_auth_headers), local.mimir_name) ? 1 : 0

  org_id = var.org_id
  uid    = grafana_data_source.mimir.uid

  secure_json_data_encoded = jsonencode(merge(
    try(var.datasource_auth_headers[local.mimir_name].basic_auth_password, "") != "" ? {
      basicAuthPassword = var.datasource_auth_headers[local.mimir_name].basic_auth_password
    } : {},
    {
      for k, v in try(var.datasource_auth_headers[local.mimir_name].custom_headers, {}) :
      "httpHeaderValue${index(keys(var.datasource_auth_headers[local.mimir_name].custom_headers), k) + 1}" => v
    }
  ))

  http_headers = {
    for k, v in try(var.datasource_auth_headers[local.mimir_name].custom_headers, {}) :
    k => { value = v, secure = true }
  }
}

resource "grafana_data_source_config" "loki" {
  count = contains(keys(var.datasource_auth_headers), local.loki_name) ? 1 : 0

  org_id = var.org_id
  uid    = grafana_data_source.loki.uid

  secure_json_data_encoded = jsonencode(merge(
    try(var.datasource_auth_headers[local.loki_name].basic_auth_password, "") != "" ? {
      basicAuthPassword = var.datasource_auth_headers[local.loki_name].basic_auth_password
    } : {},
    {
      for k, v in try(var.datasource_auth_headers[local.loki_name].custom_headers, {}) :
      "httpHeaderValue${index(keys(var.datasource_auth_headers[local.loki_name].custom_headers), k) + 1}" => v
    }
  ))

  http_headers = {
    for k, v in try(var.datasource_auth_headers[local.loki_name].custom_headers, {}) :
    k => { value = v, secure = true }
  }
}

resource "grafana_data_source_config" "tempo" {
  count = contains(keys(var.datasource_auth_headers), local.tempo_name) ? 1 : 0

  org_id = var.org_id
  uid    = grafana_data_source.tempo.uid

  secure_json_data_encoded = jsonencode(merge(
    try(var.datasource_auth_headers[local.tempo_name].basic_auth_password, "") != "" ? {
      basicAuthPassword = var.datasource_auth_headers[local.tempo_name].basic_auth_password
    } : {},
    {
      for k, v in try(var.datasource_auth_headers[local.tempo_name].custom_headers, {}) :
      "httpHeaderValue${index(keys(var.datasource_auth_headers[local.tempo_name].custom_headers), k) + 1}" => v
    }
  ))

  http_headers = {
    for k, v in try(var.datasource_auth_headers[local.tempo_name].custom_headers, {}) :
    k => { value = v, secure = true }
  }
}

resource "grafana_data_source_config" "pyroscope" {
  count = contains(keys(var.datasource_auth_headers), local.pyroscope_name) ? 1 : 0

  org_id = var.org_id
  uid    = grafana_data_source.pyroscope.uid

  secure_json_data_encoded = jsonencode(merge(
    try(var.datasource_auth_headers[local.pyroscope_name].basic_auth_password, "") != "" ? {
      basicAuthPassword = var.datasource_auth_headers[local.pyroscope_name].basic_auth_password
    } : {},
    {
      for k, v in try(var.datasource_auth_headers[local.pyroscope_name].custom_headers, {}) :
      "httpHeaderValue${index(keys(var.datasource_auth_headers[local.pyroscope_name].custom_headers), k) + 1}" => v
    }
  ))

  http_headers = {
    for k, v in try(var.datasource_auth_headers[local.pyroscope_name].custom_headers, {}) :
    k => { value = v, secure = true }
  }
}

resource "grafana_data_source_config" "alertmanager" {
  count = contains(keys(var.datasource_auth_headers), local.alertmanager_name) ? 1 : 0

  org_id = var.org_id
  uid    = grafana_data_source.alertmanager.uid

  secure_json_data_encoded = jsonencode(merge(
    try(var.datasource_auth_headers[local.alertmanager_name].basic_auth_password, "") != "" ? {
      basicAuthPassword = var.datasource_auth_headers[local.alertmanager_name].basic_auth_password
    } : {},
    {
      for k, v in try(var.datasource_auth_headers[local.alertmanager_name].custom_headers, {}) :
      "httpHeaderValue${index(keys(var.datasource_auth_headers[local.alertmanager_name].custom_headers), k) + 1}" => v
    }
  ))

  http_headers = {
    for k, v in try(var.datasource_auth_headers[local.alertmanager_name].custom_headers, {}) :
    k => { value = v, secure = true }
  }
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "datasource_uids" {
  description = "Map of datasource name to UID"
  value = {
    (local.mimir_name)        = grafana_data_source.mimir.uid
    (local.loki_name)         = grafana_data_source.loki.uid
    (local.tempo_name)        = grafana_data_source.tempo.uid
    (local.pyroscope_name)    = grafana_data_source.pyroscope.uid
    (local.alertmanager_name) = grafana_data_source.alertmanager.uid
  }
}

output "datasource_ids" {
  description = "Map of datasource name to numeric Grafana ID"
  value = {
    (local.mimir_name)        = grafana_data_source.mimir.id
    (local.loki_name)         = grafana_data_source.loki.id
    (local.tempo_name)        = grafana_data_source.tempo.id
    (local.pyroscope_name)    = grafana_data_source.pyroscope.id
    (local.alertmanager_name) = grafana_data_source.alertmanager.id
  }
}
