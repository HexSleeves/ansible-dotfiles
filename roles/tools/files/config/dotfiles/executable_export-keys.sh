#!/usr/bin/env bash

set -euo pipefail

umask 0077 # secrets: 0600/0700 by default

die() {
  echo "error: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  export-keys.sh [--export] [--output DIR]
  export-keys.sh --chezmoi [--chezmoi-source DIR] [--output FILE] [--no-encrypt]
  export-keys.sh --import [--chezmoi] [--chezmoi-source DIR] [--archive FILE]

Defaults:
  - Legacy export directory: $GNUPGHOME/.exported-keyring (or ~/.gnupg/.exported-keyring)
  - Chezmoi source directory: chezmoi source-path, else ~/.local/share/chezmoi
  - Chezmoi archive path: <chezmoi-source>/bootstrap/gpg/gpg-keyring.tgz.gpg

Notes:
  - The chezmoi mode uses *symmetric* GPG encryption (a passphrase), so you can decrypt/import
    the keyring on a new machine without already having a GPG private key.
  - On a new machine: run `chezmoi init <repo>` (without --apply), then run the import command,
    then run `chezmoi apply`.
EOF
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

default_gnupghome() {
  echo "${GNUPGHOME:-"$HOME/.gnupg"}"
}

primary_fprs() {
  gpg --with-colons --list-keys 2>/dev/null | awk -F: '
    $1=="pub" { want=1; next }
    want && $1=="fpr" { print $10; want=0 }
  '
}

ensure_dir_0700() {
  local dir="$1"
  if [ -d "$dir" ]; then
    chmod 0700 "$dir" || true
  else
    mkdir -p "$dir"
    chmod 0700 "$dir"
  fi
  [ -d "$dir" ] || die "unable to create directory: $dir"
}

resolve_chezmoi_source() {
  if [ -n "${CHEZMOI_SOURCE_DIR:-}" ]; then
    echo "$CHEZMOI_SOURCE_DIR"
    return 0
  fi
  if [ -n "${1:-}" ]; then
    echo "$1"
    return 0
  fi
  if command -v chezmoi >/dev/null 2>&1; then
    local p=""
    p="$(chezmoi source-path 2>/dev/null || true)"
    if [ -n "$p" ]; then
      echo "$p"
      return 0
    fi
  fi
  echo "$HOME/.local/share/chezmoi"
}

legacy_export() {
  local export_dir="$1"

  ensure_dir_0700 "$export_dir"

  echo "Exporting private keys to $export_dir/private-key.asc"
  gpg -a --export-secret-keys -o "$export_dir/private-key.asc"

  echo "Exporting public keys to $export_dir"
  local any_key=0
  while IFS= read -r fpr; do
    [ -n "$fpr" ] || continue
    any_key=1
    echo "  Key: $fpr"
    gpg -a --export "$fpr" >"$export_dir/${fpr}.asc"
  done < <(primary_fprs || true)

  if [ "$any_key" -eq 0 ]; then
    echo "  (no public keys found)"
  fi

  echo "Exporting ownertrust to $export_dir/ownertrust.txt"
  gpg --export-ownertrust >"$export_dir/ownertrust.txt"
}

chezmoi_export() {
  local chezmoi_source="$1"
  local archive_path="$2"
  local encrypt="$3"

  [ -n "$chezmoi_source" ] || die "chezmoi source directory is empty"

  local out_dir
  out_dir="$(dirname "$archive_path")"
  ensure_dir_0700 "$out_dir"

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap "rm -rf '$tmpdir'" EXIT

  mkdir -p "$tmpdir/keyring"

  echo "Exporting key material to temporary directory"
  gpg -a --export-secret-keys -o "$tmpdir/keyring/secret-keys.asc"
  gpg -a --export -o "$tmpdir/keyring/public-keys.asc"
  gpg --export-ownertrust >"$tmpdir/keyring/ownertrust.txt"

  {
    echo "created_at_utc=$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    echo "gnupghome=$(default_gnupghome)"
    echo "gpg_version=$(gpg --version 2>/dev/null | head -n 1 || true)"
    echo "primary_fprs="
    primary_fprs 2>/dev/null || true
  } >"$tmpdir/keyring/manifest.txt"

  local tgz="$tmpdir/gpg-keyring.tgz"
  tar -C "$tmpdir" -czf "$tgz" keyring

  if [ "$encrypt" -eq 1 ]; then
    echo "Encrypting archive (symmetric) to $archive_path"
    gpg --symmetric --cipher-algo AES256 --output "$archive_path" "$tgz"
  else
    echo "Writing unencrypted archive to $archive_path"
    mv "$tgz" "$archive_path"
    chmod 0600 "$archive_path" || true
  fi

  echo "Done. Add $archive_path to your chezmoi repo and commit it."
  echo "Bootstrap import (on a new machine, before 'chezmoi apply'):"
  echo "  $0 --import --chezmoi --archive \"$archive_path\""
}

chezmoi_import() {
  local archive_path="$1"
  [ -f "$archive_path" ] || die "archive not found: $archive_path"

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap "rm -rf '$tmpdir'" EXIT

  local tgz="$tmpdir/gpg-keyring.tgz"
  case "$archive_path" in
    *.gpg)
      echo "Decrypting archive $archive_path"
      gpg --decrypt --output "$tgz" "$archive_path" >/dev/null
      ;;
    *.tgz|*.tar.gz)
      cp "$archive_path" "$tgz"
      ;;
    *)
      die "unsupported archive format (expected .gpg or .tgz): $archive_path"
      ;;
  esac

  tar -C "$tmpdir" -xzf "$tgz"

  local secret="$tmpdir/keyring/secret-keys.asc"
  local public="$tmpdir/keyring/public-keys.asc"
  local ownertrust="$tmpdir/keyring/ownertrust.txt"

  [ -f "$secret" ] || die "missing file in archive: keyring/secret-keys.asc"
  [ -f "$public" ] || die "missing file in archive: keyring/public-keys.asc"

  echo "Importing secret keys"
  gpg --import "$secret" >/dev/null
  echo "Importing public keys"
  gpg --import "$public" >/dev/null

  if [ -f "$ownertrust" ]; then
    echo "Importing ownertrust"
    gpg --import-ownertrust <"$ownertrust" >/dev/null
  fi

  echo "Imported keys:"
  gpg --list-secret-keys --keyid-format=long || true
}

main() {
  need_cmd gpg

  local action="export"
  local use_chezmoi=0
  local chezmoi_source_arg=""
  local output_path=""
  local archive_path=""
  local no_encrypt=0

  while [ $# -gt 0 ]; do
    case "$1" in
      --export)
        action="export"
        shift
        ;;
      --import)
        action="import"
        shift
        ;;
      --chezmoi)
        use_chezmoi=1
        shift
        ;;
      --chezmoi-source)
        shift
        [ $# -gt 0 ] || die "--chezmoi-source requires an argument"
        chezmoi_source_arg="$1"
        shift
        ;;
      --output)
        shift
        [ $# -gt 0 ] || die "--output requires an argument"
        output_path="$1"
        shift
        ;;
      --archive)
        shift
        [ $# -gt 0 ] || die "--archive requires an argument"
        archive_path="$1"
        shift
        ;;
      --no-encrypt)
        no_encrypt=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown argument: $1 (use --help)"
        ;;
    esac
  done

  if [ "$use_chezmoi" -eq 1 ]; then
    local chezmoi_source
    chezmoi_source="$(resolve_chezmoi_source "$chezmoi_source_arg")"
    [ -d "$chezmoi_source" ] || die "chezmoi source directory not found: $chezmoi_source"

    local default_archive="$chezmoi_source/bootstrap/gpg/gpg-keyring.tgz.gpg"

    if [ "$action" = "export" ]; then
      local archive="${output_path:-$default_archive}"
      local encrypt=1
      if [ "$no_encrypt" -eq 1 ]; then
        encrypt=0
        if [ -z "$output_path" ]; then
          archive="$chezmoi_source/bootstrap/gpg/gpg-keyring.tgz"
        fi
      fi
      chezmoi_export "$chezmoi_source" "$archive" "$encrypt"
      return 0
    fi

    if [ "$action" = "import" ]; then
      local archive="${archive_path:-$default_archive}"
      chezmoi_import "$archive"
      return 0
    fi

    die "unknown action: $action"
  fi

  if [ "$action" = "import" ]; then
    die "import mode requires --chezmoi (use --help)"
  fi

  local gnupghome
  gnupghome="$(default_gnupghome)"
  local export_dir="${output_path:-$gnupghome/.exported-keyring}"
  legacy_export "$export_dir"
}

main "$@"
