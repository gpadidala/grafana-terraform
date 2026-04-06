# =============================================================================
# Staging Environment Configuration
# Grafana Enterprise - Terraform Variables
# =============================================================================

environment = "staging"
grafana_url = "https://grafana-staging.company.com"
org_id      = 1

# -----------------------------------------------------------------------------
# Data Source URLs (staging endpoints)
# -----------------------------------------------------------------------------
mimir_url        = "https://mimir-staging.company.com/prometheus"
loki_url         = "https://loki-staging.company.com"
tempo_url        = "https://tempo-staging.company.com"
pyroscope_url    = "https://pyroscope-staging.company.com"
alertmanager_url = "https://mimir-staging.company.com/alertmanager"

# -----------------------------------------------------------------------------
# Feature Flags
# -----------------------------------------------------------------------------
enable_alerting = true
enable_rbac     = true
enable_sso      = false  # Use local auth in staging
enable_reports  = false  # No reports in staging

# -----------------------------------------------------------------------------
# SSO Configuration (disabled in staging - values kept for reference)
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
alert_email_addresses = ["sre-staging@company.com"]

# -----------------------------------------------------------------------------
# Default Tags
# -----------------------------------------------------------------------------
default_tags = {
  environment = "staging"
  managed_by  = "terraform"
  team        = "platform"
}
