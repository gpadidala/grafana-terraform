# =============================================================================
# Dev Environment Configuration
# Grafana Enterprise - Terraform Variables
# =============================================================================

environment = "dev"
grafana_url = "http://localhost:3000"
org_id      = 1

# -----------------------------------------------------------------------------
# Data Source URLs (local development endpoints)
# -----------------------------------------------------------------------------
mimir_url        = "http://localhost:9009/prometheus"
loki_url         = "http://localhost:3100"
tempo_url        = "http://localhost:3200"
pyroscope_url    = "http://localhost:4040"
alertmanager_url = "http://localhost:9009/alertmanager"

# -----------------------------------------------------------------------------
# Feature Flags
# -----------------------------------------------------------------------------
enable_alerting = true
enable_rbac     = false  # No RBAC in dev
enable_sso      = false  # No SSO in dev
enable_reports  = false  # No reports in dev

# -----------------------------------------------------------------------------
# SSO Configuration (disabled in dev)
# -----------------------------------------------------------------------------
sso_provider        = "generic_oauth"
oauth_auth_url      = ""
oauth_token_url     = ""
oauth_api_url       = ""
oauth_scopes        = ""
allowed_domains     = []
role_attribute_path = ""

# -----------------------------------------------------------------------------
# Alert Routing
# -----------------------------------------------------------------------------
alert_email_addresses = ["dev-alerts@company.com"]

# -----------------------------------------------------------------------------
# Default Tags
# -----------------------------------------------------------------------------
default_tags = {
  environment = "dev"
  managed_by  = "terraform"
  team        = "platform"
}
