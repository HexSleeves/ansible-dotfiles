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
  export-keys.sh --ansible-vault [--vault-file FILE] [--vault-name NAME]
  export-keys.sh --import --archive FILE

Defaults:
  - Legacy export directory: $GNUPGHOME/.exported-keyring (or ~/.gnupg/.exported-keyring)
  - Ansible vault file: inventory/group_vars/all/vault.yml
  - Ansible vault variable: vault_gpg_keyring_b64

Notes:
  - Ansible vault mode stores a base64 copy of a symmetric-GPG-encrypted keyring archive.
  - The encrypted archive is created only in a temporary directory; the durable copy lives in
    Ansible vault.
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

default_vault_repo_root() {
  local script_dir
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
  cd "$script_dir/.." && pwd -P
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

keyring_archive_export() {
  local archive_path="$1"
  local encrypt="$2"

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
    gpg --batch --yes --symmetric --cipher-algo AES256 --output "$archive_path" "$tgz"
  else
    echo "Writing unencrypted archive to $archive_path"
    mv "$tgz" "$archive_path"
    chmod 0600 "$archive_path" || true
  fi

  echo "Archive written to $archive_path"
}

update_ansible_vault() {
  local vault_file="$1"
  local vault_name="$2"

  need_cmd ansible-vault
  [ -f "$vault_file" ] || die "vault file not found: $vault_file"

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap "rm -rf '$tmpdir'" EXIT

  local archive="$tmpdir/gpg-keyring.tgz.gpg"
  keyring_archive_export "$archive" 1

  base64 <"$archive" | tr -d '\n' >"$tmpdir/archive.b64"
  ansible-vault encrypt_string --stdin-name "$vault_name" <"$tmpdir/archive.b64" >"$tmpdir/new-block.yml"

  awk '
    BEGIN { replacing=0; inserted=0 }
    $0 ~ "^" var ":" {
      while ((getline line < block) > 0) print line
      close(block)
      replacing=1
      inserted=1
      next
    }
    replacing && /^[A-Za-z_][A-Za-z0-9_]*:/ {
      replacing=0
    }
    !replacing { print }
    END {
      if (!inserted) exit 42
    }
  ' var="$vault_name" block="$tmpdir/new-block.yml" "$vault_file" >"$tmpdir/vault.yml"

  mv "$tmpdir/vault.yml" "$vault_file"
  chmod 0600 "$vault_file" || true

  echo "Updated $vault_name in $vault_file"
}

keyring_archive_import() {
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
  local use_ansible_vault=0
  local output_path=""
  local archive_path=""
  local no_encrypt=0
  local vault_file=""
  local vault_name="vault_gpg_keyring_b64"

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
      --ansible-vault)
        use_ansible_vault=1
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
      --vault-file)
        shift
        [ $# -gt 0 ] || die "--vault-file requires an argument"
        vault_file="$1"
        shift
        ;;
      --vault-name)
        shift
        [ $# -gt 0 ] || die "--vault-name requires an argument"
        vault_name="$1"
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

  if [ "$use_ansible_vault" -eq 1 ]; then
    [ "$action" = "export" ] || die "--ansible-vault only supports export mode"
    local repo_root
    repo_root="$(default_vault_repo_root)"
    local target_vault="${vault_file:-$repo_root/inventory/group_vars/all/vault.yml}"
    update_ansible_vault "$target_vault" "$vault_name"
    return 0
  fi

  if [ "$action" = "import" ]; then
    [ -n "$archive_path" ] || die "import mode requires --archive"
    keyring_archive_import "$archive_path"
    return 0
  fi

  if [ -n "$output_path" ] && [[ "$output_path" == *.gpg || "$output_path" == *.tgz || "$output_path" == *.tar.gz ]]; then
    local encrypt=1
    if [ "$no_encrypt" -eq 1 ]; then
      encrypt=0
    fi
    keyring_archive_export "$output_path" "$encrypt"
  else
    local gnupghome
    gnupghome="$(default_gnupghome)"
    local export_dir="${output_path:-$gnupghome/.exported-keyring}"
    legacy_export "$export_dir"
  fi
}

main "$@"
