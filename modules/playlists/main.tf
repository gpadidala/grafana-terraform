#--------------------------------------------------------------
# Phase 8: Dashboard Playlists
# Grafana Enterprise Terraform Module - Playlists
#
# Creates rotating dashboard playlists for NOC wall displays,
# executive lobby screens, and SRE on-call monitors.
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

variable "grafana_url" {
  description = "Base URL of the Grafana instance (used to construct playlist URLs)"
  type        = string
  default     = "https://grafana.ops.internal"
}

variable "playlist_dashboards" {
  description = "Map of playlist slug to ordered list of dashboard items (title + uid)"
  type = map(list(object({
    title = string
    uid   = string
  })))

  default = {
    "noc-wall-display" = [
      { title = "Executive Command Center", uid = "executive-command-center" },
      { title = "Infrastructure Overview", uid = "infrastructure-overview" },
      { title = "Application Overview", uid = "application-overview" },
      { title = "Network Health", uid = "network-health" },
    ]

    "executive-lobby" = [
      { title = "Home Page", uid = "home-page" },
      { title = "SLO Overview", uid = "slo-overview" },
      { title = "Cloud & Cost Overview", uid = "cloud-cost-overview" },
    ]

    "sre-oncall-display" = [
      { title = "Executive Command Center", uid = "executive-command-center" },
      { title = "SRE On-Call Dashboard", uid = "sre-oncall-dashboard" },
      { title = "Incident Management", uid = "incident-management" },
      { title = "SLO Overview", uid = "slo-overview" },
    ]
  }

  validation {
    condition     = length(var.playlist_dashboards) > 0
    error_message = "At least one playlist must be defined."
  }
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------

locals {
  # Playlist-level configuration (interval per playlist)
  playlist_config = {
    "noc-wall-display" = {
      name     = "NOC Wall Display"
      interval = "1m"
    }
    "executive-lobby" = {
      name     = "Executive Lobby Display"
      interval = "2m"
    }
    "sre-oncall-display" = {
      name     = "SRE On-Call Display"
      interval = "30s"
    }
  }

  # Only create playlists that appear in both the config and the dashboards map
  active_playlists = {
    for slug, config in local.playlist_config : slug => config
    if contains(keys(var.playlist_dashboards), slug)
  }
}

# -----------------------------------------------------------------------------
# Resources
# -----------------------------------------------------------------------------

resource "grafana_playlist" "this" {
  for_each = local.active_playlists

  org_id   = var.org_id
  name     = each.value.name
  interval = each.value.interval

  dynamic "item" {
    for_each = var.playlist_dashboards[each.key]

    content {
      type  = "dashboard_by_uid"
      value = item.value.uid
    }
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "playlist_ids" {
  description = "Map of playlist slug to Grafana playlist ID"
  value = {
    for slug, playlist in grafana_playlist.this : slug => playlist.id
  }
}

output "playlist_urls" {
  description = "Map of playlist slug to full playback URL"
  value = {
    for slug, playlist in grafana_playlist.this : slug => "${var.grafana_url}/playlists/play/${playlist.id}"
  }
}
