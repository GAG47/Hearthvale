extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const PLAYER_INSTANCE_ID := &"90000000-0000-4000-8000-000000000001"
const CHEST_INSTANCE_ID := &"5543caf7-2a10-4a40-84de-3a39ffdf670e"
const GENERATED_GROUND_DEFINITION_ID := &"c0000000-0000-4000-8000-000000000101"
const GENERATED_LOCATION_DEFINITION_ID := &"c0000000-0000-4000-8000-000000000102"
const GENERATED_LOCATION_INSTANCE_ID := &"c0000000-0000-4000-8000-000000000103"

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
	_test_generated_definition_path(definitions, world_definition, world_state)
	await _test_scene_lifecycle(world_definition, world_state, entities, definitions)
	_test_source_boundaries()
	_finish()


func _test_definition_registry(registry: DefinitionRegistryRuntime) -> void:
	var project_definitions := registry.get_definitions()
	_expect(project_definitions.size() == 30, "Registry must contain all project Actor, Furniture, spatial and Location Definitions.")
	var type_counts: Dictionary[StringName, int] = {}
	for definition in project_definitions:
		_expect(UuidValidator.is_valid_v4(definition.definition_id), "Every Definition must use UUID v4 identity.")
		type_counts[definition.get_definition_type()] = type_counts.get(definition.get_definition_type(), 0) + 1
	_expect(type_counts.get(&"actor", 0) == 2, "ActorDefinitions must use the unified Registry.")
	_expect(type_counts.get(&"furniture", 0) == 3, "FurnitureDefinitions must use the unified Registry.")
	_expect(type_counts.get(&"ground", 0) == 9, "GroundDefinitions must use the unified Registry.")
	_expect(type_counts.get(&"decoration", 0) == 5, "DecorationDefinitions must use the unified Registry.")
	_expect(type_counts.get(&"structure", 0) == 8, "StructureDefinitions must use the unified Registry.")
	_expect(type_counts.get(&"location", 0) == 3, "LocationDefinitions must use the unified Registry.")
	var existing := project_definitions[0]
	_expect(
		not registry.register_generated_definition(existing),
		"Generated and Project Definitions must share one collision-safe UUID namespace."
	)
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
	) as GroundDefinition
	var copied_presentation := ground_definition.presentation
	copied_presentation["atlas_coords"] = [99, 99]
	var stable_atlas: Array = ground_definition.presentation["atlas_coords"]
	_expect(
		stable_atlas.size() == 2 and int(stable_atlas[0]) == 0 and int(stable_atlas[1]) == 0,
		"Registered spatial Definition presentation must remain stable."
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
		_expect(not location.definition.structure_placements.is_empty(), "%s must carry Structure Placements as world data." % key)
		_expect(not location.definition.anchors.is_empty(), "%s must carry spatial Anchors as world data." % key)
		for ground_definition_id in location.definition.ground_layer.values():
			_expect(registry.get_definition(ground_definition_id) is GroundDefinition, "Ground Layer cells must reference GroundDefinitions.")

	var tavern_id := world_definition.get_project_location_id(&"tavern")
	var tavern := world_definition.get_location(tavern_id)
	var multi_cell_placement: StructurePlacement
	for placement in tavern.get_current_structures():
		var structure := registry.get_definition(placement.definition_id) as StructureDefinition
		if structure != null and structure.occupied_cells.size() > 1:
			multi_cell_placement = placement
			break
	_expect(multi_cell_placement != null, "Migrated Tavern must contain a multi-cell StructurePlacement.")
	if multi_cell_placement != null:
		var cells := tavern.get_structure_cells(multi_cell_placement)
		_expect(cells.size() == 2, "Multi-cell footprint must produce every occupied world cell.")
		_expect(cells[1] == cells[0] + Vector2i.RIGHT, "origin_cell + occupied_cells must produce the actual horizontal footprint.")
		var structure := registry.get_definition(multi_cell_placement.definition_id) as StructureDefinition
		var rotated := StructurePlacement.new(
			&"c0000000-0000-4000-8000-000000000104",
			structure.definition_id,
			Vector2i(5, 5),
			90
		)
		_expect(
			rotated.get_world_cells(structure) == [Vector2i(5, 5), Vector2i(5, 6)],
			"Structure orientation must transform the shared footprint around origin_cell."
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
		and state.removed_structure_ids.is_empty()
		and state.added_structures.is_empty()
		and state.removed_decoration_ids.is_empty()
		and state.added_decorations.is_empty()
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
		and serialized_state["ground_overrides"].is_empty(),
		"Serialized LocationState must contain sparse deltas rather than a copied LocationDefinition."
	)

	var cell := Vector2i.ZERO
	var base_ground_id := location.get_ground_definition_id(cell)
	var override_ground_id := &"10000000-0000-4000-8000-000000000003"
	state.ground_overrides[cell] = override_ground_id
	_expect(location.get_ground_definition_id(cell) == override_ground_id, "Ground sparse override must replace the base result.")
	state.ground_overrides.erase(cell)
	_expect(location.get_ground_definition_id(cell) == base_ground_id, "Removing Ground override must reveal Definition data again.")

	var removed_structure := location.definition.structure_placements[0]
	var base_structure_count := location.get_current_structures().size()
	state.removed_structure_ids[removed_structure.placement_id] = true
	_expect(location.get_current_structures().size() == base_structure_count - 1, "removed_structure_ids must subtract Definition placements.")
	state.removed_structure_ids.clear()
	var added_structure := StructurePlacement.new(
		&"c0000000-0000-4000-8000-000000000105",
		removed_structure.definition_id,
		Vector2i(1, 1)
	)
	state.added_structures.append(added_structure)
	_expect(location.get_current_structures().size() == base_structure_count + 1, "added_structures must extend current Structure results without copying Definition data.")
	state.added_structures.clear()

	var removed_decoration := location.definition.decoration_placements[0]
	var base_decoration_count := location.get_current_decorations().size()
	state.removed_decoration_ids[removed_decoration.placement_id] = true
	_expect(location.get_current_decorations().size() == base_decoration_count - 1, "removed_decoration_ids must subtract Definition placements.")
	state.removed_decoration_ids.clear()
	var added_decoration := DecorationPlacement.new(
		&"c0000000-0000-4000-8000-000000000106",
		removed_decoration.definition_id,
		Vector2i(1, 1)
	)
	state.added_decorations.append(added_decoration)
	_expect(location.get_current_decorations().size() == base_decoration_count + 1, "added_decorations must extend current Decoration results.")
	state.added_decorations.clear()

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
	_expect(registry.get_definition(base_ground_id) == location.get_ground_definition(cell), "Runtime queries must resolve semantic IDs through DefinitionRegistry.")


func _test_generated_definition_path(
	registry: DefinitionRegistryRuntime,
	world_definition: WorldDefinitionRuntime,
	world_state: WorldStateRuntime
) -> void:
	var generated_ground := GroundDefinition.new(
		GENERATED_GROUND_DEFINITION_ID,
		&"generated_floor",
		true,
		1.0,
		{
			"kind": "tile",
			"tile_set_path": "res://data/world_tileset.tres",
			"source_id": 0,
			"atlas_coords": [0, 0],
			"alternative_tile": 0,
		}
	)
	_expect(registry.register_generated_definition(generated_ground), "Generated Definition must join the unified Registry.")
	var ground: Dictionary[Vector2i, StringName] = {
		Vector2i(0, 0): GENERATED_GROUND_DEFINITION_ID,
		Vector2i(1, 0): GENERATED_GROUND_DEFINITION_ID,
	}
	var generated_location_definition := LocationDefinition.new(
		GENERATED_LOCATION_DEFINITION_ID,
		"Generated Test Location",
		Vector2i(2, 1),
		[],
		ground
	)
	var generated_state := LocationState.new(
		GENERATED_LOCATION_INSTANCE_ID,
		GENERATED_LOCATION_DEFINITION_ID
	)
	_expect(
		world_definition.register_generated_location(generated_location_definition, generated_state),
		"Generated LocationDefinition must create the same Definition + State runtime path."
	)
	var generated_location := world_definition.get_location(GENERATED_LOCATION_INSTANCE_ID)
	_expect(generated_location != null and generated_location.state == generated_state, "Generated Location must resolve as an ordinary Location Runtime.")
	_expect(generated_location.get_ground_definition(Vector2i(1, 0)) == generated_ground, "Generated Location queries must use the same DefinitionRegistry lookup.")
	_expect(world_state.get_location_state(GENERATED_LOCATION_INSTANCE_ID) == generated_state, "Generated LocationState must be persistent WorldState content.")

	var serialized := registry.serialize_generated_definitions()
	var serialized_location: Dictionary
	for data in serialized:
		if data.get("definition_id", "") == String(GENERATED_LOCATION_DEFINITION_ID):
			serialized_location = data
	_expect(not serialized_location.is_empty(), "Generated LocationDefinition itself must be serializable for World Save.")
	_expect(serialized_location.has("spatial_layout"), "Saved Generated LocationDefinition must contain the generated result, not only a seed.")
	var restored_registry := DefinitionRegistryRuntime.new()
	_expect(restored_registry.restore_generated_definitions(serialized), "Serialized Generated Definitions must restore through the unified codec.")
	_expect(restored_registry.get_definition(GENERATED_LOCATION_DEFINITION_ID) is LocationDefinition, "Restored generated Location must remain an ordinary LocationDefinition.")
	restored_registry.free()

	var prepared := LocationSceneBuilder.new().prepare_scene(
		generated_location,
		EntityRepresentationRegistry.create_default()
	)
	_expect(not prepared.is_empty(), "LocationSceneBuilder must accept generated and project Locations identically.")
	if not prepared.is_empty():
		var scene := prepared["scene"] as GridScene
		_expect((scene.get_node("GroundLayer") as TileMapLayer).get_used_cells().size() == 2, "Generated Location Scene must build from its Ground Layer.")
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
	_expect(first_scene.scene_file_path.is_empty(), "Location Scene must be generated and must not be a fixed map Scene resource.")
	_expect(first_scene.location.definition == tavern_definition and first_scene.location.state == tavern_state, "Scene must represent the composed current Location.")
	_expect((first_scene.get_node("GroundLayer") as TileMapLayer).get_used_cells().size() == 384, "Tavern Ground representation must be generated from 384 data cells.")
	_expect((first_scene.get_node("StructureLayer") as TileMapLayer).get_used_cells().size() == 108, "Tavern Structure representation must rebuild every footprint cell.")
	_expect(first_scene.get_node("DecorationLayer").get_child_count() == 2, "Tavern Decorations must be generated from DecorationDefinitions.")
	_expect(first_scene.get_location_entries().size() == 3, "Entry Anchors must generate Scene entry markers.")
	_expect(first_scene.location.get_entities().size() == 4, "Location Entities must derive from EntityRegistry and EntityState.current_location_id.")
	_expect(first_scene.location.get_entities_at(Vector2i(14, 6)).has(chest), "Cell Entity query must derive the Chest footprint from EntityState.")

	var chest_state := chest.state
	var player_state := player.state
	var first_player_representation := (game.get_node("PlayerController") as PlayerController).controlled_representation
	game.call("request_location_change", &"back_door")
	await _wait_for_transition(game)
	_expect(player.current_location_id == yard_id, "Existing Location transition must work with generated Scenes.")
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
	var game_source := _read_text("res://scripts/game.gd")
	var project_world_source := _read_text("res://data/world/project_world.json")
	_expect(not location_definition_source.contains("scene_path"), "LocationDefinition must not have scene_path authority.")
	_expect(not project_world_source.contains("scene_path"), "Project Location world data must not point at fixed map Scenes.")
	_expect(not game_source.contains("PackedScene") and not game_source.contains("scenes/tavern"), "Game transition must consume LocationSceneBuilder instead of fixed map Scenes.")
	_expect(game_source.contains("LocationSceneBuilder"), "Game Prepare must explicitly use the Location to Scene bridge.")
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
		print("V9 Location-First World Data: %d checks passed." % _checks)
		quit(0)
		return
	push_error("V9 Location-First World Data: %d of %d checks failed." % [_failures, _checks])
	quit(1)
