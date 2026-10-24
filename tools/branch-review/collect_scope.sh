#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
node "$SCRIPT_DIR/../ai-workflow/collect.mjs" "${1:-origin/develop}" "${2:-.tmp/branch-review}"
