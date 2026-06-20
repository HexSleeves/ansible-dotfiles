#!/usr/bin/env bash
# Bootstrap: install Homebrew (macOS), Ansible, and run site.yml
# Usage: bash scripts/bootstrap.sh [ansible-playbook args]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

install_brew() {
    if command -v brew >/dev/null 2>&1; then
        log "Homebrew already installed at $(brew --prefix)."
        return
    fi
    if [[ "$(uname -s)" != "Darwin" ]]; then
        return
    fi

    local arch
    arch="$(uname -m)"
    log "Installing Homebrew on ${arch} macOS..."

    # Standard install detects arm64 → /opt/homebrew, x86_64 → /usr/local.
    # On macOS 14+ it may need sudo for /opt/homebrew; run with NONINTERACTIVE.
    if NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        log "Homebrew installed via standard installer."
    else
        log "Standard install failed (likely needs sudo)."
        log "Run the installer manually, then re-run bootstrap:"
        log '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        exit 1
    fi

    local brew_prefix
    if [[ "$arch" == "arm64" ]]; then
        brew_prefix="/opt/homebrew"
    else
        brew_prefix="/usr/local"
    fi

    eval "$("$brew_prefix/bin/brew" shellenv)"
    mkdir -p "$HOME/.local/bin"
    ln -sf "$brew_prefix/bin/brew" "$HOME/.local/bin/brew"
    log "Homebrew installed at $brew_prefix."
}

install_ansible() {
    log "Installing Ansible via pipx..."
    if ! command -v pipx >/dev/null 2>&1; then
        if command -v brew >/dev/null 2>&1; then
            brew install pipx
        elif command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y pipx
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y pipx
        else
            log "ERROR: Cannot install pipx." >&2; exit 1
        fi
        pipx ensurepath
    fi

    pipx install ansible || pipx upgrade ansible

    # Resolve the venvs location (differs between Linux and macOS)
    local pipx_bin
    pipx_bin="$(pipx environment --value PIPX_LOCAL_VENVS)/ansible/bin"
    mkdir -p "$HOME/.local/bin"
    for bin in ansible ansible-vault ansible-playbook ansible-galaxy \
               ansible-config ansible-inventory ansible-doc ansible-console ansible-pull; do
        ln -sf "$pipx_bin/$bin" "$HOME/.local/bin/$bin"
    done
    export PATH="$HOME/.local/bin:$PATH"
}

install_collections() {
    log "Installing Ansible Galaxy collections..."
    ansible-galaxy collection install -r requirements.yml --upgrade
}

verify_1password() {
    if ! command -v op >/dev/null 2>&1; then
        log "WARNING: 1Password CLI (op) not found."
        log "  Install it, then authenticate: op signin"
        log "  Or set ANSIBLE_VAULT_PASSWORD_FILE to a local password file."
    fi
}

install_brew
install_ansible
install_collections

# Warn if vault password is unreachable — suggest bootstrapping without secrets first.
if ! bash .vault-password-op.sh >/dev/null 2>&1; then
    log "WARNING: Vault password is not available."
    log "  Start with: ansible-playbook site.yml --diff --tags bootstrap"
    log "  Or install 1Password CLI: brew install --cask 1password-cli && op signin"
    log "  Or create .vault-pass with the plaintext password."
fi

log "Running site.yml..."
ansible-playbook site.yml --diff "$@"
