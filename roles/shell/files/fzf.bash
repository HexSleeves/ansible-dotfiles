# Setup fzf
# ---------
__chezmoi_fzf_prefix=""
if command -v brew >/dev/null 2>&1; then
  __chezmoi_fzf_prefix="$(brew --prefix fzf 2>/dev/null || true)"
elif [[ -d "/opt/homebrew/opt/fzf" ]]; then
  __chezmoi_fzf_prefix="/opt/homebrew/opt/fzf"
elif [[ -d "/usr/local/opt/fzf" ]]; then
  __chezmoi_fzf_prefix="/usr/local/opt/fzf"
fi

if [[ -n "$__chezmoi_fzf_prefix" && -d "$__chezmoi_fzf_prefix/bin" && ":$PATH:" != *":$__chezmoi_fzf_prefix/bin:"* ]]; then
  PATH="$__chezmoi_fzf_prefix/bin${PATH:+:${PATH}}"
fi

if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --bash)"
fi

unset __chezmoi_fzf_prefix
