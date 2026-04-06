# =============================================================================
# Grafana Enterprise Terraform - Input Variables
# Covers ALL 30 Grafana Terraform provider resources
# =============================================================================

# -----------------------------------------------------------------------------
# Core Connection
# -----------------------------------------------------------------------------

variable "grafana_url" {
  description = "The root URL of the Grafana instance (e.g. https://grafana.example.com)"
  type        = string

  validation {
    condition     = can(regex("^https?://", var.grafana_url))
    error_message = "grafana_url must start with http:// or https://."
  }
}

variable "grafana_auth" {
  description = "API token or basic auth credentials for the Grafana provider"
  type        = string
  sensitive   = true
}

variable "org_id" {
  description = "Grafana organization ID to operate within"
  type        = number
  default     = 1
}

# -----------------------------------------------------------------------------
# Environment & Metadata
# -----------------------------------------------------------------------------

variable "environment" {
  description = "Deployment environment"
  type        = string

  validation {
    condition     = contains(["prod", "staging", "dev"], var.environment)
    error_message = "environment must be one of: prod, staging, dev."
  }
}

variable "platform_version" {
  description = "Semantic version of the AIOps platform release (e.g. 2.4.0)"
  type        = string
  default     = "1.0.0"

  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+$", var.platform_version))
    error_message = "platform_version must follow semver (e.g. 1.0.0)."
  }
}

# -----------------------------------------------------------------------------
# Provider TLS & Retry Settings
# -----------------------------------------------------------------------------

variable "tls_key" {
  description = "Path to a PEM-encoded TLS client key for mTLS to Grafana"
  type        = string
  default     = ""
  sensitive   = true
}

variable "tls_cert" {
  description = "Path to a PEM-encoded TLS client certificate for mTLS to Grafana"
  type        = string
  default     = ""
}

variable "tls_insecure_skip_verify" {
  description = "Skip TLS certificate verification (non-prod only)"
  type        = bool
  default     = false
}

variable "provider_retries" {
  description = "Number of retries for failed Grafana API calls"
  type        = number
  default     = 3
}

variable "provider_retry_status_codes" {
  description = "HTTP status codes that should trigger a retry"
  type        = list(number)
  default     = [429, 500, 502, 503]
}

variable "provider_retry_wait" {
  description = "Seconds to wait between retries"
  type        = number
  default     = 10
}

# -----------------------------------------------------------------------------
# Feature Flags
# -----------------------------------------------------------------------------

variable "enable_alerting" {
  description = "Enable Grafana Alerting resources (rules, contact points, policies)"
  type        = bool
  default     = true
}

variable "enable_rbac" {
  description = "Enable Role-Based Access Control resources"
  type        = bool
  default     = true
}

variable "enable_sso" {
  description = "Enable SSO/OAuth configuration resources"
  type        = bool
  default     = true
}

variable "enable_reports" {
  description = "Enable Grafana Enterprise reporting resources"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Data Source URLs
# -----------------------------------------------------------------------------

variable "datasource_urls" {
  description = "Map of data source endpoint URLs for the LGTM+ stack"
  type = object({
    mimir_url        = string
    loki_url         = string
    tempo_url        = string
    pyroscope_url    = string
    alertmanager_url = string
  })

  default = {
    mimir_url        = "http://mimir.monitoring.svc.cluster.local:8080/prometheus"
    loki_url         = "http://loki.monitoring.svc.cluster.local:3100"
    tempo_url        = "http://tempo.monitoring.svc.cluster.local:3200"
    pyroscope_url    = "http://pyroscope.monitoring.svc.cluster.local:4040"
    alertmanager_url = "http://alertmanager.monitoring.svc.cluster.local:9093"
  }
}

# -----------------------------------------------------------------------------
# Teams
# -----------------------------------------------------------------------------

variable "teams" {
  description = "List of Grafana teams with membership and SSO mapping"
  type = list(object({
    name         = string
    display_name = string
    members      = list(string)
    sso_group    = string
  }))

  default = [
    {
      name         = "platform-admin"
      display_name = "Platform Administration"
      members      = []
      sso_group    = "grafana-platform-admin"
    },
    {
      name         = "sre"
      display_name = "Site Reliability Engineering"
      members      = []
      sso_group    = "grafana-sre"
    },
    {
      name         = "devops"
      display_name = "DevOps Engineering"
      members      = []
      sso_group    = "grafana-devops"
    },
    {
      name         = "executive-leadership"
      display_name = "Executive Leadership"
      members      = []
      sso_group    = "grafana-executive-leadership"
    },
    {
      name         = "app-engineering"
      display_name = "Application Engineering"
      members      = []
      sso_group    = "grafana-app-engineering"
    },
    {
      name         = "network-engineering"
      display_name = "Network Engineering"
      members      = []
      sso_group    = "grafana-network-engineering"
    },
    {
      name         = "security-ops"
      display_name = "Security Operations"
      members      = []
      sso_group    = "grafana-security-ops"
    },
    {
      name         = "data-platform"
      display_name = "Data Platform Engineering"
      members      = []
      sso_group    = "grafana-data-platform"
    },
    {
      name         = "cloud-infra"
      display_name = "Cloud Infrastructure"
      members      = []
      sso_group    = "grafana-cloud-infra"
    }
  ]
}

# -----------------------------------------------------------------------------
# Folders
# -----------------------------------------------------------------------------

variable "folders" {
  description = "Grafana folder hierarchy for organizing dashboards and alerts"
  type = list(object({
    name   = string
    title  = string
    parent = optional(string, "")
  }))

  default = [
    { name = "platform-overview", title = "Platform Overview", parent = "" },
    { name = "sre", title = "SRE", parent = "" },
    { name = "sre-slos", title = "SLOs", parent = "sre" },
    { name = "sre-incidents", title = "Incidents", parent = "sre" },
    { name = "infrastructure", title = "Infrastructure", parent = "" },
    { name = "infrastructure-compute", title = "Compute", parent = "infrastructure" },
    { name = "infrastructure-network", title = "Network", parent = "infrastructure" },
    { name = "applications", title = "Applications", parent = "" },
    { name = "security", title = "Security", parent = "" },
    { name = "executive", title = "Executive Dashboards", parent = "" },
    { name = "alerting", title = "Alerting", parent = "" },
    { name = "alerting-rules", title = "Alert Rules", parent = "alerting" },
  ]
}

# -----------------------------------------------------------------------------
# Alerting Configuration
# -----------------------------------------------------------------------------

variable "slack_webhook_url" {
  description = "Slack incoming webhook URL for alert notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "pagerduty_integration_key" {
  description = "PagerDuty Events API v2 integration key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "alert_email_addresses" {
  description = "List of email addresses for alert notifications"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# SSO / OAuth Configuration
# -----------------------------------------------------------------------------

variable "oauth_client_id" {
  description = "OAuth2 client ID for Grafana SSO integration"
  type        = string
  default     = ""
}

variable "oauth_client_secret" {
  description = "OAuth2 client secret for Grafana SSO integration"
  type        = string
  default     = ""
  sensitive   = true
}

variable "oauth_auth_url" {
  description = "OAuth2 authorization endpoint URL"
  type        = string
  default     = ""
}

variable "oauth_token_url" {
  description = "OAuth2 token endpoint URL"
  type        = string
  default     = ""
}

variable "allowed_domains" {
  description = "List of email domains allowed for SSO login"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Reporting
# -----------------------------------------------------------------------------

variable "report_recipients" {
  description = "Map of report name to list of recipient email addresses"
  type        = map(list(string))
  default     = {}
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "default_tags" {
  description = "Default tags applied to all taggable Grafana resources"
  type        = map(string)
  default = {
    managed_by = "terraform"
    project    = "aiops-platform"
    owner      = "platform-engineering"
  }
}

# -----------------------------------------------------------------------------
# Service Account Configuration
# -----------------------------------------------------------------------------

variable "service_accounts" {
  description = "Service accounts to create for CI/CD and automation"
  type = list(object({
    name        = string
    role        = string
    is_disabled = optional(bool, false)
  }))

  default = [
    { name = "terraform-ci", role = "Admin", is_disabled = false },
    { name = "dashboard-deployer", role = "Editor", is_disabled = false },
    { name = "alerting-provisioner", role = "Editor", is_disabled = false },
    { name = "readonly-exporter", role = "Viewer", is_disabled = false },
  ]
}

# -----------------------------------------------------------------------------
# Users (managed externally, referenced here for team membership)
# -----------------------------------------------------------------------------

variable "users" {
  description = "Map of user login to user config for Grafana-managed users"
  type = list(object({
    name     = string
    email    = string
    login    = string
    password = optional(string, "")
    role     = optional(string, "Viewer")
  }))

  default  = []
  sensitive = true
}

# -----------------------------------------------------------------------------
# Dashboard Configuration
# -----------------------------------------------------------------------------

variable "dashboard_dir" {
  description = "Path to directory containing dashboard JSON files"
  type        = string
  default     = "dashboards"
}

# -----------------------------------------------------------------------------
# Library Panel Configuration
# -----------------------------------------------------------------------------

variable "library_panel_dir" {
  description = "Path to directory containing library panel JSON definitions"
  type        = string
  default     = "library-panels"
}

# -----------------------------------------------------------------------------
# Playlist Configuration
# -----------------------------------------------------------------------------

variable "playlists" {
  description = "Playlist definitions for rotating dashboard views"
  type = list(object({
    name     = string
    interval = string
    items = list(object({
      type  = string
      value = string
    }))
  }))

  default = []
}

# -----------------------------------------------------------------------------
# Preferences
# -----------------------------------------------------------------------------

variable "org_preferences" {
  description = "Organization-level preference overrides"
  type = object({
    theme            = optional(string, "dark")
    home_dashboard   = optional(string, "")
    timezone         = optional(string, "utc")
    week_start       = optional(string, "monday")
  })

  default = {
    theme          = "dark"
    home_dashboard = ""
    timezone       = "utc"
    week_start     = "monday"
  }
}
