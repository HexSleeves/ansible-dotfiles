#
# nvm - Lazy-loaded for fast shell startup
#

# Homebrew installs nvm.sh under its prefix, but upstream expects a separate
# per-user working directory for installed Node versions.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[[ -d "$NVM_DIR" ]] || mkdir -p "$NVM_DIR"

# Detect NVM installation: Homebrew takes priority when available.
_NVM_BREW_PREFIX=""
if command -v brew >/dev/null 2>&1; then
  _NVM_BREW_PREFIX="$(brew --prefix nvm 2>/dev/null || true)"
fi

if [[ -n "$_NVM_BREW_PREFIX" && -f "$_NVM_BREW_PREFIX/nvm.sh" ]]; then
  _NVM_SH="$_NVM_BREW_PREFIX/nvm.sh"
elif [[ -f "/opt/homebrew/opt/nvm/nvm.sh" ]]; then
  _NVM_SH="/opt/homebrew/opt/nvm/nvm.sh"
elif [[ -f "/usr/local/opt/nvm/nvm.sh" ]]; then
  _NVM_SH="/usr/local/opt/nvm/nvm.sh"
else
  _NVM_SH="$NVM_DIR/nvm.sh"
fi

__chezmoi_load_nvm() {
  unset -f nvm node npm npx yarn pnpm corepack 2>/dev/null
  if [[ -s "$_NVM_SH" ]]; then
    source "$_NVM_SH"
    [[ -s "$NVM_DIR/etc/bash_completion.d/nvm" ]] && source "$NVM_DIR/etc/bash_completion.d/nvm"
    return 0
  else
    return 1
  fi
}

nvm()      { __chezmoi_load_nvm || return $?; nvm "$@"; }
node()     { __chezmoi_load_nvm || return $?; command node "$@"; }
npm()      { __chezmoi_load_nvm || return $?; command npm "$@"; }
npx()      { __chezmoi_load_nvm || return $?; command npx "$@"; }
yarn()     { __chezmoi_load_nvm || return $?; command yarn "$@"; }
pnpm()     { __chezmoi_load_nvm || return $?; command pnpm "$@"; }
corepack() { __chezmoi_load_nvm || return $?; command corepack "$@"; }

unset _NVM_BREW_PREFIX
