#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
godot_bin="$(command -v godot || command -v godot4 || true)"
if [[ -z "$godot_bin" ]]; then
  echo "Godot 4 is required. Install Godot 4.6 or open project.godot in the Godot editor." >&2
  exit 1
fi
# Writable engine data/cache paths also work in cloud sandboxes. No HOME changes.
task_runtime_dir="${TMPDIR:-/tmp}/marea-${UID:-user}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$task_runtime_dir/data}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$task_runtime_dir/cache}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$task_runtime_dir/config}"
mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
exec "$godot_bin" --path "$project_dir" "$@"
