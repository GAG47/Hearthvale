#!/usr/bin/env bash
set -euo pipefail

if (($# == 0)); then
	echo "Usage: tools/build.sh <Godot build/export arguments>" >&2
	exit 2
fi

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(dirname -- "$script_directory")"
godot_binary="${GODOT_BIN:-godot}"

"$godot_binary" --headless --path "$project_root" \
	--script res://tools/bake_logical_locations.gd

exec "$godot_binary" --headless --path "$project_root" "$@"
