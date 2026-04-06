#!/usr/bin/env bash
#
# version-bump.sh
# Bumps the semantic version stored in the VERSION file.
#
# Usage:
#   ./scripts/version-bump.sh patch          # 1.0.0 -> 1.0.1
#   ./scripts/version-bump.sh minor          # 1.0.0 -> 1.1.0
#   ./scripts/version-bump.sh major          # 1.0.0 -> 2.0.0
#   ./scripts/version-bump.sh patch --tag    # Also create a git tag
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSION_FILE="${PROJECT_ROOT}/VERSION"

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
TYPE="${1:-}"
CREATE_TAG=false

for arg in "$@"; do
  case "${arg}" in
    --tag) CREATE_TAG=true ;;
  esac
done

if [[ -z "${TYPE}" ]] || [[ ! "${TYPE}" =~ ^(major|minor|patch)$ ]]; then
  echo "Usage: $(basename "$0") <major|minor|patch> [--tag]" >&2
  echo "" >&2
  echo "Arguments:" >&2
  echo "  major    Bump major version (X.0.0)" >&2
  echo "  minor    Bump minor version (x.Y.0)" >&2
  echo "  patch    Bump patch version (x.y.Z)" >&2
  echo "" >&2
  echo "Options:" >&2
  echo "  --tag    Create a git tag for the new version" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Read current version
# ---------------------------------------------------------------------------
if [[ -f "${VERSION_FILE}" ]]; then
  CURRENT_VERSION=$(cat "${VERSION_FILE}" | tr -d '[:space:]')
else
  CURRENT_VERSION="0.0.0"
  echo "[INFO] VERSION file not found. Defaulting to ${CURRENT_VERSION}."
fi

# Validate semver format
if [[ ! "${CURRENT_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: Current version '${CURRENT_VERSION}' is not a valid semver (X.Y.Z)." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Parse version components
# ---------------------------------------------------------------------------
IFS='.' read -r MAJOR MINOR PATCH <<< "${CURRENT_VERSION}"

# ---------------------------------------------------------------------------
# Bump
# ---------------------------------------------------------------------------
case "${TYPE}" in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

# ---------------------------------------------------------------------------
# Write new version
# ---------------------------------------------------------------------------
echo "${NEW_VERSION}" > "${VERSION_FILE}"

echo "=============================================="
echo " Version Bump"
echo "=============================================="
echo "  Type:         ${TYPE}"
echo "  Old version:  ${CURRENT_VERSION}"
echo "  New version:  ${NEW_VERSION}"
echo "  File:         ${VERSION_FILE}"
echo "=============================================="

# ---------------------------------------------------------------------------
# Optional: create git tag
# ---------------------------------------------------------------------------
if ${CREATE_TAG}; then
  TAG_NAME="v${NEW_VERSION}"

  if ! command -v git &>/dev/null; then
    echo "" >&2
    echo "ERROR: git is not installed. Cannot create tag." >&2
    exit 1
  fi

  # Check if we are in a git repo
  if ! git -C "${PROJECT_ROOT}" rev-parse --is-inside-work-tree &>/dev/null; then
    echo "" >&2
    echo "ERROR: ${PROJECT_ROOT} is not inside a git repository. Cannot create tag." >&2
    exit 1
  fi

  # Check if tag already exists
  if git -C "${PROJECT_ROOT}" rev-parse "${TAG_NAME}" &>/dev/null; then
    echo "" >&2
    echo "ERROR: Tag '${TAG_NAME}' already exists." >&2
    exit 1
  fi

  git -C "${PROJECT_ROOT}" tag -a "${TAG_NAME}" -m "Release ${NEW_VERSION}"
  echo ""
  echo "  Git tag created: ${TAG_NAME}"
  echo "  Run 'git push origin ${TAG_NAME}' to push the tag."
fi
