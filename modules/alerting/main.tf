#--------------------------------------------------------------
# Phase 6: Alerting & Notification Routing
# Grafana Enterprise Terraform Module - Alerting
#
# Provisions contact points (Slack, PagerDuty, Email),
# severity-based notification policies, message templates,
# mute timings, and Prometheus-style alert rule groups
# targeting Mimir as the evaluation datasource.
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
  description = "Grafana organization ID"
  type        = string
}

variable "folder_uid" {
  description = "UID of the Grafana folder used for alerting rule groups"
  type        = string

  validation {
    condition     = length(var.folder_uid) > 0
    error_message = "folder_uid must not be empty."
  }
}

variable "datasource_uid" {
  description = "UID of the Mimir datasource used for alert rule queries"
  type        = string

  validation {
    condition     = length(var.datasource_uid) > 0
    error_message = "datasource_uid must not be empty."
  }
}

variable "slack_webhook_url" {
  description = "Slack incoming webhook URL for the platform alerts channel"
  type        = string
  sensitive   = true
}

variable "pagerduty_integration_key" {
  description = "PagerDuty Events API v2 integration key for critical alerts"
  type        = string
  sensitive   = true
}

variable "alert_email_addresses" {
  description = "List of email addresses that receive alert notifications"
  type        = list(string)

  validation {
    condition     = length(var.alert_email_addresses) > 0
    error_message = "alert_email_addresses must contain at least one address."
  }
}

# -----------------------------------------------------------------------------
# Message Templates
# -----------------------------------------------------------------------------

resource "grafana_message_template" "slack_alert_template" {
  org_id = var.org_id
  name   = "slack_alert_template"

  template = <<-EOT
{{ define "slack_alert_template" }}
{{ range .Alerts }}
*Alert:* {{ .Labels.alertname }}
*Status:* {{ .Status | toUpper }}
*Severity:* {{ .Labels.severity }}
*Namespace:* {{ .Labels.namespace | default "n/a" }}
*Cluster:* {{ .Labels.cluster | default "n/a" }}
*Service:* {{ .Labels.service | default "n/a" }}

{{ if .Annotations.summary }}*Summary:* {{ .Annotations.summary }}{{ end }}
{{ if .Annotations.description }}*Description:* {{ .Annotations.description }}{{ end }}
{{ if .Annotations.runbook_url }}:book: <{{ .Annotations.runbook_url }}|Runbook>{{ end }}
{{ if .DashboardURL }}:chart_with_upwards_trend: <{{ .DashboardURL }}|Dashboard>{{ end }}
{{ if .SilenceURL }}:no_bell: <{{ .SilenceURL }}|Silence>{{ end }}
---
{{ end }}
{{ end }}
EOT
}

resource "grafana_message_template" "email_alert_template" {
  org_id = var.org_id
  name   = "email_alert_template"

  template = <<-EOT
{{ define "email_alert_template" }}
<!DOCTYPE html>
<html>
<head>
<style>
  body { font-family: Arial, sans-serif; margin: 20px; color: #333; }
  h2 { color: #b71c1c; }
  table { border-collapse: collapse; width: 100%; margin-top: 12px; }
  th, td { border: 1px solid #ddd; padding: 8px 12px; text-align: left; }
  th { background-color: #f5f5f5; font-weight: 600; }
  tr:nth-child(even) { background-color: #fafafa; }
  .firing { color: #b71c1c; font-weight: bold; }
  .resolved { color: #2e7d32; font-weight: bold; }
  a { color: #1565c0; }
</style>
</head>
<body>
<h2>Grafana Alert Notification</h2>
<p>There are <strong>{{ len .Alerts.Firing }}</strong> firing and <strong>{{ len .Alerts.Resolved }}</strong> resolved alert(s).</p>
<table>
  <tr>
    <th>Alert</th>
    <th>Status</th>
    <th>Severity</th>
    <th>Value</th>
    <th>Labels</th>
    <th>Summary</th>
    <th>Links</th>
  </tr>
  {{ range .Alerts }}
  <tr>
    <td>{{ .Labels.alertname }}</td>
    <td class="{{ .Status }}">{{ .Status | toUpper }}</td>
    <td>{{ .Labels.severity }}</td>
    <td>{{ .ValueString | default "n/a" }}</td>
    <td>namespace={{ .Labels.namespace | default "n/a" }}, cluster={{ .Labels.cluster | default "n/a" }}, service={{ .Labels.service | default "n/a" }}</td>
    <td>{{ .Annotations.summary | default "" }}</td>
    <td>
      {{ if .DashboardURL }}<a href="{{ .DashboardURL }}">Dashboard</a> {{ end }}
      {{ if .SilenceURL }}<a href="{{ .SilenceURL }}">Silence</a>{{ end }}
    </td>
  </tr>
  {{ end }}
</table>
</body>
</html>
{{ end }}
EOT
}

# -----------------------------------------------------------------------------
# Contact Points
# -----------------------------------------------------------------------------

resource "grafana_contact_point" "slack" {
  org_id = var.org_id
  name   = "slack-platform-alerts"

  slack {
    endpoint_url    = var.slack_webhook_url
    title           = "{{ template \"slack_alert_template\" . }}"
    text            = <<-EOT
*[{{ .Status | toUpper }}] {{ .CommonLabels.alertname }}*
Severity: {{ .CommonLabels.severity }}
Namespace: {{ .CommonLabels.namespace }}
Cluster: {{ .CommonLabels.cluster }}
{{ range .Alerts }}
  - {{ .Annotations.summary }}
{{ end }}
EOT
    mention_channel = "here"
  }
}

resource "grafana_contact_point" "pagerduty" {
  org_id = var.org_id
  name   = "pagerduty-critical"

  pagerduty {
    integration_key = var.pagerduty_integration_key
    severity        = "{{ if eq .CommonLabels.severity \"critical\" }}critical{{ else }}warning{{ end }}"
    class           = "grafana-alerting"
    component       = "{{ .CommonLabels.namespace }}/{{ .CommonLabels.service }}"
    summary         = "{{ .CommonLabels.alertname }}: {{ .CommonAnnotations.summary }}"
  }
}

resource "grafana_contact_point" "email" {
  org_id = var.org_id
  name   = "email-alerts"

  email {
    addresses    = var.alert_email_addresses
    single_email = false
    message      = "{{ template \"email_alert_template\" . }}"
    subject      = "[{{ .Status | toUpper }}] {{ .CommonLabels.alertname }} - {{ .CommonLabels.severity }}"
  }
}

# -----------------------------------------------------------------------------
# Mute Timings (Maintenance Windows)
# -----------------------------------------------------------------------------

resource "grafana_mute_timing" "deploy_freeze" {
  org_id = var.org_id
  name   = "deploy-freeze-window"

  intervals {
    weekdays = ["saturday", "sunday"]
    times {
      start = "00:00"
      end   = "23:59"
    }
  }
}

resource "grafana_mute_timing" "maintenance" {
  org_id = var.org_id
  name   = "maintenance-window"

  intervals {
    weekdays = ["wednesday"]
    times {
      start = "02:00"
      end   = "04:00"
    }
  }
}

# -----------------------------------------------------------------------------
# Notification Policy - Severity-Based Routing Tree
# -----------------------------------------------------------------------------

resource "grafana_notification_policy" "this" {
  org_id = var.org_id

  group_by        = ["alertname", "namespace", "cluster"]
  contact_point   = grafana_contact_point.slack.name
  group_wait      = "30s"
  group_interval  = "5m"
  repeat_interval = "4h"

  # Critical severity -> PagerDuty + Slack
  policy {
    contact_point = grafana_contact_point.pagerduty.name
    continue      = true
    group_by      = ["alertname", "namespace", "cluster"]

    matcher {
      label = "severity"
      match = "="
      value = "critical"
    }

    # Nested: also send critical to Slack
    policy {
      contact_point = grafana_contact_point.slack.name
      group_by      = ["alertname", "namespace", "cluster"]

      matcher {
        label = "severity"
        match = "="
        value = "critical"
      }
    }
  }

  # Warning severity -> Slack only
  policy {
    contact_point = grafana_contact_point.slack.name
    group_by      = ["alertname", "namespace", "cluster"]

    matcher {
      label = "severity"
      match = "="
      value = "warning"
    }
  }

  # Info severity -> Email only
  policy {
    contact_point = grafana_contact_point.email.name
    group_by      = ["alertname", "namespace", "cluster"]

    matcher {
      label = "severity"
      match = "="
      value = "info"
    }
  }

  # Team SRE -> Slack #sre-alerts
  policy {
    contact_point = grafana_contact_point.slack.name
    group_by      = ["alertname", "namespace", "cluster"]

    matcher {
      label = "team"
      match = "="
      value = "sre"
    }
  }
}

# -----------------------------------------------------------------------------
# Alert Rule Groups
# -----------------------------------------------------------------------------

resource "grafana_rule_group" "platform_slo_alerts" {
  org_id           = var.org_id
  name             = "platform-slo-alerts"
  folder_uid       = var.folder_uid
  interval_seconds = 60

  # ---- Rule 1: High Error Rate (>1% for 5m) - critical ----
  rule {
    name      = "High Error Rate"
    condition = "C"
    for       = "5m"

    labels = {
      severity = "critical"
    }

    annotations = {
      summary       = "HTTP error rate exceeds 1% SLO threshold"
      description   = "The ratio of 5xx responses to total HTTP requests has exceeded 1% for the past 5 minutes in namespace {{ $labels.namespace }}, cluster {{ $labels.cluster }}."
      runbook_url   = "https://runbooks.example.com/platform/high-error-rate"
      dashboard_url = "https://grafana.example.com/d/slo-overview"
    }

    # Query A: 5xx request rate
    data {
      ref_id = "A"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = var.datasource_uid

      model = jsonencode({
        refId         = "A"
        expr          = "sum(rate(http_requests_total{status=~\"5..\"}[5m]))"
        instant       = true
        intervalMs    = 1000
        maxDataPoints = 43200
      })
    }

    # Query B: total request rate
    data {
      ref_id = "B"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = var.datasource_uid

      model = jsonencode({
        refId         = "B"
        expr          = "sum(rate(http_requests_total[5m]))"
        instant       = true
        intervalMs    = 1000
        maxDataPoints = 43200
      })
    }

    # Condition C: error ratio > 0.01
    data {
      ref_id = "C"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = "__expr__"

      model = jsonencode({
        refId      = "C"
        type       = "math"
        expression = "$A / $B > 0.01"
      })
    }
  }

  # ---- Rule 2: SLO Burn Rate (>2x for 1h) - warning ----
  rule {
    name      = "SLO Burn Rate Too High"
    condition = "B"
    for       = "1h"

    labels = {
      severity = "warning"
    }

    annotations = {
      summary       = "SLO burn rate exceeds 2x threshold"
      description   = "The 1-hour SLO burn rate is above 2x, indicating the error budget is being consumed too quickly for service {{ $labels.service }}."
      runbook_url   = "https://runbooks.example.com/platform/slo-burn-rate"
      dashboard_url = "https://grafana.example.com/d/slo-overview"
    }

    # Query A: burn rate metric
    data {
      ref_id = "A"

      relative_time_range {
        from = 3600
        to   = 0
      }

      datasource_uid = var.datasource_uid

      model = jsonencode({
        refId         = "A"
        expr          = "slo:burn_rate:1h"
        instant       = true
        intervalMs    = 1000
        maxDataPoints = 43200
      })
    }

    # Condition B: burn rate > 2
    data {
      ref_id = "B"

      relative_time_range {
        from = 3600
        to   = 0
      }

      datasource_uid = "__expr__"

      model = jsonencode({
        refId      = "B"
        type       = "threshold"
        expression = "A"
        conditions = [
          {
            evaluator = {
              type   = "gt"
              params = [2]
            }
            operator = {
              type = "and"
            }
            reducer = {
              type = "last"
            }
          }
        ]
      })
    }
  }

  # ---- Rule 3: High P99 Latency (>2s for 10m) - warning ----
  rule {
    name      = "High P99 Latency"
    condition = "B"
    for       = "10m"

    labels = {
      severity = "warning"
    }

    annotations = {
      summary       = "P99 latency exceeds 2 second threshold"
      description   = "The 99th percentile HTTP request latency has exceeded 2 seconds for the past 10 minutes for service {{ $labels.service }}."
      runbook_url   = "https://runbooks.example.com/platform/high-latency"
      dashboard_url = "https://grafana.example.com/d/slo-overview"
    }

    # Query A: P99 histogram quantile
    data {
      ref_id = "A"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = var.datasource_uid

      model = jsonencode({
        refId         = "A"
        expr          = "histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service))"
        instant       = true
        intervalMs    = 1000
        maxDataPoints = 43200
      })
    }

    # Condition B: latency > 2s
    data {
      ref_id = "B"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = "__expr__"

      model = jsonencode({
        refId      = "B"
        type       = "threshold"
        expression = "A"
        conditions = [
          {
            evaluator = {
              type   = "gt"
              params = [2]
            }
            operator = {
              type = "and"
            }
            reducer = {
              type = "last"
            }
          }
        ]
      })
    }
  }
}

resource "grafana_rule_group" "infrastructure_alerts" {
  org_id           = var.org_id
  name             = "infrastructure-alerts"
  folder_uid       = var.folder_uid
  interval_seconds = 60

  # ---- Rule 1: Node Not Ready (for 5m) - critical ----
  rule {
    name      = "Node Not Ready"
    condition = "B"
    for       = "5m"

    labels = {
      severity = "critical"
    }

    annotations = {
      summary       = "Kubernetes node is not in Ready state"
      description   = "Node {{ $labels.node }} in cluster {{ $labels.cluster }} has been in a non-Ready state for more than 5 minutes."
      runbook_url   = "https://runbooks.example.com/infra/node-not-ready"
      dashboard_url = "https://grafana.example.com/d/infra-overview"
    }

    # Query A: node ready condition
    data {
      ref_id = "A"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = var.datasource_uid

      model = jsonencode({
        refId         = "A"
        expr          = "kube_node_status_condition{condition=\"Ready\",status=\"true\"} == 0"
        instant       = true
        intervalMs    = 1000
        maxDataPoints = 43200
      })
    }

    # Condition B: threshold (any result means firing)
    data {
      ref_id = "B"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = "__expr__"

      model = jsonencode({
        refId      = "B"
        type       = "threshold"
        expression = "A"
        conditions = [
          {
            evaluator = {
              type   = "gt"
              params = [0]
            }
            operator = {
              type = "and"
            }
            reducer = {
              type = "last"
            }
          }
        ]
      })
    }
  }

  # ---- Rule 2: Pod CrashLooping (>3 restarts in 10m) - warning ----
  rule {
    name      = "Pod CrashLooping"
    condition = "B"
    for       = "0s"

    labels = {
      severity = "warning"
    }

    annotations = {
      summary       = "Pod is crash-looping with frequent restarts"
      description   = "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} has restarted more than 3 times in the last 10 minutes."
      runbook_url   = "https://runbooks.example.com/infra/pod-crashlooping"
      dashboard_url = "https://grafana.example.com/d/infra-overview"
    }

    # Query A: restart count increase over 10m
    data {
      ref_id = "A"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = var.datasource_uid

      model = jsonencode({
        refId         = "A"
        expr          = "increase(kube_pod_container_status_restarts_total[10m])"
        instant       = true
        intervalMs    = 1000
        maxDataPoints = 43200
      })
    }

    # Condition B: restarts > 3
    data {
      ref_id = "B"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = "__expr__"

      model = jsonencode({
        refId      = "B"
        type       = "threshold"
        expression = "A"
        conditions = [
          {
            evaluator = {
              type   = "gt"
              params = [3]
            }
            operator = {
              type = "and"
            }
            reducer = {
              type = "last"
            }
          }
        ]
      })
    }
  }

  # ---- Rule 3: Disk Space Critical (<10% free) - critical ----
  rule {
    name      = "Disk Space Critical"
    condition = "B"
    for       = "5m"

    labels = {
      severity = "critical"
    }

    annotations = {
      summary       = "Disk space is critically low (less than 10% free)"
      description   = "Filesystem {{ $labels.mountpoint }} on node {{ $labels.instance }} has less than 10% free disk space remaining."
      runbook_url   = "https://runbooks.example.com/infra/disk-space-critical"
      dashboard_url = "https://grafana.example.com/d/infra-overview"
    }

    # Query A: filesystem free ratio
    data {
      ref_id = "A"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = var.datasource_uid

      model = jsonencode({
        refId         = "A"
        expr          = "(node_filesystem_avail_bytes / node_filesystem_size_bytes)"
        instant       = true
        intervalMs    = 1000
        maxDataPoints = 43200
      })
    }

    # Condition B: free ratio < 0.10
    data {
      ref_id = "B"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = "__expr__"

      model = jsonencode({
        refId      = "B"
        type       = "threshold"
        expression = "A"
        conditions = [
          {
            evaluator = {
              type   = "lt"
              params = [0.10]
            }
            operator = {
              type = "and"
            }
            reducer = {
              type = "last"
            }
          }
        ]
      })
    }
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "contact_point_names" {
  description = "List of all provisioned contact point names"
  value = [
    grafana_contact_point.slack.name,
    grafana_contact_point.pagerduty.name,
    grafana_contact_point.email.name,
  ]
}

output "notification_policy_id" {
  description = "ID of the root notification policy"
  value       = grafana_notification_policy.this.id
}

output "rule_group_names" {
  description = "List of all provisioned alert rule group names"
  value = [
    grafana_rule_group.platform_slo_alerts.name,
    grafana_rule_group.infrastructure_alerts.name,
  ]
}

output "mute_timing_names" {
  description = "List of all provisioned mute timing names"
  value = [
    grafana_mute_timing.deploy_freeze.name,
    grafana_mute_timing.maintenance.name,
  ]
}
