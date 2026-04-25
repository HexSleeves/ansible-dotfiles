set dotenv-load := false
set export := true

justfile := justfile_directory() + "/.justfiles/distrobox.justfile"

[private]
@default:
    just --justfile {{ justfile }} --list

[private]
@fmt:
    just --justfile {{ justfile }} --fmt

[group("distrobox")]
@migrate-fedora-apps target="fedora-dev":
    ~/.local/bin/setup-fedora-dev-apps {{ target }}

[group("distrobox")]
@list:
    distrobox list
