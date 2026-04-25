# shellcheck shell=bash
# Interactive bash settings for development.

case $- in
  *i*) ;;
  *) return 0 ;;
esac

HISTSIZE=50000
HISTFILESIZE=100000
PROMPT_DIRTRIM=3

shopt -s histappend checkwinsize

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)"
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook bash)"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init bash)"
fi

if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init bash --disable-up-arrow)"
fi

if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first --icons=auto'
  alias ll='eza -lah --group-directories-first --git --icons=auto'
  alias la='eza -a --group-directories-first --icons=auto'
  alias tree='eza --tree --group-directories-first --icons=auto'
fi

if command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never'
fi
