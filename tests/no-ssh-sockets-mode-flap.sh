#!/usr/bin/env bash
set -euo pipefail

if grep -n --fixed-strings '    - "{{ _home }}/.ssh/sockets"' roles/common/tasks/main.yml; then
  echo "~/.ssh/sockets must not be in the generic 0755 XDG directory loop; it is managed separately as 0700" >&2
  exit 1
fi
