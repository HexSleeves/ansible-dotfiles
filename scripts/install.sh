#!/usr/bin/env bash
# Remote installer: clone/update this repo and run the Ansible bootstrap.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/HexSleeves/ansible-dotfiles/main/scripts/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/HexSleeves/ansible-dotfiles/main/scripts/install.sh | bash -s -- --tags dotfiles
set -euo pipefail

REPO_URL="${ANSIBLE_DOTFILES_REPO:-https://github.com/HexSleeves/ansible-dotfiles.git}"
REPO_BRANCH="${ANSIBLE_DOTFILES_BRANCH:-main}"
TARGET_DIR="${ANSIBLE_DOTFILES_DIR:-$HOME/Developer/ansible-dotfiles}"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

fail() { printf '[%s] ERROR: %s\n' "$(date +%H:%M:%S)" "$*" >&2; exit 1; }

install_git() {
    if command -v git >/dev/null 2>&1; then
        return
    fi

    log "git not found; installing git..."
    if command -v brew >/dev/null 2>&1; then
        brew install git
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y git ca-certificates
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y git ca-certificates
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --needed --noconfirm git ca-certificates
    else
        fail "Cannot install git automatically. Install git, then rerun this installer."
    fi
}

clone_or_update_repo() {
    if [ -d "$TARGET_DIR/.git" ]; then
        log "Updating existing repo at $TARGET_DIR"
        git -C "$TARGET_DIR" fetch --prune origin "$REPO_BRANCH"
        git -C "$TARGET_DIR" checkout "$REPO_BRANCH"
        git -C "$TARGET_DIR" pull --ff-only origin "$REPO_BRANCH"
        return
    fi

    if [ -e "$TARGET_DIR" ]; then
        fail "$TARGET_DIR exists but is not a git repository. Set ANSIBLE_DOTFILES_DIR or move it aside."
    fi

    log "Cloning $REPO_URL into $TARGET_DIR"
    mkdir -p "$(dirname "$TARGET_DIR")"
    git clone --branch "$REPO_BRANCH" "$REPO_URL" "$TARGET_DIR"
}

main() {
    install_git
    clone_or_update_repo

    log "Running bootstrap script"
    exec bash "$TARGET_DIR/scripts/bootstrap.sh" "$@"
}

main "$@"
