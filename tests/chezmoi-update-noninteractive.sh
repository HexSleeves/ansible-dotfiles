#!/usr/bin/env bash
set -euo pipefail

if ! grep -R --line-number --fixed-strings "chezmoi update --init --force --no-tty" roles/chezmoi/tasks/main.yml; then
  echo "chezmoi update must be non-interactive and regenerate templated config: expected --init --force --no-tty" >&2
  exit 1
fi
