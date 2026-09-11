#!/usr/bin/env bash
# ==============================================================================
# HubSight SDK - Pre-Publish Validation Script
# ==============================================================================
# Verifies formatting, static analysis, unit tests, version alignment,
# and pub.dev package validation rules before releasing to pub.dev.
# ==============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}   HubSight SDK - Pre-Publish Quality Gatekeeper      ${NC}"
echo -e "${BLUE}======================================================${NC}"

# Step 1: Check Working Tree
echo -e "\n${YELLOW}[1/6] Checking git status...${NC}"
if [[ -n $(git status --porcelain) ]]; then
  echo -e "${RED}❌ Error: Uncommitted changes detected in repository!${NC}"
  echo -e "Please commit or stash your changes before proceeding."
  git status --short
  exit 1
fi
echo -e "${GREEN}✓ Working tree is clean.${NC}"

# Step 2: Code Formatting
echo -e "\n${YELLOW}[2/6] Verifying code formatting (dart format)...${NC}"
if ! dart format --output=none --set-exit-if-changed .; then
  echo -e "${RED}❌ Error: Code formatting check failed!${NC}"
  echo -e "Run 'dart format .' to automatically format all files."
  exit 1
fi
echo -e "${GREEN}✓ All files comply with Dart formatting conventions.${NC}"

# Step 3: Static Analysis
echo -e "\n${YELLOW}[3/6] Running static analysis (dart analyze)...${NC}"
dart analyze --fatal-infos
echo -e "${GREEN}✓ Zero issues found in static analysis.${NC}"

# Step 4: Unit Tests
echo -e "\n${YELLOW}[4/6] Running unit test suite (flutter test)...${NC}"
flutter test
echo -e "${GREEN}✓ All unit tests passed successfully.${NC}"

# Step 5: Version & Changelog Verification
echo -e "\n${YELLOW}[5/6] Checking version alignment between pubspec.yaml and CHANGELOG.md...${NC}"
PUBSPEC_VERSION=$(grep "^version:" pubspec.yaml | head -n1 | awk '{print $2}')
echo -e "Detected package version: ${BLUE}${PUBSPEC_VERSION}${NC}"

if ! grep -q "## ${PUBSPEC_VERSION}" CHANGELOG.md; then
  echo -e "${RED}❌ Error: CHANGELOG.md does not contain a release entry for version ${PUBSPEC_VERSION}!${NC}"
  echo -e "Please document your changes under '## ${PUBSPEC_VERSION}' in CHANGELOG.md."
  exit 1
fi
echo -e "${GREEN}✓ Version ${PUBSPEC_VERSION} is documented in CHANGELOG.md.${NC}"

# Step 6: Pub.dev Dry Run Validation
echo -e "\n${YELLOW}[6/6] Validating package for pub.dev (flutter pub publish --dry-run)...${NC}"
flutter pub publish --dry-run
echo -e "${GREEN}✓ Package validation passed with zero warnings!${NC}"

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}   SUCCESS: Package is 100% ready for pub.dev!        ${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "Next steps to release version ${PUBSPEC_VERSION}:"
echo -e "  1. Create a git tag:"
echo -e "     ${BLUE}git tag v${PUBSPEC_VERSION}${NC}"
echo -e "  2. Push the tag to GitHub:"
echo -e "     ${BLUE}git push origin v${PUBSPEC_VERSION}${NC}"
echo -e "  3. The GitHub Actions 'Publish to pub.dev' workflow will automatically"
echo -e "     deploy this release to https://pub.dev via OIDC tokenless auth."
echo -e ""
