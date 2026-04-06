#--------------------------------------------------------------
# Phase 5: Library Panel Provisioning
# Grafana Enterprise Terraform Module - Library Panels
#
# Creates reusable library panels shared across dashboards:
# navigation breadcrumb, platform health stats, SLO compliance
# table, and datasource status indicators.
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
  description = "The Grafana organization ID to create library panels in"
  type        = number
}

variable "folder_uids" {
  description = "Map of folder name to Grafana folder UID (e.g. { home = \"abc\", l0-executive = \"def\" })"
  type        = map(string)

  validation {
    condition     = contains(keys(var.folder_uids), "home") && contains(keys(var.folder_uids), "l0-executive")
    error_message = "folder_uids must include at least 'home' and 'l0-executive' keys."
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

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------

locals {
  mimir_uid    = lookup(var.datasource_uids, "mimir", "")
  loki_uid     = lookup(var.datasource_uids, "loki", "")
  tempo_uid    = lookup(var.datasource_uids, "tempo", "")
  pyroscope_uid = lookup(var.datasource_uids, "pyroscope", "")

  home_folder_uid          = lookup(var.folder_uids, "home", "")
  l0_executive_folder_uid  = lookup(var.folder_uids, "l0-executive", "")
}

# -----------------------------------------------------------------------------
# Resources
# -----------------------------------------------------------------------------

# (a) Navigation Breadcrumb Panel
resource "grafana_library_panel" "nav_breadcrumb" {
  org_id     = var.org_id
  name       = "nav-breadcrumb"
  folder_uid = local.home_folder_uid

  model_json = jsonencode({
    type        = "text"
    title       = "Navigation"
    description = "Breadcrumb navigation across dashboard tiers"
    transparent = true

    fieldConfig = {
      defaults = {
        custom = {}
      }
      overrides = []
    }

    options = {
      mode    = "html"
      code    = { language = "html", showLineNumbers = false, showMiniMap = false }
      content = <<-HTML
        <div style="display:flex;align-items:center;gap:8px;font-size:14px;padding:4px 0;">
          <a href="/d/$${__dashboard.uid}/home" style="color:#6E9FFF;text-decoration:none;font-weight:600;">Home</a>
          <span style="color:#8e8e8e;">&#8594;</span>
          <a href="/dashboards/f/$${folder_l0_executive}/" style="color:#6E9FFF;text-decoration:none;">L0 Executive</a>
          <span style="color:#8e8e8e;">&#8594;</span>
          <a href="/dashboards/f/$${folder_l1_domain}/" style="color:#6E9FFF;text-decoration:none;">L1 Domain</a>
          <span style="color:#8e8e8e;">&#8594;</span>
          <a href="/dashboards/f/$${folder_l2_service}/" style="color:#6E9FFF;text-decoration:none;">L2 Service</a>
          <span style="color:#8e8e8e;">&#8594;</span>
          <a href="/dashboards/f/$${folder_l3_debug}/" style="color:#6E9FFF;text-decoration:none;">L3 Debug</a>
        </div>
      HTML
    }

    pluginVersion = "11.0.0"
    targets       = []
    datasource    = { type = "datasource", uid = "-- Dashboard --" }

    gridPos = {
      h = 2
      w = 24
      x = 0
      y = 0
    }
  })
}

# (b) Platform Health Stats Panel
resource "grafana_library_panel" "platform_health_stats" {
  org_id     = var.org_id
  name       = "platform-health-stats"
  folder_uid = local.home_folder_uid

  model_json = jsonencode({
    type        = "stat"
    title       = "Platform Health"
    description = "Key platform health indicators at a glance"

    datasource = {
      type = "prometheus"
      uid  = local.mimir_uid
    }

    fieldConfig = {
      defaults = {
        color = {
          mode = "thresholds"
        }
        thresholds = {
          mode = "absolute"
          steps = [
            { color = "red", value = null },
            { color = "orange", value = 50 },
            { color = "green", value = 90 }
          ]
        }
        mappings = []
        custom   = {}
      }
      overrides = [
        {
          matcher = { id = "byName", options = "Up Services" }
          properties = [
            { id = "unit", value = "short" },
            {
              id    = "thresholds"
              value = {
                mode = "absolute"
                steps = [
                  { color = "red", value = null },
                  { color = "orange", value = 5 },
                  { color = "green", value = 10 }
                ]
              }
            }
          ]
        },
        {
          matcher = { id = "byName", options = "Error Rate" }
          properties = [
            { id = "unit", value = "percent" },
            { id = "decimals", value = 2 },
            {
              id    = "thresholds"
              value = {
                mode = "absolute"
                steps = [
                  { color = "green", value = null },
                  { color = "orange", value = 1 },
                  { color = "red", value = 5 }
                ]
              }
            }
          ]
        },
        {
          matcher = { id = "byName", options = "P99 Latency" }
          properties = [
            { id = "unit", value = "ms" },
            { id = "decimals", value = 0 },
            {
              id    = "thresholds"
              value = {
                mode = "absolute"
                steps = [
                  { color = "green", value = null },
                  { color = "orange", value = 500 },
                  { color = "red", value = 2000 }
                ]
              }
            }
          ]
        },
        {
          matcher = { id = "byName", options = "Active Alerts" }
          properties = [
            { id = "unit", value = "short" },
            {
              id    = "thresholds"
              value = {
                mode = "absolute"
                steps = [
                  { color = "green", value = null },
                  { color = "orange", value = 5 },
                  { color = "red", value = 20 }
                ]
              }
            }
          ]
        }
      ]
    }

    options = {
      reduceOptions = {
        values = false
        calcs  = ["lastNotNull"]
        fields = ""
      }
      orientation   = "horizontal"
      textMode      = "auto"
      wideLayout    = true
      colorMode     = "background"
      graphMode     = "area"
      justifyMode   = "auto"
      showPercentChange = false
    }

    pluginVersion = "11.0.0"

    targets = [
      {
        refId      = "A"
        datasource = { type = "prometheus", uid = local.mimir_uid }
        expr       = "count(up{job=~\".+\"} == 1)"
        legendFormat = "Up Services"
        instant    = true
      },
      {
        refId      = "B"
        datasource = { type = "prometheus", uid = local.mimir_uid }
        expr       = "100 * sum(rate(http_requests_total{status=~\"5..\"}[$__rate_interval])) / clamp_min(sum(rate(http_requests_total[$__rate_interval])), 1)"
        legendFormat = "Error Rate"
        instant    = true
      },
      {
        refId      = "C"
        datasource = { type = "prometheus", uid = local.mimir_uid }
        expr       = "histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[$__rate_interval])) by (le)) * 1000"
        legendFormat = "P99 Latency"
        instant    = true
      },
      {
        refId      = "D"
        datasource = { type = "prometheus", uid = local.mimir_uid }
        expr       = "count(ALERTS{alertstate=\"firing\"})"
        legendFormat = "Active Alerts"
        instant    = true
      }
    ]

    gridPos = {
      h = 4
      w = 24
      x = 0
      y = 2
    }
  })
}

# (c) SLO Compliance Table Panel
resource "grafana_library_panel" "slo_compliance_table" {
  org_id     = var.org_id
  name       = "slo-compliance-table"
  folder_uid = local.l0_executive_folder_uid

  model_json = jsonencode({
    type        = "table"
    title       = "SLO Compliance"
    description = "Service-level objective compliance overview with budget burn tracking"

    datasource = {
      type = "prometheus"
      uid  = local.mimir_uid
    }

    fieldConfig = {
      defaults = {
        color = {
          mode = "thresholds"
        }
        custom = {
          align       = "auto"
          cellOptions = { type = "auto" }
          filterable  = true
          inspect     = true
        }
        thresholds = {
          mode = "absolute"
          steps = [
            { color = "red", value = null },
            { color = "orange", value = 95 },
            { color = "green", value = 99 }
          ]
        }
        mappings = []
      }
      overrides = [
        {
          matcher = { id = "byName", options = "Service" }
          properties = [
            { id = "custom.width", value = 200 },
            { id = "custom.cellOptions", value = { type = "auto" } }
          ]
        },
        {
          matcher = { id = "byName", options = "SLO Target" }
          properties = [
            { id = "unit", value = "percent" },
            { id = "decimals", value = 2 },
            { id = "custom.width", value = 120 }
          ]
        },
        {
          matcher = { id = "byName", options = "Current SLI" }
          properties = [
            { id = "unit", value = "percent" },
            { id = "decimals", value = 3 },
            { id = "custom.width", value = 120 },
            {
              id    = "custom.cellOptions"
              value = {
                type = "color-background"
                mode = "basic"
              }
            }
          ]
        },
        {
          matcher = { id = "byName", options = "Budget Remaining" }
          properties = [
            { id = "unit", value = "percent" },
            { id = "decimals", value = 1 },
            { id = "custom.width", value = 160 },
            {
              id    = "thresholds"
              value = {
                mode = "absolute"
                steps = [
                  { color = "red", value = null },
                  { color = "orange", value = 25 },
                  { color = "green", value = 50 }
                ]
              }
            },
            {
              id    = "custom.cellOptions"
              value = {
                type = "gauge"
                mode = "basic"
              }
            }
          ]
        },
        {
          matcher = { id = "byName", options = "Status" }
          properties = [
            { id = "custom.width", value = 100 },
            {
              id    = "mappings"
              value = [
                { type = "value", options = { "1" = { text = "OK", color = "green" } } },
                { type = "value", options = { "0" = { text = "BREACH", color = "red" } } }
              ]
            }
          ]
        }
      ]
    }

    options = {
      showHeader  = true
      footer      = { show = false, reducer = ["sum"], fields = "" }
      frameIndex  = 0
      sortBy      = [{ displayName = "Budget Remaining", desc = false }]
      cellHeight  = "sm"
    }

    pluginVersion = "11.0.0"

    transformations = [
      {
        id = "merge"
        options = {}
      },
      {
        id = "organize"
        options = {
          renameByName = {
            service          = "Service"
            slo_target       = "SLO Target"
            current_sli      = "Current SLI"
            budget_remaining = "Budget Remaining"
            status           = "Status"
          }
          indexByName = {
            service          = 0
            slo_target       = 1
            current_sli      = 2
            budget_remaining = 3
            status           = 4
          }
        }
      }
    ]

    targets = [
      {
        refId      = "A"
        datasource = { type = "prometheus", uid = local.mimir_uid }
        expr       = "slo:current_sli:ratio"
        legendFormat = "{{ service }}"
        instant    = true
        format     = "table"
      },
      {
        refId      = "B"
        datasource = { type = "prometheus", uid = local.mimir_uid }
        expr       = "slo:target:ratio"
        legendFormat = "{{ service }}"
        instant    = true
        format     = "table"
      },
      {
        refId      = "C"
        datasource = { type = "prometheus", uid = local.mimir_uid }
        expr       = "slo:error_budget_remaining:ratio * 100"
        legendFormat = "{{ service }}"
        instant    = true
        format     = "table"
      },
      {
        refId      = "D"
        datasource = { type = "prometheus", uid = local.mimir_uid }
        expr       = "slo:current_sli:ratio >= bool slo:target:ratio"
        legendFormat = "{{ service }}"
        instant    = true
        format     = "table"
      }
    ]

    gridPos = {
      h = 8
      w = 24
      x = 0
      y = 0
    }
  })
}

# (d) Data Source Status Panel
resource "grafana_library_panel" "datasource_status" {
  org_id     = var.org_id
  name       = "datasource-status"
  folder_uid = local.home_folder_uid

  model_json = jsonencode({
    type        = "stat"
    title       = "Data Source Health"
    description = "Health check status for each core observability datasource"

    datasource = {
      type = "prometheus"
      uid  = local.mimir_uid
    }

    fieldConfig = {
      defaults = {
        color = {
          mode = "thresholds"
        }
        thresholds = {
          mode = "absolute"
          steps = [
            { color = "red", value = null },
            { color = "green", value = 1 }
          ]
        }
        mappings = [
          {
            type    = "value"
            options = {
              "0" = { text = "DOWN", color = "red" }
              "1" = { text = "UP", color = "green" }
            }
          }
        ]
        custom = {}
      }
      overrides = [
        {
          matcher = { id = "byName", options = "Mimir" }
          properties = [
            { id = "displayName", value = "Mimir (Metrics)" },
            { id = "links", value = [{ title = "Mimir Health", url = "/connections/datasources/edit/${local.mimir_uid}" }] }
          ]
        },
        {
          matcher = { id = "byName", options = "Loki" }
          properties = [
            { id = "displayName", value = "Loki (Logs)" },
            { id = "links", value = [{ title = "Loki Health", url = "/connections/datasources/edit/${local.loki_uid}" }] }
          ]
        },
        {
          matcher = { id = "byName", options = "Tempo" }
          properties = [
            { id = "displayName", value = "Tempo (Traces)" },
            { id = "links", value = [{ title = "Tempo Health", url = "/connections/datasources/edit/${local.tempo_uid}" }] }
          ]
        },
        {
          matcher = { id = "byName", options = "Pyroscope" }
          properties = [
            { id = "displayName", value = "Pyroscope (Profiles)" },
            { id = "links", value = [{ title = "Pyroscope Health", url = "/connections/datasources/edit/${local.pyroscope_uid}" }] }
          ]
        }
      ]
    }

    options = {
      reduceOptions = {
        values = false
        calcs  = ["lastNotNull"]
        fields = ""
      }
      orientation   = "horizontal"
      textMode      = "auto"
      wideLayout    = true
      colorMode     = "background"
      graphMode     = "none"
      justifyMode   = "center"
      showPercentChange = false
    }

    pluginVersion = "11.0.0"

    targets = [
      {
        refId        = "A"
        datasource   = { type = "prometheus", uid = local.mimir_uid }
        expr         = "grafana_datasource_health_check{datasource_type=\"prometheus\", datasource_uid=\"${local.mimir_uid}\"}"
        legendFormat = "Mimir"
        instant      = true
      },
      {
        refId        = "B"
        datasource   = { type = "prometheus", uid = local.mimir_uid }
        expr         = "grafana_datasource_health_check{datasource_type=\"loki\", datasource_uid=\"${local.loki_uid}\"}"
        legendFormat = "Loki"
        instant      = true
      },
      {
        refId        = "C"
        datasource   = { type = "prometheus", uid = local.mimir_uid }
        expr         = "grafana_datasource_health_check{datasource_type=\"tempo\", datasource_uid=\"${local.tempo_uid}\"}"
        legendFormat = "Tempo"
        instant      = true
      },
      {
        refId        = "D"
        datasource   = { type = "prometheus", uid = local.mimir_uid }
        expr         = "grafana_datasource_health_check{datasource_type=\"grafana-pyroscope-datasource\", datasource_uid=\"${local.pyroscope_uid}\"}"
        legendFormat = "Pyroscope"
        instant      = true
      }
    ]

    gridPos = {
      h = 3
      w = 24
      x = 0
      y = 6
    }
  })
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "library_panel_uids" {
  description = "Map of library panel name to its Grafana UID"
  value = {
    "nav-breadcrumb"       = grafana_library_panel.nav_breadcrumb.uid
    "platform-health-stats" = grafana_library_panel.platform_health_stats.uid
    "slo-compliance-table" = grafana_library_panel.slo_compliance_table.uid
    "datasource-status"    = grafana_library_panel.datasource_status.uid
  }
}
