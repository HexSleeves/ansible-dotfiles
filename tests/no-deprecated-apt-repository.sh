#!/usr/bin/env bash
set -euo pipefail

if grep -R --line-number --fixed-strings "ansible.builtin.apt_repository" roles playbooks site.yml; then
  echo "deprecated ansible.builtin.apt_repository usage found; use ansible.builtin.deb822_repository instead" >&2
  exit 1
fi
