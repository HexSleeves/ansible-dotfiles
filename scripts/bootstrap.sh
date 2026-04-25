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

    echo "Installing Ansible..."
    if command -v brew >/dev/null 2>&1; then
        brew install ansible
    elif command -v pip3 >/dev/null 2>&1; then
        pip3 install --user ansible
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y ansible
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y ansible
    else
        echo "ERROR: Cannot install Ansible — no package manager found." >&2
        exit 1
    fi
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
