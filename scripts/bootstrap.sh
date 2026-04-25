#!/usr/bin/env bash
# Bootstrap: install Ansible and run site.yml
# Usage: bash scripts/bootstrap.sh [ansible-playbook args]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

install_ansible() {
    if command -v ansible-playbook >/dev/null 2>&1; then
        echo "ansible-playbook found: $(ansible-playbook --version | head -1)"
        return
    fi

    echo "Installing Ansible via pipx..."
    if ! command -v pipx >/dev/null 2>&1; then
        if command -v brew >/dev/null 2>&1; then
            brew install pipx
        elif command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y pipx
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y pipx
        else
            echo "ERROR: Cannot install pipx." >&2; exit 1
        fi
        pipx ensurepath
    fi

    pipx install ansible

    # pipx only symlinks the main entry point; expose all ansible-* binaries
    local pipx_bin="$HOME/.local/share/pipx/venvs/ansible/bin"
    for bin in ansible ansible-vault ansible-playbook ansible-galaxy \
               ansible-config ansible-inventory ansible-doc ansible-console ansible-pull; do
        ln -sf "$pipx_bin/$bin" "$HOME/.local/bin/$bin"
    done
}

install_collections() {
    echo "Installing Ansible Galaxy collections..."
    ansible-galaxy collection install -r requirements.yml --upgrade
}

verify_1password() {
    if ! command -v op >/dev/null 2>&1; then
        echo "WARNING: 1Password CLI (op) not found."
        echo "  Install it, then authenticate: op signin"
        echo "  Or set ANSIBLE_VAULT_PASSWORD_FILE to a local password file."
    fi
}

install_ansible
install_collections
verify_1password

echo "Running site.yml..."
ansible-playbook site.yml --diff "$@"
