#!/usr/bin/env bash
# Retrieves the ansible-vault password.
# Tries 1Password first; falls back to .vault-pass file.
#
# One-time 1Password setup:
#   Create item "ansible-vault-password" in "Imported Engineering Secrets" vault
#   with the password field set to the contents of .vault-pass
#   Then delete .vault-pass

FALLBACK="$(cd "$(dirname "$0")" && pwd)/.vault-pass"
OP_PATH="op://Imported Engineering Secrets/ansible-vault-password/password"

if [[ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
    if result=$(op read "$OP_PATH" 2>/dev/null); then
        echo "$result"
        exit 0
    fi
fi

if [[ -f "$FALLBACK" ]]; then
    cat "$FALLBACK"
    exit 0
fi

echo "ERROR: No vault password available. Create .vault-pass or add item to 1Password." >&2
exit 1
