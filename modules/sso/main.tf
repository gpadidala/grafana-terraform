#--------------------------------------------------------------
# Phase 8: SSO Configuration
# Grafana Enterprise Terraform Module - SSO / OAuth2
#
# Configures Single Sign-On via a generic OAuth2 provider
# (or GitHub/GitLab/Azure AD). Maps external groups/roles
# to Grafana roles using JMESPath expressions.
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

variable "sso_provider" {
  description = "SSO provider type (generic_oauth, github, gitlab, azuread, okta, google)"
  type        = string
  default     = "generic_oauth"

  validation {
    condition     = contains(["generic_oauth", "github", "gitlab", "azuread", "okta", "google"], var.sso_provider)
    error_message = "sso_provider must be one of: generic_oauth, github, gitlab, azuread, okta, google."
  }
}

variable "oauth_client_id" {
  description = "OAuth2 client ID issued by the identity provider"
  type        = string

  validation {
    condition     = length(var.oauth_client_id) > 0
    error_message = "oauth_client_id must not be empty."
  }
}

variable "oauth_client_secret" {
  description = "OAuth2 client secret issued by the identity provider"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.oauth_client_secret) > 0
    error_message = "oauth_client_secret must not be empty."
  }
}

variable "oauth_auth_url" {
  description = "OAuth2 authorization endpoint URL"
  type        = string

  validation {
    condition     = can(regex("^https://", var.oauth_auth_url))
    error_message = "oauth_auth_url must be a valid HTTPS URL."
  }
}

variable "oauth_token_url" {
  description = "OAuth2 token endpoint URL"
  type        = string

  validation {
    condition     = can(regex("^https://", var.oauth_token_url))
    error_message = "oauth_token_url must be a valid HTTPS URL."
  }
}

variable "oauth_api_url" {
  description = "OAuth2 user info / API endpoint URL"
  type        = string

  validation {
    condition     = can(regex("^https://", var.oauth_api_url))
    error_message = "oauth_api_url must be a valid HTTPS URL."
  }
}

variable "oauth_scopes" {
  description = "Space-separated OAuth2 scopes to request"
  type        = string
  default     = "openid profile email groups"
}

variable "allowed_domains" {
  description = "List of email domains permitted to sign in via SSO"
  type        = list(string)
  default     = []
}

variable "role_attribute_path" {
  description = "JMESPath expression to extract the Grafana role from the IdP token/response"
  type        = string
  default     = "contains(groups[*], 'grafana-admin') && 'Admin' || contains(groups[*], 'grafana-editor') && 'Editor' || 'Viewer'"
}

variable "allow_sign_up" {
  description = "Whether new users are automatically created on first SSO login"
  type        = bool
  default     = true
}

variable "auto_login" {
  description = "Whether to bypass the Grafana login page and redirect directly to the IdP"
  type        = bool
  default     = false
}

variable "team_ids_attribute_path" {
  description = "JMESPath expression to extract team IDs for auto team assignment"
  type        = string
  default     = ""
}

variable "allowed_organizations" {
  description = "Comma-separated list of allowed GitHub organizations (GitHub provider only)"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------

locals {
  # Build the allowed_domains as a comma-separated string for the provider
  allowed_domains_csv = join(",", var.allowed_domains)

  # Provider display name used in the Grafana login button
  provider_display_names = {
    generic_oauth = "SSO"
    github        = "GitHub"
    gitlab        = "GitLab"
    azuread       = "Azure AD"
    okta          = "Okta"
    google        = "Google"
  }

  display_name = lookup(local.provider_display_names, var.sso_provider, "SSO")
}

# -----------------------------------------------------------------------------
# Resources
# -----------------------------------------------------------------------------

resource "grafana_sso_settings" "this" {
  provider_name = var.sso_provider

  oauth2_settings {
    name            = local.display_name
    client_id       = var.oauth_client_id
    client_secret   = var.oauth_client_secret
    auth_url        = var.oauth_auth_url
    token_url       = var.oauth_token_url
    api_url         = var.oauth_api_url
    scopes          = var.oauth_scopes
    allowed_domains = local.allowed_domains_csv
    auto_login      = var.auto_login
    allow_sign_up   = var.allow_sign_up

    # Role mapping via JMESPath
    role_attribute_path  = var.role_attribute_path
    role_attribute_strict = true

    # Team auto-assignment (optional)
    team_ids_attribute_path = var.team_ids_attribute_path != "" ? var.team_ids_attribute_path : null

    # GitHub-specific: restrict to specific organizations
    allowed_organizations = var.allowed_organizations != "" ? var.allowed_organizations : null
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "sso_provider_name" {
  description = "The configured SSO provider name"
  value       = grafana_sso_settings.this.provider_name
}

output "sso_enabled" {
  description = "Whether SSO has been successfully configured"
  value       = true
}
