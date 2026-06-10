#!/usr/bin/env bash
# Retrieves the ansible-vault password.
# Tries 1Password first (service account or user session); falls back to .vault-pass file.
#
# One-time 1Password setup:
#   Create item "ansible-vault-password" in "Solace - Engineering Secrets" vault
#   with the password field set to the contents of .vault-pass
#   Then delete .vault-pass

FALLBACK="$(cd "$(dirname "$0")" && pwd)/.vault-pass"
OP_PATH="op://Solace - Engineering Secrets/ansible-vault-password/password"

# Try 1Password service account first
if [[ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
    if result=$(op read "$OP_PATH" 2>/dev/null); then
        echo "$result"
        exit 0
    fi
fi

# Try 1Password user session (desktop app integration)
if result=$(op read "$OP_PATH" 2>/dev/null); then
    echo "$result"
    exit 0
fi

if [[ -f "$FALLBACK" ]]; then
    cat "$FALLBACK"
    exit 0
fi

echo "ERROR: No vault password available. Sign into 1Password ('op signin') or create .vault-pass." >&2
exit 1
