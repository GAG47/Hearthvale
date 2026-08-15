extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const TEST_ACTION_ENTITY := preload("res://tests/entities/helpers/test_action_entity.gd")
const BED_PATH := "res://data/furniture/simple_bed.tres"
const CHEST_PATH := "res://data/furniture/wooden_chest.tres"
const VISUAL_LAYER_FIXTURE := "res://tests/location/fixtures/v10_visual_layer_location.tscn"

var _checks := 0
var _failures := 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var world_definition := root.get_node_or_null("WorldDefinition") as WorldDefinitionRuntime
	var entity_registry := root.get_node_or_null("EntityRegistry") as EntityRegistryRuntime
	var location_space := root.get_node_or_null("LocationSpace") as LocationSpaceRuntime
	_expect(world_definition != null, "WorldDefinition Autoload must exist.")
	_expect(entity_registry != null, "EntityRegistry Autoload must exist.")
	_expect(
		location_space != null and location_space.locations_valid,
		"LocationSpace must load current baked logical data."
	)
	if world_definition == null or entity_registry == null or location_space == null:
		_finish()
		return

	_test_headless_compilation_and_preflight(world_definition)
	_test_runtime_data_boundary(location_space)
	_test_logical_tile_layer_selection(world_definition)
	_test_cli_preflight_entry_points(world_definition)
	_test_static_queries(location_space)

	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var player_id: StringName = game.get("controlled_actor_id")
	var player := entity_registry.get_entity(player_id) as Actor
	var bed := _find_furniture(entity_registry, BED_PATH)
	var chest := _find_furniture(entity_registry, CHEST_PATH)
	_expect(player != null and bed != null and chest != null, "Game must create Player, Bed, and Chest Entities.")
	if player == null or bed == null or chest == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	var tavern := location_space.get_location(&"tavern")
	_test_runtime_index_and_slots(tavern, player, bed, chest)
	_test_action_scoped_and_generic_use_slots(tavern)
	_test_foot_and_front_interaction(tavern)
	_test_representation_uses_existing_state(game, player, bed)

	game.call("request_location_change", &"back_door")
	await _wait_for_transition(game)
	_test_unloaded_location_queries(game, location_space, player, bed, chest)

	game.queue_free()
	await process_frame
	_finish()


func _test_headless_compilation_and_preflight(
	world_definition: WorldDefinitionRuntime
) -> void:
	var definition := world_definition.get_location(&"tavern")
	var fingerprint := LogicalLocationCompiler.compute_source_fingerprint(definition.scene_path)
	var compiled := LogicalLocationCompiler.compile_scene(definition.scene_path, fingerprint)
	_expect(compiled != null, "Location Scene and TileSet Custom Data must compile headlessly.")
	if compiled == null:
		return
	_expect(compiled.location_id == &"tavern", "Compiled data must retain location_id.")
	_expect(compiled.bounds == Rect2i(0, 0, 24, 16), "Bake bounds must come from participating Tiles.")
	_expect(compiled.has_valid_grid_shape(), "Bake must create compact arrays matching bounds.")
	_expect(
		compiled.compiler_version == LogicalLocationCompiler.COMPILER_VERSION,
		"Bake must record compiler version."
	)
	_expect(compiled.source_fingerprint == fingerprint, "Bake must record its source fingerprint.")
	_expect(not LogicalLocationCompiler.needs_bake(definition, fingerprint), "Current output must pass Preflight.")
	_expect(
		LogicalLocationCompiler.needs_bake(definition, fingerprint + "changed"),
		"A changed Scene/TileSet fingerprint must make only that output stale."
	)
	var old_version_data := compiled.duplicate(true) as LogicalLocationData
	old_version_data.compiler_version -= 1
	_expect(
		not LogicalLocationCompiler.is_data_current(definition, old_version_data, fingerprint),
		"An old compiler version must be rejected."
	)
	_expect(
		compiled.get_entry(&"front_door")["cell"] == Vector2i(12, 2),
		"Entry Bake must include its logical Cell."
	)
	_expect(
		compiled.get_entry(&"back_door")["facing"] == ActorState.Facing.UP,
		"Entry Bake must include its facing."
	)
	_expect(not compiled.get_exit(&"front_door").is_empty(), "Exit Bake must include edge_key data.")


func _test_runtime_data_boundary(location_space: LocationSpaceRuntime) -> void:
	var source := _read_text("res://scripts/location/location_space.gd")
	_expect(not source.is_empty(), "LocationSpace runtime source must be readable for boundary verification.")
	_expect(
		not source.contains("scene_path")
		and not source.contains("LogicalLocationCompiler")
		and not source.contains("compute_source_fingerprint")
		and not source.contains("TileMapLayer")
		and not source.contains("TileSet"),
		"LocationSpace runtime must not inspect authoring Scenes, TileSets, or fingerprints."
	)
	var tavern := location_space.get_location(&"tavern")
	_expect(
		tavern.data.get_runtime_validation_warnings(&"tavern").is_empty(),
		"Current LogicalLocationData must satisfy runtime-only structural validation."
	)
	var old_version := tavern.data.duplicate(true) as LogicalLocationData
	old_version.compiler_version -= 1
	_expect(
		not old_version.get_runtime_validation_warnings(&"tavern").is_empty(),
		"Runtime validation must reject a mismatched logical compiler version without consulting authoring sources."
	)


func _test_logical_tile_layer_selection(
	world_definition: WorldDefinitionRuntime
) -> void:
	var fixture := LogicalLocationCompiler.compile_scene(
		VISUAL_LAYER_FIXTURE,
		"visual-layer-fixture"
	)
	_expect(
		fixture != null and fixture.bounds == Rect2i(0, 0, 24, 16),
		"An unmarked visual TileMapLayer without logical Custom Data must not affect Bake bounds or success."
	)
	var definition := world_definition.get_location(&"tavern")
	var location := (load(definition.scene_path) as PackedScene).instantiate() as GridScene
	var ground := location.get_node("Ground") as TileMapLayer
	var structures := location.get_node("Structures") as TileMapLayer
	_expect(
		ground.get("participates_in_static_grid") == true
		and structures.get("participates_in_static_grid") == true,
		"Every current logical TileMapLayer must opt into the static grid explicitly."
	)
	var ground_tile := ground.get_cell_tile_data(Vector2i.ZERO)
	var structure_tile := structures.get_cell_tile_data(Vector2i.ZERO)
	_expect(
		ground_tile != null
		and structure_tile != null
		and ground_tile.get_custom_data(&"walkable") == true
		and structure_tile.get_custom_data(&"walkable") == false,
		"The overlap fixture must contain a walkable ground Tile and a blocked structure Tile."
	)
	_expect(
		fixture != null and not fixture.is_statically_walkable(Vector2i.ZERO),
		"Multiple participating layers must merge the blocked value with priority."
	)
	location.free()


func _test_cli_preflight_entry_points(
	world_definition: WorldDefinitionRuntime
) -> void:
	_expect(
		LogicalLocationCompiler.run_preflight(world_definition.get_locations()),
		"The shared CLI/Editor Location Bake Preflight must accept the current world."
	)
	for script_path in ["res://tools/run_tests.sh", "res://tools/build.sh"]:
		var source := _read_text(script_path)
		var preflight_position := source.find("res://tools/bake_logical_locations.gd")
		var command_position := (
			source.find("for test_script")
			if script_path.ends_with("run_tests.sh")
			else source.find("exec \"$godot_binary\"")
		)
		_expect(
			source.contains("set -euo pipefail")
			and preflight_position >= 0
			and command_position > preflight_position,
			"%s must stop on a failed automatic Bake Preflight before its normal command."
			% script_path
		)


func _test_static_queries(location_space: LocationSpaceRuntime) -> void:
	var tavern := location_space.get_location(&"tavern")
	_expect(tavern != null, "Tavern Logical Location must exist before any Scene is loaded.")
	if tavern == null:
		return
	_expect(tavern.contains_cell(Vector2i(12, 8)), "Bounds query must accept an interior Cell.")
	_expect(not tavern.contains_cell(Vector2i(-1, 8)), "Bounds query must reject an exterior Cell.")
	_expect(tavern.is_statically_walkable(Vector2i(12, 8)), "Explicit floor Tile must be walkable.")
	_expect(not tavern.is_statically_walkable(Vector2i(0, 0)), "Blocked structure Tile must not be walkable.")
	_expect(not tavern.is_statically_walkable(Vector2i(-1, 8)), "Out-of-bounds Cell must be blocked.")
	_expect(tavern.get_movement_cost(Vector2i(12, 8)) == 1, "Walkable Cell movement_cost must be queryable.")
	_expect(tavern.get_movement_cost(Vector2i(0, 0)) == 0, "Blocked Cell must have no movement cost.")


func _test_runtime_index_and_slots(
	tavern: LogicalLocation,
	player: Actor,
	bed: Furniture,
	chest: Furniture
) -> void:
	_expect(tavern.get_entities_in_location().has(bed), "Location must list its offscreen-capable Entities.")
	var bed_cells := tavern.get_entity_occupied_cells(bed)
	_expect(
		bed_cells == [Vector2i(20, 3), Vector2i(20, 4)],
		"Two-cell Furniture footprint must derive from EntityState.local_position."
	)
	_expect(tavern.get_entities_at(Vector2i(20, 3)).has(bed), "Spatial Index must index first footprint Cell.")
	_expect(tavern.get_entities_at(Vector2i(20, 4)).has(bed), "Spatial Index must index second footprint Cell.")
	_expect(not tavern.is_currently_walkable(Vector2i(20, 3)), "Blocking Entity occupancy must affect current walkability.")
	_expect(tavern.get_entities_supporting_action(&"sleep", player).has(bed), "Location must query Entities by Action.")

	var bed_slots := tavern.get_entity_use_slots(bed, &"sleep", player)
	_expect(bed_slots.size() == 1 and bed_slots[0].explicitly_defined, "Bed must use its explicit sleep Slot.")
	_expect(
		bed_slots[0].cell == Vector2i(19, 3)
		and bed_slots[0].required_facing == ActorState.Facing.RIGHT,
		"Explicit Slot must be relative to the footprint top-left."
	)
	var chest_slots := tavern.get_entity_use_slots(chest, &"open", player)
	_expect(not chest_slots.is_empty(), "Furniture without explicit Slots must generate adjacent defaults.")
	_expect(
		_has_slot(chest_slots, Vector2i(13, 6), ActorState.Facing.RIGHT, false),
		"Default Slot must face the Entity from a legal adjacent Cell."
	)

	var old_position := chest.local_position
	var old_cells := chest.get_occupied_grid_cells()
	var moved := (root.get_node("LocationSpace") as LocationSpaceRuntime).try_move_entity(
		chest,
		&"tavern",
		Vector2(528.0, 208.0)
	)
	_expect(moved, "Unified movement boundary must accept a legal offscreen move.")
	_expect(not tavern.get_entities_at(old_cells[0]).has(chest), "Move Commit must remove the old Spatial Index entry.")
	_expect(tavern.get_entities_at(Vector2i(16, 6)).has(chest), "Move Commit must index the new occupied Cell.")
	_expect(chest.local_position == Vector2(528.0, 208.0), "Move Commit must update EntityState.local_position.")
	_expect(
		(root.get_node("LocationSpace") as LocationSpaceRuntime).try_move_entity(chest, &"tavern", old_position),
		"Test cleanup must restore Chest through the same movement boundary."
	)


func _test_action_scoped_and_generic_use_slots(tavern: LogicalLocation) -> void:
	var mixed_definition := (load(BED_PATH) as FurnitureDefinition).duplicate(true) as FurnitureDefinition
	mixed_definition.behaviors = {
		"sleepable": {},
		"inspectable": {"text": "测试床"},
	}
	var mixed_furniture := Furniture.new(
		mixed_definition,
		FurnitureState.new(
			&"11111111-1111-4111-8111-111111111101",
			&"tavern",
			Vector2(272.0, 288.0)
		)
	)
	var sleep_slots := tavern.get_entity_use_slots(mixed_furniture, &"sleep")
	var inspect_slots := tavern.get_entity_use_slots(mixed_furniture, &"inspect")
	_expect(
		sleep_slots.size() == 1 and sleep_slots[0].explicitly_defined,
		"An Action with matching explicit definitions must use only those explicit Slots."
	)
	_expect(
		not inspect_slots.is_empty() and _all_slots_are_default(inspect_slots),
		"An Action without a matching explicit definition must still generate default Slots."
	)

	var generic_entity := TEST_ACTION_ENTITY.new(
		ActorState.new(
			&"11111111-1111-4111-8111-111111111102",
			&"tavern",
			Vector2(400.0, 272.0)
		)
	)
	var generic_definition := UseSlotDefinition.new()
	generic_definition.relative_cell = Vector2i.LEFT
	generic_definition.required_facing = ActorState.Facing.RIGHT
	generic_definition.supported_actions = [&"test_action"]
	generic_entity.explicit_use_slots = [generic_definition]
	var generic_slots := tavern.get_entity_use_slots(generic_entity, &"test_action")
	_expect(
		generic_slots.size() == 1
		and generic_slots[0].explicitly_defined
		and generic_slots[0].cell == Vector2i(11, 8),
		"Explicit Use Slot capability must work for a non-Furniture Entity."
	)


func _test_foot_and_front_interaction(tavern: LogicalLocation) -> void:
	var isolated_tavern := LogicalLocation.new(tavern.data, null)
	var target := TEST_ACTION_ENTITY.new(
		ActorState.new(
			&"11111111-1111-4111-8111-111111111103",
			&"tavern",
			Vector2(400.0, 272.0)
		)
	)
	target.blocks_movement = false
	var actor := Actor.new(
		load("res://data/actors/player.tres") as ActorDefinition,
		ActorState.new(
			&"11111111-1111-4111-8111-111111111104",
			&"tavern",
			Vector2(400.0, 272.0),
			ActorState.Facing.UP
		)
	)
	var slots := isolated_tavern.get_entity_use_slots(target, &"test_action", actor)
	_expect(
		_has_slot(slots, Vector2i(12, 8), ActorState.Facing.UP, false),
		"A nonblocking interactive Entity must generate a default Slot under the Actor's feet."
	)
	_expect(
		_has_slot(slots, Vector2i(12, 7), ActorState.Facing.DOWN, false),
		"Default front interaction Slots around the Entity must remain available."
	)
	var result := WorldAction.new(&"test_action", actor, target, isolated_tavern).execute()
	_expect(result.success, "The foot-under Slot must pass the normal Action spatial rule.")

	var blocking_target := TEST_ACTION_ENTITY.new(
		ActorState.new(
			&"11111111-1111-4111-8111-111111111105",
			&"tavern",
			Vector2(400.0, 272.0)
		)
	)
	var blocking_slots := isolated_tavern.get_entity_use_slots(blocking_target, &"test_action")
	var has_footprint_slot := false
	for slot in blocking_slots:
		if slot.cell == Vector2i(12, 8):
			has_footprint_slot = true
	_expect(not has_footprint_slot, "Blocking Entities must not generate default Slots in their footprint.")


func _test_representation_uses_existing_state(game: Node, player: Actor, bed: Furniture) -> void:
	var current_scene := game.get("current_location") as GridScene
	var controller := game.get_node("PlayerController") as PlayerController
	_expect(current_scene != null and current_scene.location_id == &"tavern", "Tavern Scene must activate normally.")
	_expect(
		controller.controlled_representation.position == player.local_position,
		"Actor Representation must appear from existing EntityState."
	)
	var bed_representation := _find_furniture_representation(current_scene, bed.entity_id)
	_expect(
		bed_representation != null and bed_representation.position == bed.local_position,
		"Furniture Representation must appear from existing EntityState."
	)


func _test_unloaded_location_queries(
	game: Node,
	location_space: LocationSpaceRuntime,
	player: Actor,
	bed: Furniture,
	chest: Furniture
) -> void:
	var current_scene := game.get("current_location") as GridScene
	_expect(current_scene != null and current_scene.location_id == &"tavern_yard", "Transition must load Yard Scene.")
	_expect(player.current_location_id == &"tavern_yard", "Entry Commit must move Actor through LocationSpace.")
	_expect(player.facing == ActorState.Facing.DOWN, "Entry Commit must apply baked Entry facing.")
	var tavern_scene_loaded := false
	var world_root := game.get_node("WorldRoot")
	for child in world_root.get_children():
		if child is GridScene and (child as GridScene).location_id == &"tavern":
			tavern_scene_loaded = true
	_expect(not tavern_scene_loaded, "Tavern Scene and its Representations must be unloaded.")

	var tavern := location_space.get_location(&"tavern")
	_expect(tavern != null and tavern.is_statically_walkable(Vector2i(12, 8)), "Static query must survive Scene unload.")
	_expect(tavern.get_entities_in_location().has(bed), "Entity list must survive Scene unload.")
	_expect(tavern.get_entities_at(Vector2i(20, 4)).has(bed), "Spatial Index must survive Scene unload.")
	_expect(tavern.get_entities_supporting_action(&"sleep", player).has(bed), "Action query must survive Scene unload.")
	_expect(not tavern.get_valid_entity_use_slots(bed, &"sleep", player).is_empty(), "Use Slot query must survive Scene unload.")
	_expect(tavern.get_entities_at(Vector2i(14, 6)).has(chest), "Restored offscreen Entity occupancy must persist.")
	_expect(
		location_space.get_location(&"tavern_yard").get_entities_at(player.current_cell).has(player),
		"Cross-Location Commit must update the destination Spatial Index."
	)


func _find_furniture(registry: EntityRegistryRuntime, definition_path: String) -> Furniture:
	for entity in registry.get_entities():
		if entity is Furniture and (entity as Furniture).definition.resource_path == definition_path:
			return entity as Furniture
	return null


func _find_furniture_representation(
	location: GridScene,
	entity_id: StringName
) -> FurnitureRepresentation:
	for child in location.get_children():
		if child is FurnitureRepresentation and (child as FurnitureRepresentation).entity_id == entity_id:
			return child as FurnitureRepresentation
	return null


func _has_slot(
	slots: Array[EntityUseSlot],
	cell: Vector2i,
	facing: ActorState.Facing,
	explicitly_defined: bool
) -> bool:
	for slot in slots:
		if slot.cell == cell and slot.required_facing == facing and slot.explicitly_defined == explicitly_defined:
			return true
	return false


func _all_slots_are_default(slots: Array[EntityUseSlot]) -> bool:
	for slot in slots:
		if slot.explicitly_defined:
			return false
	return true


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var content := file.get_as_text()
	file.close()
	return content


func _wait_for_transition(game: Node) -> void:
	for _frame in range(60):
		await process_frame
		if not game.get("transition_in_progress"):
			return


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("Test failure: %s" % message)


func _finish() -> void:
	if _failures == 0:
		print("V10 Location Logical Space / Scene Management: %d checks passed." % _checks)
		quit(0)
		return
	push_error("V10 Location Logical Space: %d of %d checks failed." % [_failures, _checks])
	quit(1)
