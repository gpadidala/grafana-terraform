# =============================================================================
# Production Environment Configuration
# Grafana Enterprise - Terraform Variables
# =============================================================================

environment = "prod"
grafana_url = "https://grafana.company.com"
org_id      = 1

# -----------------------------------------------------------------------------
# Data Source URLs (production endpoints)
# -----------------------------------------------------------------------------
mimir_url        = "https://mimir.company.com/prometheus"
loki_url         = "https://loki.company.com"
tempo_url        = "https://tempo.company.com"
pyroscope_url    = "https://pyroscope.company.com"
alertmanager_url = "https://mimir.company.com/alertmanager"

# -----------------------------------------------------------------------------
# Feature Flags
# -----------------------------------------------------------------------------
enable_alerting = true
enable_rbac     = true
enable_sso      = true
enable_reports  = true

# -----------------------------------------------------------------------------
# SSO Configuration
# -----------------------------------------------------------------------------
sso_provider        = "generic_oauth"
oauth_auth_url      = "https://idp.company.com/authorize"
oauth_token_url     = "https://idp.company.com/token"
oauth_api_url       = "https://idp.company.com/userinfo"
oauth_scopes        = "openid profile email groups"
allowed_domains     = ["company.com"]
role_attribute_path = "contains(groups[*], 'grafana-admin') && 'Admin' || contains(groups[*], 'grafana-editor') && 'Editor' || 'Viewer'"

# -----------------------------------------------------------------------------
# Alert Routing
# -----------------------------------------------------------------------------
alert_email_addresses = ["sre-team@company.com", "platform-alerts@company.com"]

# -----------------------------------------------------------------------------
# Default Tags
# -----------------------------------------------------------------------------
default_tags = {
  environment = "prod"
  managed_by  = "terraform"
  team        = "platform"
}
