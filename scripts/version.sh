#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${HAIRBALL_VERSION:-}" ]]; then
  printf '%s\n' "${HAIRBALL_VERSION}"
  exit 0
fi

if git describe --tags --abbrev=0 >/dev/null 2>&1; then
  git describe --tags --abbrev=0
else
  printf '0.0.0-SNAPSHOT\n'
fi
