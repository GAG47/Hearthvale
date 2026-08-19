extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const MARTHA_DEFINITION: ActorDefinition = preload("res://data/actors/martha.tres")
const TEST_ACTOR_ID := &"e3000000-0000-4000-8000-000000000001"

var _checks := 0
var _failures := 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var location_registry := root.get_node_or_null("LocationRegistry") as LocationRegistry
	var state_registry := root.get_node_or_null("StateRegistry") as StateRegistry
	var entity_registry := root.get_node_or_null("EntityRegistry") as EntityRegistry
	var movement := root.get_node_or_null("LogicalMovement") as LogicalMovement
	var game_clock := root.get_node_or_null("GameClock") as GameClock
	_expect(location_registry != null, "LocationRegistry Autoload must exist.")
	_expect(state_registry != null, "StateRegistry Autoload must exist.")
	_expect(entity_registry != null, "EntityRegistry Autoload must exist.")
	_expect(movement != null, "LogicalMovement Autoload must remain independent.")
	_expect(game_clock != null, "GameClock Autoload must exist.")
	_expect(root.get_node_or_null("WorldDefinition") == null, "WorldDefinition Autoload must be removed.")
	_expect(root.get_node_or_null("WorldState") == null, "WorldState Autoload must be removed.")
	_expect(root.get_node_or_null("WorldTime") == null, "WorldTime Autoload must be removed.")
	if location_registry == null or state_registry == null or entity_registry == null or movement == null:
		_finish()
		return

	_expect(state_registry.get_location_states().is_empty(), "StateRegistry must not auto-create Project LocationState objects.")
	var tavern_id_before_game := location_registry.get_project_location_id(&"tavern")
	var locations_before_game := location_registry.get_all().size()
	var states_before_game := state_registry.get_location_states().size()
	_expect(location_registry.get_location_definition(tavern_id_before_game) != null, "Project LocationDefinition should be indexed before runtime Location initialization.")
	_expect(not location_registry.has_location(tavern_id_before_game), "Definition presence must not count as registered Location presence.")
	_expect(location_registry.get_location(tavern_id_before_game) == null, "LocationRegistry.get_location must not create an unregistered Project Location.")
	var unknown_location_id := &"e5000000-0000-4000-8000-000000000001"
	_expect(not location_registry.has_location(unknown_location_id), "Unknown Location must not be reported as registered.")
	_expect(location_registry.get_location(unknown_location_id) == null, "LocationRegistry.get_location must return null for an unknown Location.")
	_expect(location_registry.get_all().size() == locations_before_game, "A pure Location query must not register a Location.")
	_expect(state_registry.get_location_states().size() == states_before_game, "A pure Location query must not create LocationState.")
	_expect(not _has_property(state_registry, &"_active_locations"), "StateRegistry must not store LocationScene Nodes.")
	_expect(not state_registry.has_method("register_location"), "StateRegistry must not register LocationScene Nodes.")

	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame

	_expect(location_registry.get_all().size() == 3, "Game startup must register the three Project Locations.")
	var tavern_id := location_registry.get_project_location_id(&"tavern")
	var tavern := location_registry.get_location(tavern_id)
	_expect(location_registry.has_location(tavern_id), "LocationRegistry.has_location must find a registered Location.")
	_expect(location_registry.get_location(tavern_id) == tavern, "LocationRegistry.get_location must return the registered Location.")
	_expect(tavern != null and tavern.definition != null and tavern.state != null and tavern.entity_registry == entity_registry, "Location must compose Definition, State, and EntityRegistry.")
	_expect(not _has_property(tavern, &"location_id"), "Location must expose only instance_id identity.")
	_expect(not _has_property(tavern, &"movement_runtime"), "Location must not hold LogicalMovement.")
	_expect(not tavern.has_method("is_actor_cell_available"), "Location must not expose mixed static-plus-Actor occupancy queries.")

	await _test_committed_position_and_arrival_composition(
		game,
		location_registry,
		state_registry,
		entity_registry,
		movement
	)
	_test_names_and_paths()

	game.queue_free()
	await process_frame
	_finish()


func _test_committed_position_and_arrival_composition(
	game: Node,
	location_registry: LocationRegistry,
	state_registry: StateRegistry,
	entity_registry: EntityRegistry,
	movement: LogicalMovement
) -> void:
	movement.set_physics_process(false)
	var tavern_id := location_registry.get_project_location_id(&"tavern")
	var edge := location_registry.get_edge(tavern_id, &"back_door")
	var target_location := location_registry.get_location(edge.target_location_id)
	var entry := target_location.get_entry(edge.target_entry_id)
	var cells := _find_three_open_cells(target_location)
	_expect(cells.size() == 3, "Target Location must contain three adjacent static test Cells.")
	if cells.size() != 3:
		return

	var tail_cell: Vector2i = cells[0]
	var head_cell: Vector2i = cells[1]
	var fallback_cell: Vector2i = cells[2]
	var actor_state := ActorState.new(
		TEST_ACTOR_ID,
		target_location.instance_id,
		tail_cell,
		ActorState.Facing.RIGHT
	)
	var actor_definition := MARTHA_DEFINITION.duplicate(true) as ActorDefinition
	var actor := Actor.new(actor_definition, actor_state)
	_expect(state_registry.register_entity_state(actor_state), "V11.3 test ActorState must register.")
	_expect(entity_registry.register_entity(actor), "V11.3 test Actor must register.")
	_expect(movement.request_step(actor, head_cell - tail_cell), "V11.3 test Actor must accept a logical step.")
	var request := movement.get_request(actor)
	movement.call("_activate_participants")
	movement.call("_activate_requesting", request)
	_expect(request.phase == ActorMovementRequest.Phase.EXTENDED, "Test Actor must reach extended phase.")
	_expect(target_location.get_entities_at(tail_cell).has(actor), "Location must find an extended Actor at its committed tail Cell.")
	_expect(not target_location.get_entities_at(head_cell).has(actor), "Location must not expose an extended head as committed Entity position.")
	_expect(movement.is_actor_cell_occupied(target_location.instance_id, head_cell), "LogicalMovement must expose the extended head as hard occupancy.")

	var original_arrivals := entry.arrival_cells.duplicate()
	entry.arrival_cells = [head_cell, fallback_cell]
	var prepared: Dictionary = game.call(
		"_prepare_location_change",
		target_location.instance_id,
		tavern_id,
		edge
	)
	_expect(not prepared.is_empty(), "Location transfer must prepare when a later arrival Cell is free.")
	_expect(prepared.get("spawn_cell") == fallback_cell, "Location transfer must combine static validity with LogicalMovement hard occupancy.")
	var prepared_scene := prepared.get("location") as LocationScene
	if is_instance_valid(prepared_scene):
		prepared_scene.free()
	entry.arrival_cells = original_arrivals
	movement.cancel_move(actor)


func _find_three_open_cells(location: Location) -> Array[Vector2i]:
	for y in range(1, location.definition.grid_size.y - 1):
		for x in range(1, location.definition.grid_size.x - 2):
			var cells: Array[Vector2i] = [
				Vector2i(x, y),
				Vector2i(x + 1, y),
				Vector2i(x + 2, y),
			]
			var all_open := true
			for cell in cells:
				if not location.is_cell_statically_walkable(cell):
					all_open = false
					break
			if all_open:
				return cells
	return []


func _test_names_and_paths() -> void:
	for old_path in [
		"res://scripts/world_definition",
		"res://scripts/world_state",
		"res://scripts/world_time",
		"res://scripts/actions/%s" % ("world_" + "action.gd"),
		"res://scripts/location/grid_space.gd",
		"res://scripts/location/grid_scene.gd",
		"res://data/%s" % ("world_" + "tileset.tres"),
	]:
		_expect(not DirAccess.dir_exists_absolute(old_path) and not FileAccess.file_exists(old_path), "Old path must be removed: %s" % old_path)
	for current_path in [
		"res://scripts/location/location.gd",
		"res://scripts/location/location_registry.gd",
		"res://scripts/location/location_grid_space.gd",
		"res://scripts/location/location_scene.gd",
		"res://scripts/actions/entity_action.gd",
		"res://scripts/state/state_registry.gd",
		"res://scripts/time/game_clock.gd",
		"res://scripts/time/game_time_state.gd",
		"res://scripts/time/game_calendar.gd",
		"res://scripts/initialization/project_world.gd",
		"res://scripts/initialization/project_location_instance_spec.gd",
		"res://data/location_tileset.tres",
	]:
		_expect(FileAccess.file_exists(current_path), "Current V11.3 path must exist: %s" % current_path)
	var location_source := _read_text("res://scripts/location/location.gd")
	var location_registry_source := _read_text("res://scripts/location/location_registry.gd")
	_expect(not location_source.contains("LogicalMovement") and not location_source.contains("movement_runtime"), "Location source must not reference LogicalMovement.")
	_expect(not location_source.contains("select_" + "arrival_cell"), "Location arrival-cell selector must be fully removed.")
	_expect(location_source.contains("entity.get_occupied_grid_cells()"), "Location Cell queries must use committed Entity footprint Cells.")
	_expect(location_registry_source.contains("func has_location("), "LocationRegistry must expose the instance-oriented has_location API.")
	_expect(not location_registry_source.contains("func has("), "LocationRegistry must not retain a duplicate generic has API.")
	_expect(not location_registry_source.contains("func _get("), "LocationRegistry must not retain a duplicate generic get property API.")
	var state_source := _read_text("res://scripts/state/state_registry.gd")
	_expect(not state_source.contains("_active_locations") and not state_source.contains("register_location("), "StateRegistry source must not contain Scene registration.")
	var builder_source := _read_text("res://scripts/location/location_scene_builder.gd")
	_expect(builder_source.contains("LocationGridSpace.cell_to_center_position"), "LocationSceneBuilder must own Entry Cell-to-Pixel conversion.")
	var entity_registry_source := _read_text("res://scripts/entities/entity_registry.gd")
	var logical_movement_source := _read_text("res://scripts/movement/logical_movement.gd")
	_expect(not entity_registry_source.contains("class_name"), "EntityRegistry Autoload must not declare a duplicate global class name.")
	_expect(not logical_movement_source.contains("class_name"), "LogicalMovement Autoload must not declare a duplicate global class name.")
	var actor_representation_source := _read_text("res://scripts/entities/actors/actor_representation.gd")
	_expect(not actor_representation_source.contains("world_" + "position"), "ActorRepresentation must use native global_position directly.")


func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if property["name"] == property_name:
			return true
	return false


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var content := file.get_as_text()
	file.close()
	return content


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("Test failure: %s" % message)


func _finish() -> void:
	if _failures == 0:
		print("V11.3 Location Naming & Responsibility Cleanup: %d checks passed." % _checks)
		quit(0)
		return
	push_error(
		"V11.3 Location Naming & Responsibility Cleanup: %d of %d checks failed."
		% [_failures, _checks]
	)
	quit(1)
