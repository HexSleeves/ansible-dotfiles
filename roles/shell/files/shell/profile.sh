# shellcheck shell=sh
# Shared login environment for login shells.

if [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
fi

if [ -f "$HOME/.cargo/env" ]; then
  # shellcheck source=/dev/null
  . "$HOME/.cargo/env"
fi

export GOPATH="${GOPATH:-$HOME/go}"

for path_item in \
  "$HOME/.local/bin" \
  "$HOME/.local/share/cargo/bin" \
  "$HOME/.local/share/mise/bin" \
  "$HOME/.local/share/mise/shims" \
  "$HOME/.npm-global/bin" \
  "$GOPATH/bin"; do
  case ":$PATH:" in
    *":$path_item:"*) ;;
    *) PATH="$path_item:$PATH" ;;
  esac
done

if [ -n "${HOMEBREW_PREFIX:-}" ] && [ -d "${HOMEBREW_PREFIX}/opt/openjdk@21/libexec" ]; then
  export JAVA_HOME="${HOMEBREW_PREFIX}/opt/openjdk@21/libexec"
  case ":$PATH:" in
    *":$JAVA_HOME/bin:"*) ;;
    *) PATH="$JAVA_HOME/bin:$PATH" ;;
  esac
fi

export PATH
export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-$EDITOR}"
export GIT_EDITOR="${GIT_EDITOR:-$EDITOR}"
export PAGER="${PAGER:-less}"
export LESS="${LESS:--FRX}"
export BAT_THEME="${BAT_THEME:-TwoDark}"
export FZF_DEFAULT_COMMAND="${FZF_DEFAULT_COMMAND:-fd --type f --hidden --follow --exclude .git}"
export HOMEBREW_NO_ANALYTICS=1
