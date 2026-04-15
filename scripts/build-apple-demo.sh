#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_dir="${repo_root}/apps/apple-demo"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is required" >&2
  exit 1
fi

xcodebuild \
  -project "${project_dir}/HairballExample.xcodeproj" \
  -scheme HairballExample_macOS \
  -configuration Debug \
  build
