# =============================================================================
# Grafana Enterprise Terraform - Version Constraints & Backend
# Manages ALL 30 Grafana provider resources with zero ClickOps
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = ">= 3.0.0"
    }
  }

  # S3 backend with partial configuration.
  # Remaining settings (bucket, region, key, dynamodb_table, etc.)
  # are supplied per-environment via backend config files:
  #   terraform init -backend-config=environments/<env>/backend.hcl
  backend "s3" {}
}
