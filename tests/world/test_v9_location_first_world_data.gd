extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const PLAYER_INSTANCE_ID := &"90000000-0000-4000-8000-000000000001"
const CHEST_INSTANCE_ID := &"5543caf7-2a10-4a40-84de-3a39ffdf670e"
const SPARSE_TEST_DEFINITION_ID := &"c0000000-0000-4000-8000-000000000108"
const SPARSE_TEST_INSTANCE_ID := &"c0000000-0000-4000-8000-000000000109"
const DECORATION_TEST_DEFINITION_ID := &"c0000000-0000-4000-8000-000000000110"
const DECORATION_TEST_LOCATION_ID := &"c0000000-0000-4000-8000-000000000111"
const DECORATION_TEST_INSTANCE_ID := &"c0000000-0000-4000-8000-000000000112"
var _checks := 0
var _failures := 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var definitions := root.get_node_or_null("DefinitionRegistry") as DefinitionRegistryRuntime
	var world_definition := root.get_node_or_null("WorldDefinition") as WorldDefinitionRuntime
	var world_state := root.get_node_or_null("WorldState") as WorldStateRuntime
	var entities := root.get_node_or_null("EntityRegistry") as EntityRegistryRuntime
	_expect(definitions != null, "DefinitionRegistry Autoload must exist.")
	_expect(world_definition != null and world_definition.definitions_valid, "Project world data must validate.")
	_expect(world_state != null and entities != null, "World runtime registries must exist.")
	if definitions == null or world_definition == null or world_state == null or entities == null:
		_finish()
		return

	_test_definition_registry(definitions)
	_test_project_locations(world_definition, world_state, definitions)
	_test_sparse_location_state(world_definition, world_state, definitions)
	_test_scene_builder_current_ground(definitions, entities)
	await _test_scene_lifecycle(world_definition, world_state, entities, definitions)
	_test_source_boundaries()
	_finish()


func _test_definition_registry(registry: DefinitionRegistryRuntime) -> void:
	var project_definitions := registry.get_definitions()
	_expect(project_definitions.size() == 27, "Registry must contain all project Actor, Furniture, spatial Tile and Location Definitions.")
	var type_counts: Dictionary[StringName, int] = {}
	for definition in project_definitions:
		_expect(UuidValidator.is_valid_v4(definition.definition_id), "Every Definition must use UUID v4 identity.")
		type_counts[definition.get_definition_type()] = type_counts.get(definition.get_definition_type(), 0) + 1
	_expect(type_counts.get(&"actor", 0) == 2, "ActorDefinitions must use the unified Registry.")
	_expect(type_counts.get(&"furniture", 0) == 3, "FurnitureDefinitions must use the unified Registry.")
	_expect(type_counts.get(&"ground_tile", 0) == 9, "GroundTileDefinitions must use the unified Registry.")
	_expect(type_counts.get(&"decoration_tile", 0) == 0, "Project data must not retain Label Decorations as Tile Definitions.")
	_expect(type_counts.get(&"structure_tile", 0) == 10, "StructureTileDefinitions must use the unified Registry.")
	_expect(type_counts.get(&"location", 0) == 3, "LocationDefinitions must use the unified Registry.")
	for definition in project_definitions:
		if definition is GroundTileDefinition or definition is StructureTileDefinition:
			_expect(not _has_property(definition, &"presentation"), "Spatial Tile Definitions must expose explicit Tile fields.")
			_expect(definition.source_id >= 0, "Spatial Tile Definitions must select a source in the fixed TileSet.")
	var player_definition := registry.get_definition(
		&"5e05b833-0645-4c13-8713-4c8767a7efe3"
	) as ActorDefinition
	var copied_visuals := player_definition.visuals
	copied_visuals["down"] = "changed-outside-definition"
	_expect(
		player_definition.visuals["down"] == "res://assets/actors/player_down.svg",
		"Definition collection data must not be mutable through consumer copies."
	)
	var ground_definition := registry.get_definition(
		&"10000000-0000-4000-8000-000000000001"
	) as GroundTileDefinition
	_expect(
		ground_definition.key == &"wood_floor"
		and ground_definition.walkable
		and ground_definition.movement_cost == 1.0
		and ground_definition.source_id == 0
		and ground_definition.atlas_coords == Vector2i.ZERO
		and ground_definition.alternative_tile == 0,
		"GroundTileDefinition must expose only its explicit logical and fixed-TileSet fields."
	)


func _test_project_locations(
	world_definition: WorldDefinitionRuntime,
	world_state: WorldStateRuntime,
	registry: DefinitionRegistryRuntime
) -> void:
	_expect(world_state.get_location_states().size() == 3, "Project world must create three LocationStates.")
	for key in [&"tavern", &"town_street", &"tavern_yard"]:
		var instance_id := world_definition.get_project_location_id(key)
		var state := world_state.get_location_state(instance_id)
		var location := world_definition.get_location(instance_id)
		_expect(UuidValidator.is_valid_v4(instance_id), "%s Location instance must use UUID v4." % key)
		_expect(state != null and UuidValidator.is_valid_v4(state.definition_id), "%s LocationState must reference a Definition UUID." % key)
		_expect(location != null and location.definition.definition_id == state.definition_id, "%s Runtime must compose matching Definition + State." % key)
		_expect(location.definition.grid_size.x * location.definition.grid_size.y == location.definition.ground_layer.size(), "%s Ground Layer must fully describe the grid." % key)
		_expect(not location.definition.structure_layer.is_empty(), "%s must carry direct Structure Layer cells as world data." % key)
		_expect(not location.definition.entries.is_empty(), "%s must carry direct LocationEntries." % key)
		_expect(not location.definition.exits.is_empty(), "%s must carry direct LocationExits." % key)
		for tile_definition_id in location.definition.ground_layer.values():
			_expect(registry.get_definition(tile_definition_id) is GroundTileDefinition, "Ground Layer cells must reference GroundTileDefinitions.")
		for tile_definition_id in location.definition.decoration_layer.values():
			_expect(registry.get_definition(tile_definition_id) is DecorationTileDefinition, "Decoration Layer cells must reference DecorationTileDefinitions.")
		for tile_definition_id in location.definition.structure_layer.values():
			_expect(registry.get_definition(tile_definition_id) is StructureTileDefinition, "Structure Layer cells must reference StructureTileDefinitions.")

	var tavern_id := world_definition.get_project_location_id(&"tavern")
	var tavern := world_definition.get_location(tavern_id)
	var top_left := tavern.get_structure_tile(Vector2i(11, 0))
	var top_right := tavern.get_structure_tile(Vector2i(12, 0))
	_expect(
		top_left != null
		and top_left.key == &"top_doorway_left"
		and top_right != null
		and top_right.key == &"top_doorway_right",
		"Each Tavern doorway Cell must directly select its own StructureTileDefinition."
	)


func _test_sparse_location_state(
	world_definition: WorldDefinitionRuntime,
	world_state: WorldStateRuntime,
	registry: DefinitionRegistryRuntime
) -> void:
	var tavern_id := world_definition.get_project_location_id(&"tavern")
	var state := world_state.get_location_state(tavern_id)
	var location := world_definition.get_location(tavern_id)
	_expect(
		state.ground_overrides.is_empty()
		and state.decoration_overrides.is_empty()
		and state.structure_overrides.is_empty()
		and state.removed_edge_ids.is_empty()
		and state.disabled_edge_ids.is_empty()
		and state.added_edges.is_empty(),
		"Unchanged LocationState must remain sparse and small."
	)
	_expect(not _has_property(state, &"entity_ids") and not _has_property(state, &"entity_positions"), "LocationState must not duplicate Entity membership or positions.")
	var serialized_state := state.to_data()
	_expect(
		not serialized_state.has("spatial_layout")
		and not serialized_state.has("ground_layer")
		and serialized_state["ground_overrides"].is_empty()
		and serialized_state["decoration_overrides"].is_empty()
		and serialized_state["structure_overrides"].is_empty(),
		"Serialized LocationState must contain sparse deltas rather than a copied LocationDefinition."
	)

	var cell := Vector2i.ZERO
	var base_ground_id := location.get_ground_tile_definition_id(cell)
	var override_ground_id := &"10000000-0000-4000-8000-000000000003"
	state.ground_overrides[cell] = override_ground_id
	_expect(location.get_ground_tile_definition_id(cell) == override_ground_id, "Ground Cell override must replace the base result.")
	state.ground_overrides.erase(cell)
	_expect(location.get_ground_tile_definition_id(cell) == base_ground_id, "Removing Ground override must reveal Definition data again.")

	var structure_cell: Vector2i = location.definition.structure_layer.keys()[0]
	var base_structure_id := location.get_structure_tile_definition_id(structure_cell)
	var replacement_structure_id := &"20000000-0000-4000-8000-000000000001"
	if replacement_structure_id == base_structure_id:
		replacement_structure_id = &"20000000-0000-4000-8000-000000000002"
	state.structure_overrides[structure_cell] = replacement_structure_id
	_expect(location.get_structure_tile_definition_id(structure_cell) == replacement_structure_id, "Structure Cell override must replace the base result.")
	state.structure_overrides[structure_cell] = &""
	_expect(location.get_structure_tile(structure_cell) == null, "An empty Structure Cell override must remove the current Tile.")
	_expect(not location.get_current_structure_layer().has(structure_cell), "Removed Structure Cells must be absent from the current Layer.")
	state.structure_overrides.erase(structure_cell)
	_expect(location.get_structure_tile_definition_id(structure_cell) == base_structure_id, "Removing a Structure override must reveal Definition data again.")

	_test_decoration_cell_override()

	var edge := location.get_current_edges()[0]
	state.disabled_edge_ids[edge.edge_id] = true
	_expect(location.get_edge(edge.edge_key) == null, "disabled_edge_ids must remove an edge from current Topology queries.")
	state.disabled_edge_ids.clear()
	_expect(location.get_edge(edge.edge_key) == edge, "Clearing a sparse edge override must restore Definition Topology.")
	state.removed_edge_ids[edge.edge_id] = true
	_expect(location.get_edge(edge.edge_key) == null, "removed_edge_ids must subtract Definition Topology edges.")
	state.removed_edge_ids.clear()
	var added_edge := LocationEdgeDefinition.new(
		&"c0000000-0000-4000-8000-000000000107",
		&"state_added_edge",
		world_definition.get_project_location_id(&"tavern_yard"),
		&"tavern_entrance"
	)
	state.added_edges.append(added_edge)
	_expect(location.get_edge(&"state_added_edge") == added_edge, "added_edges must extend current Topology.")
	state.added_edges.clear()
	_expect(registry.get_definition(base_ground_id) == location.get_ground_tile(cell), "Runtime queries must resolve semantic IDs through DefinitionRegistry.")


func _test_decoration_cell_override() -> void:
	var registry := DefinitionRegistryRuntime.new()
	var entities := EntityRegistryRuntime.new()
	var decoration := DecorationTileDefinition.new(
		DECORATION_TEST_DEFINITION_ID,
		&"test_decoration",
		0,
		Vector2i(4, 0),
		0
	)
	_expect(registry.register_project_definition(decoration), "Decoration override fixture must register its Tile Definition.")
	var decoration_layer: Dictionary[Vector2i, StringName] = {
		Vector2i.ZERO: DECORATION_TEST_DEFINITION_ID,
	}
	var definition := LocationDefinition.new(
		DECORATION_TEST_LOCATION_ID,
		"Decoration Override Test",
		Vector2i.ONE,
		[],
		{},
		decoration_layer
	)
	var state := LocationState.new(DECORATION_TEST_INSTANCE_ID, DECORATION_TEST_LOCATION_ID)
	var location := LocationRuntime.new(definition, state, registry, entities)
	_expect(location.get_decoration_tile(Vector2i.ZERO) == decoration, "Decoration Layer must resolve its direct Cell Tile.")
	state.decoration_overrides[Vector2i.ZERO] = &""
	_expect(location.get_decoration_tile(Vector2i.ZERO) == null, "An empty Decoration Cell override must remove the current Tile.")
	state.decoration_overrides.erase(Vector2i.ZERO)
	_expect(location.get_decoration_tile(Vector2i.ZERO) == decoration, "Removing a Decoration override must reveal Definition data again.")
	registry.free()
	entities.free()


func _test_scene_builder_current_ground(
	registry: DefinitionRegistryRuntime,
	entity_registry: EntityRegistryRuntime
) -> void:
	var definition := LocationDefinition.new(
		SPARSE_TEST_DEFINITION_ID,
		"Sparse Ground Test",
		Vector2i(2, 1)
	)
	var state := LocationState.new(SPARSE_TEST_INSTANCE_ID, SPARSE_TEST_DEFINITION_ID)
	var override_cell := Vector2i(1, 0)
	state.ground_overrides[override_cell] = &"10000000-0000-4000-8000-000000000003"
	var location := LocationRuntime.new(definition, state, registry, entity_registry)
	_expect(
		location.get_current_ground_layer().has(override_cell),
		"Current Ground must include a sparse override Cell absent from the Definition."
	)
	var prepared := LocationSceneBuilder.new().prepare_scene(
		location,
		EntityRepresentationRegistry.create_default()
	)
	_expect(not prepared.is_empty(), "SceneBuilder must accept Current Ground supplied by LocationRuntime.")
	if prepared.is_empty():
		return
	var scene := prepared["scene"] as GridScene
	var ground_layer := scene.get_node("GroundLayer") as TileMapLayer
	_expect(
		ground_layer.get_used_cells() == [override_cell],
		"SceneBuilder must render a Ground override Cell absent from Definition Ground."
	)
	_expect(
		ground_layer.tile_set == LocationSceneBuilder.WORLD_TILE_SET,
		"Ground Layer must use the fixed World TileSet."
	)
	scene.free()


func _test_scene_lifecycle(
	world_definition: WorldDefinitionRuntime,
	world_state: WorldStateRuntime,
	entity_registry: EntityRegistryRuntime,
	definition_registry: DefinitionRegistryRuntime
) -> void:
	var tavern_id := world_definition.get_project_location_id(&"tavern")
	var yard_id := world_definition.get_project_location_id(&"tavern_yard")
	var tavern_definition := world_definition.get_location_definition(tavern_id)
	var tavern_state := world_state.get_location_state(tavern_id)
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var player := entity_registry.get_entity(PLAYER_INSTANCE_ID) as Actor
	var chest := entity_registry.get_entity(CHEST_INSTANCE_ID) as Furniture
	var first_scene := game.get("current_location") as GridScene
	_expect(player != null and player.instance_id != player.definition_id, "Entity instance UUID must be independent from Definition UUID.")
	_expect(player.state.definition_id == player.definition.definition_id, "EntityState must explicitly link the instance to its Definition.")
	_expect(player.definition == definition_registry.get_definition(player.definition_id), "Entity must consume its Project Definition through DefinitionRegistry.")
	_expect(chest != null and chest.definition == definition_registry.get_definition(chest.definition_id), "Furniture must use the same Definition resolution path.")
	_expect(first_scene.scene_file_path.is_empty(), "Location Scene must be built at runtime and must not be a fixed map Scene resource.")
	_expect(first_scene.location.definition == tavern_definition and first_scene.location.state == tavern_state, "Scene must represent the composed current Location.")
	_expect((first_scene.get_node("GroundLayer") as TileMapLayer).get_used_cells().size() == 384, "Tavern Ground representation must be built from 384 data cells.")
	_expect((first_scene.get_node("StructureLayer") as TileMapLayer).get_used_cells().size() == 108, "Tavern Structure representation must be built from 108 direct data cells.")
	_expect((first_scene.get_node("DecorationLayer") as TileMapLayer).get_used_cells().is_empty(), "Removed Label Decorations must leave the Tavern Decoration Tile Layer empty.")
	_expect(first_scene.get_node("EntryPoints").get_child_count() == 3, "LocationEntries must generate Scene entry markers.")
	_expect(first_scene.get_node_or_null("Exit_front_door") is LocationExitArea, "LocationExits must generate Scene exit trigger areas.")
	_expect(first_scene.location.get_entities().size() == 4, "Location Entities must derive from EntityRegistry and EntityState.current_location_id.")
	_expect(first_scene.location.get_entities_at(Vector2i(14, 6)).has(chest), "Cell Entity query must derive the Chest footprint from EntityState.")
	_expect(not player.blocks_movement(), "Entity must not block movement by default.")
	_expect(chest.blocks_movement(), "Furniture must expose its Definition blocking rule through Entity.")
	var player_cell := player.current_cell
	_expect(first_scene.location.is_cell_walkable(player_cell), "A default non-blocking Entity must not make its Cell unwalkable.")
	var chest_position := chest.state.local_position
	chest.state.local_position = GridSpace.cell_to_local_position(
		player_cell,
		Vector2.ONE * GridSpace.CELL_SIZE * 0.5
	)
	_expect(not first_scene.location.is_cell_walkable(player_cell), "Location walkability must consume Entity blocking capability.")
	chest.state.local_position = chest_position

	var chest_representation := _find_representation(first_scene, CHEST_INSTANCE_ID)
	_expect(chest_representation != null, "The initial Scene must contain the Chest Representation.")
	if chest_representation != null:
		chest_representation.free()
	var player_position := player.state.local_position
	var player_facing := player.facing
	player.state.local_position = GridSpace.cell_to_local_position(
		Vector2i(13, 6),
		Vector2.ONE * GridSpace.CELL_SIZE * 0.5
	)
	(player.state as ActorState).facing = ActorState.Facing.RIGHT
	_expect(
		InteractionTargetSelector.select_target(player) == chest,
		"Interaction must query Location Entities even when the target Representation is absent."
	)
	player.state.local_position = player_position
	(player.state as ActorState).facing = player_facing

	var chest_state := chest.state
	var player_state := player.state
	var first_player_representation := (game.get_node("PlayerController") as PlayerController).controlled_representation
	game.call("request_location_change", &"back_door")
	await _wait_for_transition(game)
	_expect(player.current_location_id == yard_id, "Existing Location transition must work with runtime-built Scenes.")
	_expect(not is_instance_valid(first_scene) and not is_instance_valid(first_player_representation), "Leaving must unload only Scene representations.")
	_expect(world_definition.get_location_definition(tavern_id) == tavern_definition, "LocationDefinition must survive Scene unload.")
	_expect(world_state.get_location_state(tavern_id) == tavern_state, "LocationState must survive Scene unload.")
	_expect(player.state == player_state and chest.state == chest_state, "Entities and EntityStates must survive Scene unload.")

	var yard_scene := game.get("current_location") as GridScene
	game.call("request_location_change", &"tavern_door")
	await _wait_for_transition(game)
	var rebuilt_scene := game.get("current_location") as GridScene
	_expect(rebuilt_scene != first_scene and rebuilt_scene.location_id == tavern_id, "Re-entry must build a fresh Scene from current Location data.")
	_expect(not is_instance_valid(yard_scene), "Re-entry Commit must unload the previous representation.")
	_expect(rebuilt_scene.location.state == tavern_state, "Rebuilt Scene must reuse the persistent sparse LocationState.")
	_expect(_find_representation(rebuilt_scene, CHEST_INSTANCE_ID) is FurnitureRepresentation, "EntityRepresentationFactory must rebuild Furniture representation under LocationSceneBuilder.")
	game.queue_free()
	await process_frame


func _test_source_boundaries() -> void:
	var location_definition_source := _read_text("res://scripts/world_definition/location_definition.gd")
	var location_state_source := _read_text("res://scripts/location/location_state.gd")
	var game_source := _read_text("res://scripts/game.gd")
	var project_world_source := _read_text("res://data/world/project_world.json")
	var project_loader_source := _read_text("res://scripts/world_definition/project_world_data_loader.gd")
	var selector_source := _read_text("res://scripts/interaction_target_selector.gd")
	var grid_scene_source := _read_text("res://scripts/location/grid_scene.gd")
	var location_source := _read_text("res://scripts/location/location.gd")
	var scene_builder_source := _read_text("res://scripts/location/location_scene_builder.gd")
	var registry_source := _read_text("res://scripts/definitions/definition_registry.gd")
	var world_definition_source := _read_text("res://scripts/world_definition/world_definition.gd")
	_expect(not location_definition_source.contains("scene_path"), "LocationDefinition must not have scene_path authority.")
	_expect(not project_world_source.contains("scene_path"), "Project Location world data must not point at fixed map Scenes.")
	_expect(not game_source.contains("PackedScene") and not game_source.contains("scenes/tavern"), "Game transition must consume LocationSceneBuilder instead of fixed map Scenes.")
	_expect(game_source.contains("LocationSceneBuilder"), "Game Prepare must explicitly use the Location to Scene bridge.")
	_expect(
		selector_source.contains("get_entities_at")
		and not selector_source.contains("Representation")
		and not selector_source.contains("GridScene"),
		"Interaction target selection must only query logical Location Entities."
	)
	_expect(
		not grid_scene_source.contains("FurnitureRepresentation"),
		"GridScene must not retain an interaction target Representation index."
	)
	_expect(
		not location_source.contains("entity is Furniture")
		and location_source.contains("entity.blocks_movement()"),
		"Location walkability must use the unified Entity blocking interface."
	)
	_expect(
		not scene_builder_source.contains("location.definition.ground_layer")
		and not scene_builder_source.contains("tile_set_path")
		and scene_builder_source.contains("WORLD_TILE_SET"),
		"SceneBuilder must consume Current Location and fixed Layer TileSets."
	)
	for old_script in [
		"res://scripts/world_definition/ground_definition.gd",
		"res://scripts/world_definition/decoration_definition.gd",
		"res://scripts/world_definition/structure_definition.gd",
		"res://scripts/world_definition/decoration_placement.gd",
		"res://scripts/world_definition/structure_placement.gd",
		"res://scripts/world_definition/location_anchor.gd",
		"res://scripts/world_definition/location_entry_anchor.gd",
		"res://scripts/world_definition/location_exit_anchor.gd",
	]:
		_expect(not FileAccess.file_exists(old_script), "V9.1 must delete obsolete spatial model script '%s'." % old_script)
	_expect(
		not location_definition_source.contains("Placement")
		and not location_definition_source.contains("Anchor")
		and not location_state_source.contains("added_structures")
		and not location_state_source.contains("removed_structure_ids")
		and not location_state_source.contains("added_decorations")
		and not location_state_source.contains("removed_decoration_ids")
		and not location_source.contains("Placement")
		and not location_source.contains("Anchor"),
		"Location Definition, State and Runtime must not retain Placement or Anchor compatibility paths."
	)
	_expect(
		not project_loader_source.contains(".presentation")
		and not scene_builder_source.contains(".presentation")
		and not scene_builder_source.contains("Label.new")
		and not project_world_source.contains("tile_set_path"),
		"Tile loading and Scene building must use explicit fixed-TileSet fields without Label branches."
	)
	for forbidden_world_data in [
		"decoration_placements", "structure_placements", "placement_id", "origin_cell",
		"orientation", "occupied_cells", "anchors", "local_offset", "presentation",
		"hall_label", "kitchen_label", "tavern_label", "street_label", "yard_label",
	]:
		_expect(not project_world_source.contains(forbidden_world_data), "Project Location data must not retain '%s'." % forbidden_world_data)
	_expect(
		not registry_source.to_lower().contains("generated")
		and not world_definition_source.to_lower().contains("generated"),
		"V9 runtime registries must not retain Generated Definition or Location paths."
	)
	_expect(
		not FileAccess.file_exists("res://scripts/definitions/definition_codec.gd"),
		"V9 must not retain a generic Definition persistence Codec."
	)
	for forbidden in ["fingerprint", "bake cache", "Location Baking", "Scene Placement Baking"]:
		_expect(not game_source.contains(forbidden) and not location_definition_source.contains(forbidden), "V9 must not reintroduce a Scene baking route.")


func _find_representation(location: GridScene, instance_id: StringName) -> Node:
	var representation_root := location.get_node_or_null("EntityRepresentationRoot")
	if representation_root == null:
		return null
	for child in representation_root.get_children():
		if child.has_method("get_entity"):
			var entity := child.call("get_entity") as Entity
			if entity != null and entity.instance_id == instance_id:
				return child
	return null


func _wait_for_transition(game: Node) -> void:
	for _frame in range(10):
		await process_frame
		await physics_frame
		if not game.get("transition_in_progress"):
			return


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
		print("V9.1 Location Spatial Layout: %d checks passed." % _checks)
		quit(0)
		return
	push_error("V9.1 Location Spatial Layout: %d of %d checks failed." % [_failures, _checks])
	quit(1)
