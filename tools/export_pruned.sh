#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Work-only paths that should never be shipped. They are renamed temporarily
# because Godot 4.6 can still pack these non-resource files despite exclude_filter.
HIDDEN_PATHS=(
  "docs:.docs"
  "web:.web"
  "assets/sound/Reaper:assets/sound/.Reaper"
  "assets/sound/FMOD/sounds/Assets:assets/sound/FMOD/sounds/.Assets"
  "assets/sound/FMOD/sounds/Metadata:assets/sound/FMOD/sounds/.Metadata"
  "assets/sound/FMOD/sounds/sounds.fspro:assets/sound/FMOD/sounds/.sounds.fspro"
  "assets/sound/FMOD/sounds/Master.bank:assets/sound/FMOD/sounds/.Master.bank"
)

RENAMED=()

restore_paths() {
  local pair from to

  for ((idx=${#RENAMED[@]}-1; idx>=0; idx--)); do
    pair="${RENAMED[$idx]}"
    from="${pair%%:*}"
    to="${pair#*:}"

    if [[ -e "$PROJECT_ROOT/$to" && ! -e "$PROJECT_ROOT/$from" ]]; then
      mv "$PROJECT_ROOT/$to" "$PROJECT_ROOT/$from"
      printf 'Restored %s\n' "$from"
    fi
  done
}

hide_paths() {
  local pair from to

  for pair in "${HIDDEN_PATHS[@]}"; do
    from="${pair%%:*}"
    to="${pair#*:}"

    if [[ ! -e "$PROJECT_ROOT/$from" ]]; then
      continue
    fi

    if [[ -e "$PROJECT_ROOT/$to" ]]; then
      printf 'Cannot hide %s: %s already exists.\n' "$from" "$to" >&2
      exit 1
    fi

    mv "$PROJECT_ROOT/$from" "$PROJECT_ROOT/$to"
    RENAMED+=("$from:$to")
    printf 'Hidden %s -> %s\n' "$from" "$to"
  done
}

usage() {
  cat <<'EOF'
Usage:
  tools/export_pruned.sh [preset] [output_path]
  tools/export_pruned.sh -- <custom godot export command>

Examples:
  GODOT_BIN=/home/xxx/godot/Godot_v4.6.2-stable_linux.x86_64 tools/export_pruned.sh "Linux" ../exports/linux/0.9.2/Florilexio.x86_64
  GODOT_BIN=/home/xxx/godot/Godot_v4.6.2-stable_linux.x86_64 tools/export_pruned.sh "Windows Desktop" ../exports/windows/0.9.2/Florilexio.exe
  tools/export_pruned.sh -- /home/aroig/godot/Godot_v4.6.2-stable_linux.x86_64 --headless --path . --export-pack "Linux" /tmp/florilexio-pruned-test.pck

Environment:
  GODOT_BIN     Godot executable to use when not passing a custom command.
  EXPORT_MODE   Godot export flag. Defaults to --export-release.
EOF
}

main() {
  local godot_bin export_mode preset output

  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  cd "$PROJECT_ROOT"
  trap restore_paths EXIT INT TERM
  hide_paths

  if [[ "${1:-}" == "--" ]]; then
    shift
    if [[ "$#" -eq 0 ]]; then
      printf 'Missing command after --\n' >&2
      exit 1
    fi
    "$@"
    return
  fi

  godot_bin="${GODOT_BIN:-godot}"
  export_mode="${EXPORT_MODE:---export-release}"
  preset="${1:-Linux}"
  output="${2:-}"

  if [[ -n "$output" ]]; then
    "$godot_bin" --headless --path "$PROJECT_ROOT" "$export_mode" "$preset" "$output"
  else
    "$godot_bin" --headless --path "$PROJECT_ROOT" "$export_mode" "$preset"
  fi
}

main "$@"
