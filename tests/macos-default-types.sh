#!/usr/bin/env bash
set -euo pipefail

require_line() {
  local expected=$1
  if ! grep --fixed-strings -- "$expected" roles/macos/defaults/main.yml >/dev/null; then
    echo "missing expected macOS default declaration: $expected" >&2
    exit 1
  fi
}

require_line "- { domain: NSGlobalDomain, key: KeyRepeat, type: int, value: 2 }"
require_line "- { domain: NSGlobalDomain, key: InitialKeyRepeat, type: int, value: 15 }"
require_line "- { domain: com.apple.dock, key: tilesize, type: float, value: 48.0 }"
