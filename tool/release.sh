#!/usr/bin/env bash
# ==============================================================================
# HubSight SDK - Release & Version Bumping Executable
# ==============================================================================
# Automatically bumps version in pubspec.yaml, drafts CHANGELOG.md,
# executes quality gate (dart format, dart analyze, flutter test),
# validates pub.dev packaging, commits, tags, and pushes to GitHub.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"
exec dart run "${SCRIPT_DIR}/release.dart" "$@"
