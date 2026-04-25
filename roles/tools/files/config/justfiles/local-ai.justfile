set dotenv-load := false
set export := true

justfile := justfile_directory() + "/.justfiles/local-ai.justfile"

[private]
@default:
    just --justfile {{ justfile }} --list

[private]
@fmt:
    just --justfile {{ justfile }} --fmt

[group("ai")]
@config:
    sed -n '1,160p' ~/.config/local-ai.env

[group("ai")]
@pull model="qwen3-coder:30b":
    ramalama pull {{ model }}

[group("ai")]
@up:
    systemctl --user daemon-reload
    systemctl --user restart local-ai.service || systemctl --user start local-ai.service

[group("ai")]
@down:
    systemctl --user stop local-ai.service

[group("ai")]
@status:
    systemctl --user --no-pager --full status local-ai.service

[group("ai")]
@logs:
    journalctl --user -u local-ai.service -n 200 -f

[group("ai")]
@models:
    curl -fsS http://127.0.0.1:8080/v1/models | jq
