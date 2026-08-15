#!/usr/bin/env bash
set -euo pipefail

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(dirname -- "$script_directory")"
godot_binary="${GODOT_BIN:-godot}"

"$godot_binary" --headless --path "$project_root" \
	--script res://tools/bake_logical_locations.gd

if (($# > 0)); then
	test_scripts=("$@")
else
	test_scripts=(
		res://tests/entities/test_entity_lifecycle_baking.gd
		res://tests/entities/test_entity_registry.gd
		res://tests/entities/test_entity_representation_system.gd
		res://tests/entities/test_v7_4_runtime.gd
		res://tests/entities/test_v7_5_location_transition.gd
		res://tests/entities/test_v9_1_entity_lifecycle_cleanup.gd
		res://tests/entities/test_v9_2_static_definition_resources.gd
		res://tests/location/test_v10_location_logical_space.gd
	)
fi

for test_script in "${test_scripts[@]}"; do
	"$godot_binary" --headless --path "$project_root" --script "$test_script"
done
