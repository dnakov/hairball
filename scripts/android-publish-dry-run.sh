#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}/android"

./gradlew \
  :hairball-core:publishToMavenLocal \
  :hairball-compose:publishToMavenLocal \
  -Psigning.required=false
