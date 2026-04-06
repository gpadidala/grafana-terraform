# Video Assets

Place short walkthrough videos in this directory. Recommended: MP4 format, 720p or 1080p.

## Required Videos

| Filename | Content | Duration |
|----------|---------|----------|
| `01-quickstart-setup.mp4` | Clone repo, configure env, init, plan, apply | ~5 min |
| `02-plan-and-apply.mp4` | Running `make plan` and `make apply` with different environments | ~3 min |
| `03-dashboard-export.mp4` | `make export` + `make templatize` workflow | ~4 min |
| `04-cicd-pipeline.mp4` | Create PR, see validation, merge, auto-deploy staging, manual prod | ~6 min |
| `05-lgtm-correlation.mp4` | Click metric spike -> trace -> logs -> profile in Grafana | ~3 min |
| `06-alerting-setup.mp4` | Show contact points, routing tree, alert firing -> notification | ~4 min |

## Recording Tips

- Use a clean terminal with large font (14-16pt)
- Record at 1920x1080 or 1280x720
- Tools: OBS Studio, QuickTime (macOS), Loom, or asciinema (terminal only)
- Keep videos under 6 minutes each
- Add captions or annotations for key steps

## Video Thumbnail Images

Place corresponding thumbnail images in `../images/`:
- `video-thumb-quickstart.png` (320x180)
- `video-thumb-plan-apply.png` (320x180)
- `video-thumb-dashboard-export.png` (320x180)
- `video-thumb-cicd.png` (320x180)
- `video-thumb-lgtm-correlation.png` (320x180)
- `video-thumb-alerting.png` (320x180)

## Alternative: GitHub Releases

For large video files, consider:
1. Upload to GitHub Releases as attachments
2. Host on YouTube/Vimeo and link in README
3. Use asciinema.org for terminal recordings (embeddable)
