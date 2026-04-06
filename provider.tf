# =============================================================================
# Grafana Enterprise Provider Configuration
# =============================================================================

provider "grafana" {
  url  = var.grafana_url
  auth = var.grafana_auth

  org_id = var.org_id

  # TLS settings - allow self-signed certs in non-prod environments
  tls_key               = var.tls_key
  tls_cert              = var.tls_cert
  insecure_skip_verify  = var.tls_insecure_skip_verify

  # Retry configuration for resilience against transient API failures
  retries              = var.provider_retries
  retry_status_codes   = var.provider_retry_status_codes
  retry_wait           = var.provider_retry_wait
}
