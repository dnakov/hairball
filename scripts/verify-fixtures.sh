#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

rm -rf "${tmp_dir}/spec"
mkdir -p "${tmp_dir}/spec"
cp -R spec/fixtures "${tmp_dir}/spec/fixtures"

./scripts/export-fixtures.sh
diff -ru "${tmp_dir}/spec/fixtures" spec/fixtures
