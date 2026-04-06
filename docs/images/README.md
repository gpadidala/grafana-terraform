# Screenshot Assets

Place the following screenshots in this directory. Recommended size: 1400x800px, PNG format.

## Required Screenshots

| Filename | What to Capture |
|----------|----------------|
| `grafana-terraform-banner.png` | Project banner/logo (1400x400) |
| `resource-coverage-overview.png` | Diagram showing 30/30 resource coverage |
| `screenshot-home-dashboard.png` | Platform Home dashboard in Grafana |
| `screenshot-executive-dashboard.png` | Executive Command Center dashboard |
| `screenshot-terraform-plan.png` | Terminal output of `make plan` |
| `screenshot-make-plan.png` | Terminal showing `make plan ENV=dev` output |
| `screenshot-make-apply.png` | Terminal showing `make apply` success |
| `screenshot-make-help.png` | Terminal showing `make help` output |
| `screenshot-folder-permissions.png` | Grafana folder list with permission icons |
| `screenshot-alerting-routing.png` | Notification policy routing tree in Grafana |
| `screenshot-lgtm-correlation.png` | Metrics -> Traces -> Logs -> Profiles flow |
| `screenshot-cicd-pipeline.png` | GitHub Actions pipeline runs |
| `screenshot-pr-plan-comment.png` | PR comment with Terraform plan diff |

## How to Capture

```bash
# Take screenshots from your running Grafana instance
# Recommended: Use browser at 1400px width, capture full page

# For terminal screenshots, use:
# macOS: Cmd+Shift+4 (area) or Cmd+Shift+5 (screen recording)
# Linux: gnome-screenshot or flameshot
# Or use a tool like carbon.now.sh for styled terminal captures
```
