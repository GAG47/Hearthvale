extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const BED_PATH := "res://data/furniture/simple_bed.tres"
const CHEST_PATH := "res://data/furniture/wooden_chest.tres"

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
