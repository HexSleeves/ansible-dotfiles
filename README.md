# ansible-dotfiles

Cross-platform dotfiles and machine configuration managed with Ansible.
Migrated from chezmoi. Supports macOS and Linux (Debian/Arch/RHEL families).

## Requirements

- Ansible ≥ 2.15
- 1Password CLI (`op`) for vault password retrieval
- Python 3

## Quick Start

```bash
# 1. Install Ansible Galaxy collections
ansible-galaxy collection install -r requirements.yml

# 2. Create vault password in 1Password (one-time)
op item create --vault Personal --title "ansible-vault-password" \
  --category login password=$(openssl rand -base64 32)

# 3. Bootstrap a new machine
bash scripts/bootstrap.sh

# Or run specific tags:
ansible-playbook site.yml --tags dotfiles
ansible-playbook site.yml --tags packages
ansible-playbook site.yml --tags secrets
```

## Repo Structure

```bash
ansible-dotfiles/
├── ansible.cfg              # vault_password_file points to .vault-password-op.sh
├── .vault-password-op.sh    # retrieves vault password from 1Password (not in git)
├── requirements.yml         # ansible-galaxy collections
├── site.yml                 # full run
├── playbooks/
│   ├── bootstrap.yml        # first-time setup
│   ├── dotfiles.yml         # dotfiles only
│   ├── packages.yml         # packages + mise
│   └── secrets.yml          # secrets only
├── inventory/
│   ├── hosts
│   └── group_vars/
│       ├── all.yml           # identity, XDG dirs, tool lists
│       ├── all/vault.yml     # ansible-vault encrypted secrets
│       ├── personal.yml      # machine_class = Personal
│       └── work.yml          # machine_class = Work
└── roles/
    ├── common/   — XDG dirs, base packages
    ├── packages/ — Homebrew/apt/pacman/dnf + Brewfile
    ├── mise/     — language runtimes, cargo tools, npm globals
    ├── shell/    — zsh/bash dotfiles + ~/.config/shell/
    ├── git/      — ~/.config/git/config (templated)
    ├── ssh/      — ~/.ssh/config (templated), deploy encrypted keys
    ├── gpg/      — import GPG keyring from vault
    ├── tools/    — tmux, zed, lazygit, gh, ghostty, etc.
    ├── secrets/  — claude, codex, cursor, npm, raycast, opencode
    ├── external/ — clone nvim/zdotdir, download glow + Monaspace
    ├── macos/    — TouchID, Spotlight, macOS defaults
    └── tailscale/— Tailscale install + service
```

## Secrets Migration (from chezmoi)

Decrypt your age-encrypted files and store them as ansible-vault strings.

```bash
# 1. Decrypt a chezmoi .age file
chezmoi decrypt ~/.local/share/chezmoi/home/private_dot_ssh/encrypted_private_id_ed25519.age

# 2. Encrypt the content with ansible-vault
ansible-vault encrypt_string "$(chezmoi decrypt <path>.age)" --name 'vault_ssh_key_ed25519'

# 3. Paste the output into inventory/group_vars/all/vault.yml

# For the GPG keyring (binary archive):
base64 -w0 ~/.local/share/chezmoi/home/bootstrap/gpg/gpg-keyring.tgz.gpg | \
  ansible-vault encrypt_string --stdin-name vault_gpg_keyring_b64
```

## Tags

| Tag | What runs |
|-----|-----------|
| `bootstrap` | common + packages |
| `dotfiles` | shell + git + tools + secrets |
| `packages` | packages + mise |
| `secrets` | ssh + gpg + secrets |
| `macos` | macOS-specific tasks |
| `network` | tailscale |
| Individual role names | that role only |

## Machine Classes

- Add hostname to `[personal]` group in `inventory/hosts` for `machine_class = Personal`
- Add hostname to `[work]` group for `machine_class = Work`
- Personal class installs: rust, lua, cargo tools, npm globals, personal Brewfile extras
- Work class adds: Azure DevOps credential manager in git config

## Vault Variables Reference

All encrypted in `inventory/group_vars/all/vault.yml`:

| Variable | Destination |
|----------|-------------|
| `vault_ssh_key_ed25519` | `~/.ssh/id_ed25519` |
| `vault_ssh_key_bayer` | `~/.ssh/id_bayer` |
| `vault_gpg_keyring_b64` | Imported into GPG keyring |
| `vault_gpg_passphrase` | GPG archive decryption |
| `vault_claude_settings` | `~/.claude/settings.json` |
| `vault_claude_config` | `~/.claude.json` |
| `vault_codex_config` | `~/.codex/config.toml` |
| `vault_cursor_mcp` | `~/.cursor/mcp.json` |
| `vault_npm_token` | `~/.config/npm/npmrc` |
| `vault_raycast_config` | `~/.config/raycast/config.json` |
| `vault_opencode_config` | `~/.config/opencode/opencode.jsonc` |
