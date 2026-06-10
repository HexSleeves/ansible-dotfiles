#!/usr/bin/env bash
set -euo pipefail

if ! grep -A3 --fixed-strings '    - role: distrobox' site.yml | grep --fixed-strings 'ansible_facts['"'"'os_family'"'"'] != "Darwin"' >/dev/null; then
  echo "site.yml must skip the distrobox role on Darwin hosts" >&2
  exit 1
fi

for pattern in "which distrobox" "which podman" "_distrobox_available.rc == 0" "_podman_available.rc == 0"; do
  if ! grep -R --line-number --fixed-strings "$pattern" roles/distrobox/tasks/main.yml >/dev/null; then
    echo "roles/distrobox/tasks/main.yml must guard optional dependency: $pattern" >&2
    exit 1
  fi
done
