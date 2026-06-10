#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
script="$repo_root/scripts/export-keys.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bin_dir="$tmpdir/bin"
vault_file="$tmpdir/vault.yml"
mkdir -p "$bin_dir"

cat >"$vault_file" <<'YAML'
---
vault_ssh_key_ed25519: !vault |
          old
vault_gpg_keyring_b64: !vault |
          old-gpg
vault_gpg_passphrase: !vault |
          keep-me
YAML

cat >"$bin_dir/gpg" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--version" ]]; then
  echo "gpg (fake) 0.0"
  exit 0
fi

if [[ "${1:-}" == "--export-ownertrust" ]]; then
  echo "ownertrust"
  exit 0
fi

output=""
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  case "${args[$i]}" in
    -o|--output)
      output="${args[$((i + 1))]}"
      ;;
  esac
done

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  printf 'fake-gpg-output\n' >"$output"
fi
EOF

cat >"$bin_dir/ansible-vault" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" != "encrypt_string" || "${2:-}" != "--stdin-name" || -z "${3:-}" ]]; then
  echo "unexpected ansible-vault invocation: $*" >&2
  exit 2
fi

name="$3"
payload="$(cat)"
cat <<YAML
$name: !vault |
          encrypted-$payload
YAML
EOF

chmod 700 "$bin_dir/gpg" "$bin_dir/ansible-vault"

stdout_path="$tmpdir/stdout"
stderr_path="$tmpdir/stderr"

PATH="$bin_dir:$PATH" bash "$script" --ansible-vault --vault-file "$vault_file" >"$stdout_path" 2>"$stderr_path"

if [[ -s "$stderr_path" ]]; then
  echo "expected empty stderr" >&2
  sed -n '1,120p' "$stderr_path" >&2
  exit 1
fi

grep -F 'vault_ssh_key_ed25519: !vault |' "$vault_file" >/dev/null
grep -F 'vault_gpg_keyring_b64: !vault |' "$vault_file" >/dev/null
grep -F 'encrypted-' "$vault_file" >/dev/null
grep -F 'vault_gpg_passphrase: !vault |' "$vault_file" >/dev/null
grep -F 'keep-me' "$vault_file" >/dev/null

echo "export helper regression test passed"
