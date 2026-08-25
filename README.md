# ansible-dotfiles

> **DEPRECATED (2026-08-25).** This repo is retired. All machine management has
> moved to [hm-dotfiles](https://github.com/HexSleeves/hm-dotfiles)
> (Home Manager + nix-darwin + sops-nix), which now covers SSH, GPG, packages,
> homebrew, dotfiles, and secrets for every host in the old inventory.
> Do not run `just apply` / `site.yml` against any machine; it would fight
> home-manager over the same files (`~/.ssh/config`, `~/.claude/*`, and more).
> Kept as history only.

Cross-platform machine provisioning for macOS and Linux (Debian/Ubuntu, Arch, RHEL/Fedora).

**Architecture:** Ansible owns system-level setup — packages, secrets, SSH/GPG keys, and OS configuration. Dotfiles are delegated to [chezmoi](https://www.chezmoi.io/) via a [separate repo](https://github.com/HexSleeves/dotfiles).

---

## Requirements

| Dependency           | Purpose                  |
| -------------------- | ------------------------ |
| Ansible ≥ 2.15       | Provisioning engine      |
| Python 3             | Ansible runtime          |
| 1Password CLI (`op`) | Vault password retrieval |
| Git                  | Repo clone, chezmoi      |

---

## Quick Start

### Fresh machine (one-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/HexSleeves/ansible-dotfiles/main/scripts/install.sh | bash
```

This script:

1. Installs `git` if missing
2. Clones this repo to `~/Developer/ansible-dotfiles`
3. Installs Ansible via `pipx` and symlinks all `ansible-*` binaries to `~/.local/bin`
4. Installs Ansible Galaxy collections
5. Runs `ansible-playbook site.yml --diff`

Pass `ansible-playbook` args through:

```bash
curl -fsSL https://raw.githubusercontent.com/HexSleeves/ansible-dotfiles/main/scripts/install.sh | bash -s -- --tags packages
```

### Manual setup (repo already cloned)

```bash
# 1. Install Galaxy collections
ansible-galaxy collection install -r requirements.yml

# 2. Authenticate 1Password CLI
op signin

# 3. Run the full playbook
ansible-playbook site.yml --diff

# Or run a focused playbook
ansible-playbook playbooks/packages.yml
ansible-playbook playbooks/secrets.yml
ansible-playbook playbooks/dotfiles.yml
```

### Local task runner

This repo includes a `justfile` for common commands:

```bash
just                 # list recipes
just syntax          # ansible-playbook --syntax-check site.yml
just check           # dry run with --check --diff
just apply           # full site.yml run with --diff
just tags secrets    # run site.yml with --tags secrets
just check-tags ssh,gpg,secrets
just packages
just secrets
just dotfiles
just refresh-gpg     # refresh vault_gpg_keyring_b64 from local GPG keyring
just verify          # shell checks, deprecation guards, export regression, syntax check, diff check
```

---

## Repo Structure

```
ansible-dotfiles/
├── ansible.cfg                  # Vault password file, fact caching, SSH pipelining
├── site.yml                     # Full provisioning playbook
├── requirements.yml             # community.general, ansible.posix
├── scripts/
│   ├── install.sh               # Remote one-liner bootstrapper
│   └── bootstrap.sh             # Local bootstrap (pipx → ansible → site.yml)
├── inventory/
│   ├── hosts                    # Groups: local, personal, work
│   └── group_vars/
│       ├── all/
│       │   ├── vars.yml         # Shared variables (XDG dirs, tool lists, chezmoi_repo)
│       │   └── vault.yml        # Ansible-vault encrypted secrets
│       ├── personal.yml         # machine_class = Personal
│       └── work.yml             # machine_class = Work
├── playbooks/
│   ├── bootstrap.yml            # Full first-time setup
│   ├── dotfiles.yml             # chezmoi apply + secrets
│   ├── packages.yml             # Homebrew + mise only
│   └── secrets.yml              # SSH + GPG + app secrets only
└── roles/
    ├── common/                  # XDG dirs, base packages
    ├── packages/                # Homebrew + Brewfile
    ├── mise/                    # Language runtimes + cargo/npm tools
    ├── chezmoi/                 # Install chezmoi, init/update dotfiles repo
    ├── ssh/                     # SSH config template + deploy private keys
    ├── gpg/                     # Import GPG keyring from vault
    ├── secrets/                 # Deploy app configs (Claude, Codex, Cursor, etc.)
    ├── external/                # Clone nvim/zdotdir, download fonts and binaries
    ├── macos/                   # TouchID sudo, Spotlight, macOS system defaults
    └── tailscale/               # Install Tailscale + enable daemon
```

---

## Roles

### `common`

Creates XDG base directories and `~/.ssh/sockets`. On Debian/Ubuntu, repairs 1Password's apt repository metadata. Installs minimal native packages required before Homebrew:

| Platform      | Packages                                          |
| ------------- | ------------------------------------------------- |
| Debian/Ubuntu | `git curl build-essential gnupg python3-debian age wl-clipboard` |
| Arch          | `git curl base-devel gnupg age`                   |
| RHEL/Fedora   | `git curl gcc gcc-c++ make gnupg2`                |

---

### `packages`

Installs [Homebrew](https://brew.sh) as the primary package manager on both macOS and Linux, then runs `brew bundle` against `roles/packages/files/Brewfile`.

Notable packages installed on all platforms:

```
age atuin awscli bat bitwarden-cli bottom chezmoi difftastic direnv
duf dust eza fd fish fzf gh git-cliff git-delta glow gnupg gum
htop hyperfine jq just k9s lazydocker lazygit mise mkcert mosh
neovim pass pipx pnpm ripgrep shellcheck shfmt starship tailscale
tealdeer tmux tokei topgrade tree watchexec xh yq zoxide zsh
```

Additional platform-specific packages:

- **Linux only:** `lld openjdk postgresql@18 redis`
- **macOS only (brew):** `cocoapods docker pinentry-mac swift-format`
- **macOS only (cask):** `1password-cli cursor codexbar dotnet-sdk gcloud-cli git-credential-manager orbstack raycast rectangle zed` + Nerd Fonts (CaskaydiaCove, FiraCode, JetBrainsMono)

> **Note:** Native distro packages are intentionally minimal — only what Homebrew itself needs to compile. All tooling comes through `brew bundle`.

---

### `mise`

Installs [mise](https://mise.jdx.dev) and activates language runtimes globally:

| Tools                                                                 | Machine class |
| --------------------------------------------------------------------- | ------------- |
| `node@lts` `python@latest` `golang@latest` `deno@latest` `bun@latest` | All           |
| `rust@latest` `lua@latest` `neovim@latest` `yamlfmt@latest`           | Personal only |

Personal machines also install via `cargo binstall`: `bat ripgrep fd-find eza zoxide starship bottom tokei`

And via npm: `typescript ts-node neovim`

---

### `chezmoi`

Installs `chezmoi` (via Homebrew on macOS, direct binary on Linux), then:

- **Fresh machine** (`~/.local/share/chezmoi` absent): runs `chezmoi init --apply git@github.com:HexSleeves/dotfiles.git`
- **Existing install**: runs `chezmoi update --no-tty`
- **No repo set** (`chezmoi_repo` empty): installs chezmoi but skips init/update

The chezmoi repo owns all dotfiles: shell rc files, `~/.config/*`, git config, `~/.local/bin` scripts, etc.

To add a new dotfile:

```bash
chezmoi add ~/.config/sometool/config.toml
cd ~/.local/share/chezmoi && git add -A && git commit -m "feat: add sometool config"
```

---

## Secrets Management

Ansible vault is the canonical store for bootstrap secrets. Chezmoi should not
carry a second copy of the GPG keyring archive.

```bash
# 1. Decrypt a chezmoi .age file
chezmoi decrypt ~/.local/share/chezmoi/home/private_dot_ssh/encrypted_private_id_ed25519.age

# 2. Encrypt the content with ansible-vault
ansible-vault encrypt_string "$(chezmoi decrypt <path>.age)" --name 'vault_ssh_key_ed25519'

# 3. Paste the output into inventory/group_vars/all/vault.yml

# Refresh the GPG keyring vault entry from the local keyring:
bash scripts/export-keys.sh --ansible-vault
```

---

### `ssh`

Creates `~/.ssh` (mode `0700`) and `~/.ssh/sockets`. Templates `~/.ssh/config` with:

- OrbStack include (macOS)
- Hardened `Host *` block — ControlMaster, keepalives, chacha20/aes256 ciphers, ed25519/rsa key algorithms
- 1Password SSH agent socket (macOS: `~/Library/Group Containers/.../agent.sock`, Linux: `~/.1password/agent.sock`)
- Host stanzas for `github.com`, `gist.github.com`, `*.bayer.com`, `localhost`, personal servers

Deploys private keys from vault (mode `0600`):

- `vault_ssh_key_ed25519` → `~/.ssh/id_ed25519`
- `vault_ssh_key_bayer` → `~/.ssh/id_bayer`

> **Order dependency:** SSH runs before `chezmoi` so the deploy key is in place before `chezmoi init` pulls the private dotfiles repo.

---

### `gpg`

Imports the full GPG keyring from vault. Skips if the signing key fingerprint (`758709BBEB67145DE844FC85C61F052D671268B5`) is already present. Uses `no_log: true` throughout. Temp files are cleaned in an `always` block.

---

### `secrets`

Deploys encrypted application configs (all mode `0600`, `no_log: true`):

| Vault variable          | Destination                         |
| ----------------------- | ----------------------------------- |
| `vault_claude_settings` | `~/.claude/settings.json`           |
| `vault_claude_config`   | `~/.claude.json`                    |
| `vault_codex_config`    | `~/.codex/config.toml`              |
| `vault_cursor_mcp`      | `~/.cursor/mcp.json`                |
| `vault_npm_token`       | `~/.config/npm/npmrc`               |
| `vault_raycast_config`  | `~/.config/raycast/config.json`     |
| `vault_opencode_config` | `~/.config/opencode/opencode.jsonc` |

Also copies static (non-secret) config files from `roles/secrets/files/` for Claude, Codex, and Cursor (agent docs, commands, skills, hooks).

---

### `external`

Clones dotfile-adjacent repos (no auto-update by default — pass `-e external_repos_update=true` to pull):

| Repo                 | Destination      |
| -------------------- | ---------------- |
| `HexSleeves/nvim`    | `~/.config/nvim` |
| `HexSleeves/zdotdir` | `~/.config/zsh`  |

On Linux x86_64: downloads and SHA256-verifies the `glow` v2.1.2 binary to `~/.local/bin/glow`.

On Linux: downloads Monaspace fonts v1.400 to `~/.local/share/fonts/Monaspace/` and runs `fc-cache`.

---

### `macos`

Darwin only. Applies system-level macOS configuration:

- **TouchID for sudo** — configurable via `macos_touchid_sudo` (default: `true`)
- **Passwordless sudo** — configurable via `macos_nopasswd_sudo` (default: `false`)
- Disables **Spotlight indexing** of `~/Developer`
- Adds `sshd` to the macOS application firewall
- Applies `macos_defaults` list via `community.general.osx_defaults`

Notable defaults managed: boot sound off, save to disk not iCloud, fast key repeat, tap-to-click, Finder hidden files/extensions/status bar/path bar, Dock autohide and tile size, screenshot format and location, Activity Monitor settings.

**Sudo configuration variables** (set in `inventory/group_vars/all/vars.yml`):

| Variable | Default | Effect |
|----------|---------|--------|
| `macos_touchid_sudo` | `true` | Enables TouchID prompt in `sudo_local` |
| `macos_nopasswd_sudo` | `false` | Creates `/etc/sudoers.d/{user}-nopasswd` for passwordless sudo |

---

### `tailscale`

Installs Tailscale. On Linux, enables and starts `tailscaled` via systemd. Does not run `tailscale up` automatically — authenticate manually after provisioning:

```bash
sudo tailscale up
```

---

## Tags

Run any subset with `--tags`:

| Tag         | Roles                               |
| ----------- | ----------------------------------- |
| `bootstrap` | `common` + `packages`               |
| `dotfiles`  | `chezmoi` + `secrets`               |
| `packages`  | `packages` + `mise`                 |
| `secrets`   | `ssh` + `gpg` + `secrets`           |
| `chezmoi`   | `chezmoi`                           |
| `macos`     | `macos`                             |
| `network`   | `tailscale`                         |
| `external`  | `external`                          |
| Role name   | That role only (e.g. `--tags mise`) |

Examples:

```bash
# Re-deploy secrets only
ansible-playbook site.yml --tags secrets

# Update dotfiles via chezmoi
ansible-playbook site.yml --tags chezmoi

# Run packages + mise only
ansible-playbook playbooks/packages.yml
```

---

## Machine Classes

Add a hostname to the appropriate inventory group in `inventory/hosts`:

```ini
[local]
localhost ansible_connection=local

[personal]
Jacobs-MacBook-Pro.local

[work]
work-laptop.local
```

| Class      | Extra installs                                              |
| ---------- | ----------------------------------------------------------- |
| `Personal` | Rust, Lua, Neovim, yamlfmt (mise), cargo tools, npm globals |
| `Work`     | Core mise runtimes only                                     |
| ---        | ---                                                         |
| `Personal` | Rust, Lua, Neovim, yamlfmt (mise), cargo tools, npm globals |
| `Work`     | Core mise runtimes only                                     |

---

## Vault Variables

All secrets live in `inventory/group_vars/all/vault.yml`, encrypted with `ansible-vault`.

### Initial setup (one-time)

```bash
# Create the vault password in 1Password
op item create --vault Personal --title "ansible-vault-password" \
  --category login password=$(openssl rand -base64 32)

# Copy the vault password script (not tracked in git)
cp .vault-password-op.sh.example .vault-password-op.sh
chmod +x .vault-password-op.sh
```

### Encrypt a new secret

```bash
ansible-vault encrypt_string 'secret-value' --name 'vault_my_secret'
# Paste the output into inventory/group_vars/all/vault.yml
```

### Update an existing secret

```bash
# View current value
ansible-vault decrypt inventory/group_vars/all/vault.yml --output -

# Re-encrypt the whole file after editing
ansible-vault encrypt inventory/group_vars/all/vault.yml
```

### Migrate from chezmoi age-encrypted files

```bash
# Decrypt an age file from the old chezmoi repo
chezmoi decrypt ~/.local/share/chezmoi/path/to/file.age

# Encrypt as an ansible-vault string
ansible-vault encrypt_string "$(chezmoi decrypt <path>.age)" --name 'vault_variable_name'
```

### GPG keyring

```bash
# Export and encrypt (run on machine with the keyring)
gpg --export-secret-keys --armor | base64 -w0 > /tmp/keys.b64
gpg --export --armor >> /tmp/keys.b64
gpg --export-ownertrust >> /tmp/ownertrust.txt
# Then encrypt /tmp/keys.b64 as vault_gpg_keyring_b64
```

---

## Adding a New Secret Config

1. Encrypt the file content:

   ```bash
   ansible-vault encrypt_string "$(cat ~/.config/mytool/config.json)" --name 'vault_mytool_config'
   ```

2. Add the variable to `inventory/group_vars/all/vault.yml`
3. Add a deploy task to `roles/secrets/tasks/main.yml`:

   ```yaml
   - name: Deploy mytool config
     ansible.builtin.copy:
       content: "{{ vault_mytool_config }}"
       dest: "{{ xdg_config_home }}/mytool/config.json"
       mode: "0600"
     no_log: true
   ```

---

## Performance Notes

- **Fact caching:** Facts are cached as JSON in `.ansible_facts/` for 24 hours. Force a refresh with `--flush-cache` or delete the directory.
- **Galaxy collections:** Installed by `bootstrap.sh` and the `install.sh` one-liner. On subsequent runs via `site.yml`, set `-e install_ansible_collections=true` to reinstall.
- **External repos:** Set `-e external_repos_update=true` to pull latest commits from `nvim` and `zdotdir`.
