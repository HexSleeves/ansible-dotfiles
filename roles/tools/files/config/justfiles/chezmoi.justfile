set dotenv-load := false
set export := true

justfile := justfile_directory() + "/.justfiles/chezmoi.justfile"

[private]
@default:
    just --justfile {{ justfile }} --list

[private]
@fmt:
    just --justfile {{ justfile }} --fmt

[group("chezmoi")]
@sync:
    chezmoi re-add
    chezmoi status
    chezmoi diff

[group("chezmoi")]
@status:
    chezmoi status

[group("chezmoi")]
@diff:
    chezmoi diff

[group("chezmoi")]
@unmanaged:
    chezmoi unmanaged
