#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Propagate the version from VERSION file to all version-bearing files.
#
# Usage:
#   scripts/version-bump.sh              # propagate current VERSION to all files
#   scripts/version-bump.sh 5.7.0        # set VERSION to 5.7.0, then propagate
#   scripts/version-bump.sh --check      # verify all files are in sync (exit 1 if not)

set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

VERSION_FILE="${PROJECT_ROOT}/VERSION"

# Platform-portable sed -i
sed_inplace () {
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

# Read current version from VERSION file
read_version () {
  if [[ ! -f "${VERSION_FILE}" ]]; then
    echo "ERROR: VERSION file not found at ${VERSION_FILE}" >&2
    return 1
  fi
  tr -d '[:space:]' < "${VERSION_FILE}"
}

# Validate version format
validate_version () {
  if ! [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: Invalid version format '$1'. Expected X.Y.Z" >&2
    return 1
  fi
}

# Extract version from a file using a regex pattern
extract_version () {
  local file="$1"
  local pattern="$2"

  grep -oE "${pattern}" "${file}" | head -1
}

# Update version in all files
propagate_version () {
  local ver="$1"
  local updated=0

  # action.yml - Docker image tag
  local action_file="${PROJECT_ROOT}/action.yml"
  if [[ -f "${action_file}" ]]; then
    sed_inplace "s|differential-shellcheck:v[0-9]*\.[0-9]*\.[0-9]*|differential-shellcheck:v${ver}|" "${action_file}"
    echo "  Updated action.yml -> v${ver}"
    ((updated++))
  fi

  # differential-shellcheck.spec - Version field
  local spec_file="${PROJECT_ROOT}/differential-shellcheck.spec"
  if [[ -f "${spec_file}" ]]; then
    sed_inplace "s/^Version:.*$/Version:        ${ver}/" "${spec_file}"
    echo "  Updated differential-shellcheck.spec -> ${ver}"
    ((updated++))
  fi

  # README.md - pre-commit rev
  local readme_file="${PROJECT_ROOT}/README.md"
  if [[ -f "${readme_file}" ]]; then
    sed_inplace "s|rev: v[0-9]*\.[0-9]*\.[0-9]*|rev: v${ver}|" "${readme_file}"
    echo "  Updated README.md -> v${ver}"
    ((updated++))
  fi

  # docs/differential-shellcheck.1.md - pre-commit rev
  local manpage_file="${PROJECT_ROOT}/docs/differential-shellcheck.1.md"
  if [[ -f "${manpage_file}" ]]; then
    sed_inplace "s|rev: v[0-9]*\.[0-9]*\.[0-9]*|rev: v${ver}|" "${manpage_file}"
    echo "  Updated docs/differential-shellcheck.1.md -> v${ver}"
    ((updated++))
  fi

  echo "Done. Updated ${updated} file(s)."
}

# Check that all version-bearing files are in sync with VERSION
check_versions () {
  local ver
  ver=$(read_version) || return 1

  local mismatches=0

  echo "Checking version consistency (VERSION = ${ver})..."

  # action.yml
  local action_ver
  action_ver=$(extract_version "${PROJECT_ROOT}/action.yml" 'differential-shellcheck:v[0-9]+\.[0-9]+\.[0-9]+' | sed 's/.*:v//')
  if [[ "${action_ver}" != "${ver}" ]]; then
    echo "  MISMATCH: action.yml has v${action_ver}, expected v${ver}"
    ((mismatches++))
  else
    echo "  OK: action.yml (v${action_ver})"
  fi

  # differential-shellcheck.spec
  local spec_ver
  spec_ver=$(extract_version "${PROJECT_ROOT}/differential-shellcheck.spec" 'Version:[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+' | sed 's/Version:[[:space:]]*//')
  if [[ "${spec_ver}" != "${ver}" ]]; then
    echo "  MISMATCH: differential-shellcheck.spec has ${spec_ver}, expected ${ver}"
    ((mismatches++))
  else
    echo "  OK: differential-shellcheck.spec (${spec_ver})"
  fi

  # README.md
  local readme_ver
  readme_ver=$(extract_version "${PROJECT_ROOT}/README.md" 'rev: v[0-9]+\.[0-9]+\.[0-9]+' | sed 's/rev: v//')
  if [[ "${readme_ver}" != "${ver}" ]]; then
    echo "  MISMATCH: README.md has v${readme_ver}, expected v${ver}"
    ((mismatches++))
  else
    echo "  OK: README.md (v${readme_ver})"
  fi

  # docs/differential-shellcheck.1.md
  local manpage_ver
  manpage_ver=$(extract_version "${PROJECT_ROOT}/docs/differential-shellcheck.1.md" 'rev: v[0-9]+\.[0-9]+\.[0-9]+' | sed 's/rev: v//')
  if [[ "${manpage_ver}" != "${ver}" ]]; then
    echo "  MISMATCH: docs/differential-shellcheck.1.md has v${manpage_ver}, expected v${ver}"
    ((mismatches++))
  else
    echo "  OK: docs/differential-shellcheck.1.md (v${manpage_ver})"
  fi

  if [[ ${mismatches} -gt 0 ]]; then
    echo ""
    echo "FAILED: ${mismatches} file(s) out of sync. Run 'make version-bump' to fix."
    return 1
  fi

  echo ""
  echo "All version strings are in sync."
  return 0
}

# --- Main ---
main () {
  case "${1:-}" in
    --check)
      check_versions
      ;;

    --help|-h)
      echo "Usage:"
      echo "  $(basename "$0")              Propagate VERSION to all files"
      echo "  $(basename "$0") X.Y.Z        Set version to X.Y.Z and propagate"
      echo "  $(basename "$0") --check      Verify all files are in sync"
      ;;

    "")
      local ver
      ver=$(read_version) || exit 1
      echo "Propagating version ${ver}..."
      propagate_version "${ver}"
      ;;

    *)
      validate_version "$1" || exit 1
      echo "Setting version to $1..."
      printf '%s\n' "$1" > "${VERSION_FILE}"
      echo "  Updated VERSION -> $1"
      propagate_version "$1"
      ;;
  esac
}

main "$@"
