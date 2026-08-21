extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const NEW_GAME_SETUP: NewGameSetup = preload("res://data/world/new_game_setup.tres")
const PLAYER_DEFINITION: ActorDefinition = preload("res://data/actors/player.tres")
const CHEST_DEFINITION: FurnitureDefinition = preload("res://data/furniture/wooden_chest.tres")
const GRASS: GroundTileDefinition = preload("res://data/tiles/ground/grass.tres")
const INTERIOR_WALL: StructureTileDefinition = preload(
	"res://data/tiles/structure/interior_wall.tres"
)
const WOODEN_FIXTURE: StructureTileDefinition = preload(
	"res://data/tiles/structure/wooden_fixture.tres"
)
const TOP_DOORWAY_LEFT: StructureTileDefinition = preload(
	"res://data/tiles/structure/top_doorway_left.tres"
)
const TOP_DOORWAY_RIGHT: StructureTileDefinition = preload(
	"res://data/tiles/structure/top_doorway_right.tres"
)
const PLAYER_INSTANCE_ID := &"90000000-0000-4000-8000-000000000001"
const CHEST_INSTANCE_ID := &"5543caf7-2a10-4a40-84de-3a39ffdf670e"
const SPARSE_TEST_INSTANCE_ID := &"c0000000-0000-4000-8000-000000000109"
const DECORATION_TEST_INSTANCE_ID := &"c0000000-0000-4000-8000-000000000112"
const TAVERN_ID := &"50000000-0000-4000-8000-000000000001"
const YARD_ID := &"50000000-0000-4000-8000-000000000003"

var _checks := 0
var _failures := 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var game := MAIN_SCENE.instantiate() as Game
	root.add_child(game)
	await process_frame
	await physics_frame
	var location_registry := game.location_registry
	var state_registry := game.state_registry
	var entities := game.entity_registry
	_expect(root.get_node_or_null("DefinitionRegistry") == null, "DefinitionRegistry Autoload must be deleted.")
	_expect(NEW_GAME_SETUP != null and NEW_GAME_SETUP.validate(), "NewGameSetup Resource must validate.")
	_expect(state_registry != null and entities != null, "World runtime registries must exist.")
	if location_registry == null or state_registry == null or entities == null:
		_finish()
		return

	_test_project_resources()
	_test_project_locations(location_registry, state_registry)
	_test_sparse_location_state(location_registry, state_registry, entities)
	_test_scene_builder_current_ground(entities)
	await _test_scene_lifecycle(game, location_registry, state_registry, entities)
	_test_source_boundaries()
	game.end_world()
	game.queue_free()
	await process_frame
	_finish()


func _test_project_resources() -> void:
	_expect(NEW_GAME_SETUP != null and NEW_GAME_SETUP.location_specs.size() == 3, "new_game_setup.tres must contain three Location specs.")
	_expect(DirAccess.get_files_at("res://data/tiles/ground").size() == 9, "Project data must contain nine GroundTileDefinition Resources.")
	_expect(DirAccess.get_files_at("res://data/tiles/decoration").is_empty(), "Project data must not retain Label Decorations as Tile Resources.")
	_expect(DirAccess.get_files_at("res://data/tiles/structure").size() == 10, "Project data must contain ten StructureTileDefinition Resources.")
	for definition in [PLAYER_DEFINITION, CHEST_DEFINITION, GRASS, INTERIOR_WALL]:
		_expect(definition is Resource, "Every Project Definition must directly extend Resource.")
		_expect(not _has_property(definition, &"definition_id"), "Project Definitions must not store UUID identity.")
	_expect(PLAYER_DEFINITION.visual_down is Texture2D, "ActorDefinition must directly reference Texture2D visuals.")
	_expect(CHEST_DEFINITION.visual is Texture2D, "FurnitureDefinition must directly reference its Texture2D.")
	_expect(CHEST_DEFINITION.behaviors[0] is OpenableBehavior, "FurnitureDefinition must store typed Behavior Resources.")
	_expect(GRASS.key == &"grass" and GRASS.walkable and GRASS.source_id == 0, "GroundTileDefinition Resource must preserve explicit Tile fields.")


func _test_project_locations(
	location_registry: LocationRegistry,
	state_registry: StateRegistry
) -> void:
	_expect(state_registry.get_location_states().size() == 3, "New Game initialization must register three LocationStates.")
	var expected_counts := {
		&"tavern": [384, 0, 108, 3, 2],
		&"tavern_yard": [432, 0, 114, 1, 1],
		&"town_street": [792, 0, 284, 1, 1],
	}
	for spec in NEW_GAME_SETUP.location_specs:
		var key := StringName(spec.definition.resource_path.get_file().get_basename())
		var instance_id := spec.instance_id
		var state := state_registry.get_location_state(instance_id)
		var location := location_registry.get_location(instance_id)
		var counts: Array = expected_counts[key]
		_expect(UuidValidator.is_valid_v4(instance_id), "%s Location instance must retain UUID identity." % key)
		_expect(state != null and state.instance_id == instance_id, "%s LocationState must retain only instance identity." % key)
		_expect(not _has_property(state, &"definition_id"), "LocationState must not store a Definition UUID.")
		_expect(location != null and location.definition == spec.definition, "%s Runtime must directly use its New Game LocationDefinition Resource." % key)
		_expect(spec.definition.resource_path == "res://data/locations/%s.tres" % key, "%s spec must reference its standalone LocationDefinition Resource." % key)
		_expect(spec.definition.ground_layer.size() == counts[0], "%s Ground Layer count must be preserved." % key)
		_expect(spec.definition.decoration_layer.size() == counts[1], "%s Decoration Layer count must be preserved." % key)
		_expect(spec.definition.structure_layer.size() == counts[2], "%s Structure Layer count must be preserved." % key)
		_expect(spec.definition.entries.size() == counts[3], "%s Entries must be preserved." % key)
		_expect(spec.definition.exits.size() == counts[4], "%s Exits must be preserved." % key)
		for tile in spec.definition.ground_layer.values():
			_expect(tile is GroundTileDefinition and not tile.resource_path.is_empty(), "Ground Cells must directly reference standalone GroundTileDefinition Resources.")
		for tile in spec.definition.decoration_layer.values():
			_expect(tile is DecorationTileDefinition and not tile.resource_path.is_empty(), "Decoration Cells must directly reference standalone DecorationTileDefinition Resources.")
		for tile in spec.definition.structure_layer.values():
			_expect(tile is StructureTileDefinition and not tile.resource_path.is_empty(), "Structure Cells must directly reference standalone StructureTileDefinition Resources.")

	var tavern_id := TAVERN_ID
	var tavern := location_registry.get_location(tavern_id)
	_expect(
		tavern.get_structure_tile(Vector2i(11, 0)) == TOP_DOORWAY_LEFT
		and tavern.get_structure_tile(Vector2i(12, 0)) == TOP_DOORWAY_RIGHT,
		"Each Tavern doorway Cell must directly reference its own StructureTileDefinition Resource."
	)
	_expect(tavern.definition.outgoing_edges[0] is LocationEdgeDefinition, "Location edges must load as internal Resources.")
	_expect(tavern.definition.entries[0] is LocationEntry, "Location entries must load as internal Resources.")
	_expect(tavern.definition.exits[0] is LocationExit, "Location exits must load as internal Resources.")


func _test_sparse_location_state(
	location_registry: LocationRegistry,
	state_registry: StateRegistry,
	entity_registry: EntityRegistry
) -> void:
	var tavern_id := TAVERN_ID
	var state := state_registry.get_location_state(tavern_id)
	var location := location_registry.get_location(tavern_id)
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

	var cell := Vector2i.ZERO
	var base_ground := location.get_ground_tile(cell)
	state.ground_overrides[cell] = GRASS
	_expect(location.get_ground_tile(cell) == GRASS, "Ground Cell override must directly replace the base Resource.")
	state.ground_overrides[cell] = null
	_expect(location.get_ground_tile(cell) == null, "A null Ground Cell override must remove the current Tile.")
	state.ground_overrides.erase(cell)
	_expect(location.get_ground_tile(cell) == base_ground, "Removing Ground override must reveal the Definition Resource again.")

	var structure_cell: Vector2i = location.definition.structure_layer.keys()[0]
	var base_structure := location.get_structure_tile(structure_cell)
	var replacement := WOODEN_FIXTURE if base_structure != WOODEN_FIXTURE else INTERIOR_WALL
	state.structure_overrides[structure_cell] = replacement
	_expect(location.get_structure_tile(structure_cell) == replacement, "Structure Cell override must directly replace the base Resource.")
	state.structure_overrides[structure_cell] = null
	_expect(location.get_structure_tile(structure_cell) == null, "A null Structure Cell override must remove the current Tile.")
	_expect(not location.get_current_structure_layer().has(structure_cell), "Removed Structure Cells must be absent from the current Layer.")
	state.structure_overrides.erase(structure_cell)
	_expect(location.get_structure_tile(structure_cell) == base_structure, "Removing a Structure override must reveal Definition data again.")

	_test_decoration_cell_override(entity_registry)

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
		YARD_ID,
		&"tavern_entrance"
	)
	state.added_edges.append(added_edge)
	_expect(location.get_edge(&"state_added_edge") == added_edge, "added_edges must extend current Topology.")
	state.added_edges.clear()


func _test_decoration_cell_override(entity_registry: EntityRegistry) -> void:
	var decoration := DecorationTileDefinition.new()
	decoration.key = &"test_decoration"
	decoration.source_id = 0
	decoration.atlas_coords = Vector2i(4, 0)
	var definition := LocationDefinition.new()
	definition.display_name = "Decoration Override Test"
	definition.grid_size = Vector2i.ONE
	definition.decoration_layer[Vector2i.ZERO] = decoration
	var state := LocationState.new(DECORATION_TEST_INSTANCE_ID)
	var location := Location.new(definition, state, entity_registry)
	_expect(location.get_decoration_tile(Vector2i.ZERO) == decoration, "Decoration Layer must expose its direct Cell Resource.")
	state.decoration_overrides[Vector2i.ZERO] = null
	_expect(location.get_decoration_tile(Vector2i.ZERO) == null, "A null Decoration Cell override must remove the current Tile.")
	state.decoration_overrides.erase(Vector2i.ZERO)
	_expect(location.get_decoration_tile(Vector2i.ZERO) == decoration, "Removing a Decoration override must reveal Definition data again.")


func _test_scene_builder_current_ground(entity_registry: EntityRegistry) -> void:
	var definition := LocationDefinition.new()
	definition.display_name = "Sparse Ground Test"
	definition.grid_size = Vector2i(2, 1)
	var state := LocationState.new(SPARSE_TEST_INSTANCE_ID)
	var override_cell := Vector2i(1, 0)
	state.ground_overrides[override_cell] = GRASS
	var location := Location.new(definition, state, entity_registry)
	_expect(location.get_current_ground_layer().get(override_cell) == GRASS, "Current Ground must directly expose a sparse override Resource.")
	var prepared := LocationSceneBuilder.new().prepare_scene(location, EntityRepresentationRegistry.create_default())
	_expect(not prepared.is_empty(), "SceneBuilder must accept Current Ground supplied by Location.")
	if prepared.is_empty():
		return
	var scene := prepared["scene"] as LocationScene
	var ground_layer := scene.get_node("GroundLayer") as TileMapLayer
	_expect(ground_layer.get_used_cells() == [override_cell], "SceneBuilder must render a Ground override Cell absent from Definition Ground.")
	_expect(ground_layer.tile_set == LocationSceneBuilder.LOCATION_TILE_SET, "Ground Layer must use the fixed Location TileSet.")
	scene.free()


func _test_scene_lifecycle(
	game: Game,
	location_registry: LocationRegistry,
	state_registry: StateRegistry,
	entity_registry: EntityRegistry
) -> void:
	var tavern_id := TAVERN_ID
	var yard_id := YARD_ID
	var tavern_definition := location_registry.get_location(tavern_id).definition
	var tavern_state := state_registry.get_location_state(tavern_id)
	var player := entity_registry.get_entity(PLAYER_INSTANCE_ID) as Actor
	var chest := entity_registry.get_entity(CHEST_INSTANCE_ID) as Furniture
	var first_scene := game.get("current_location") as LocationScene
	_expect(player != null and player.definition == PLAYER_DEFINITION, "Actor must directly hold its Project ActorDefinition Resource.")
	_expect(chest != null and chest.definition == CHEST_DEFINITION, "Furniture must directly hold its Project FurnitureDefinition Resource.")
	_expect(not _has_property(player.state, &"definition_id"), "EntityState must not store a Definition UUID.")
	_expect(first_scene.scene_file_path.is_empty(), "Location Scene must be built at runtime rather than loaded as a fixed map Scene.")
	_expect(first_scene.location.definition == tavern_definition and first_scene.location.state == tavern_state, "Scene must represent the composed current Location.")
	_expect((first_scene.get_node("GroundLayer") as TileMapLayer).get_used_cells().size() == 384, "Tavern Ground representation must be built from 384 Resource cells.")
	_expect((first_scene.get_node("StructureLayer") as TileMapLayer).get_used_cells().size() == 108, "Tavern Structure representation must be built from 108 Resource cells.")
	_expect((first_scene.get_node("DecorationLayer") as TileMapLayer).get_used_cells().is_empty(), "Tavern Decoration Tile Layer must remain empty.")
	_expect(
		first_scene.get_node_or_null("Entry" + "Points") == null
		and first_scene.get_node_or_null("Exit_front_door") == null,
		"LocationEntry and LocationExit must remain logical data without Scene nodes."
	)
	_expect(
		first_scene.location.get_exit_at(Vector2i(11, 0)).edge_key == &"front_door",
		"Location must resolve an Exit from a committed logical Cell."
	)
	_expect(first_scene.location.get_entities().size() == 4, "Location Entities must derive from EntityRegistry and EntityState.current_location_id.")
	_expect(first_scene.location.get_entities_at(Vector2i(14, 6)).has(chest), "Cell Entity query must derive the Chest footprint from EntityState.")
	var player_cell := player.current_cell
	_expect(first_scene.location.is_cell_walkable(player_cell), "A default non-blocking Entity must not make its Cell unwalkable.")
	var chest_cell := chest.state.local_cell
	chest.state.local_cell = player_cell
	_expect(not first_scene.location.is_cell_walkable(player_cell), "Location walkability must consume Furniture blocking through its Definition Resource.")
	chest.state.local_cell = chest_cell

	var chest_representation := _find_representation(first_scene, CHEST_INSTANCE_ID)
	_expect(chest_representation != null, "The initial Scene must contain the Chest Representation.")
	if chest_representation != null:
		chest_representation.free()
	var saved_player_cell := player.state.local_cell
	var player_facing := player.facing
	player.state.local_cell = Vector2i(13, 6)
	(player.state as ActorState).facing = ActorState.Facing.RIGHT
	var controller := game.get_node("PlayerController") as PlayerController
	_expect(controller.call("_select_interaction").get("entity") == chest, "Interaction must query Location Entities even when the target Representation is absent.")
	player.state.local_cell = saved_player_cell
	(player.state as ActorState).facing = player_facing

	var chest_state := chest.state
	var player_state := player.state
	var first_player_representation := (game.get_node("PlayerController") as PlayerController).controlled_representation
	game.call("request_location_change", &"back_door")
	await _wait_for_transition(game)
	_expect(player.current_location_id == yard_id, "Existing Location transition must work with Resource-built Locations.")
	_expect(not is_instance_valid(first_scene) and not is_instance_valid(first_player_representation), "Leaving must unload only Scene representations.")
	_expect(location_registry.get_location(tavern_id).definition == tavern_definition, "LocationDefinition Resource must survive Scene unload.")
	_expect(state_registry.get_location_state(tavern_id) == tavern_state, "LocationState must survive Scene unload.")
	_expect(player.state == player_state and chest.state == chest_state, "Entities and EntityStates must survive Scene unload.")

	var yard_scene := game.get("current_location") as LocationScene
	game.call("request_location_change", &"tavern_door")
	await _wait_for_transition(game)
	var rebuilt_scene := game.get("current_location") as LocationScene
	_expect(rebuilt_scene != first_scene and rebuilt_scene.location_id == tavern_id, "Re-entry must build a fresh Scene from current Location data.")
	_expect(not is_instance_valid(yard_scene), "Re-entry Commit must unload the previous representation.")
	_expect(rebuilt_scene.location.state == tavern_state, "Rebuilt Scene must reuse the persistent sparse LocationState.")
	_expect(_find_representation(rebuilt_scene, CHEST_INSTANCE_ID) is FurnitureRepresentation, "EntityRepresentationFactory must rebuild Furniture representation.")


func _test_source_boundaries() -> void:
	var game_source := _read_text("res://scripts/game.gd")
	var location_source := _read_text("res://scripts/location/location.gd")
	var location_registry_source := _read_text("res://scripts/location/location_registry.gd")
	var entity_state_source := _read_text("res://scripts/entities/entity_state.gd")
	var new_game_setup_source := _read_text("res://data/world/new_game_setup.tres")
	for old_path in [
		"res://scripts/definitions/definition.gd",
		"res://scripts/definitions/definition_registry.gd",
		"res://scripts/entities/actors/actor_definition_loader.gd",
		"res://scripts/entities/furniture/furniture_definition_loader.gd",
		"res://scripts/location_registry/project_world_data_loader.gd",
		"res://data/world/project_world.json",
		"res://data/actors/player.json",
		"res://data/furniture/wooden_chest.json",
	]:
		_expect(not FileAccess.file_exists(old_path), "Resource migration must delete '%s'." % old_path)
	_expect(not game_source.contains("DefinitionRegistry") and not game_source.contains("DefinitionLoader"), "Game must directly consume Project Definition Resources.")
	_expect(not location_source.contains("DefinitionRegistry") and not location_source.contains("definition_id"), "Location must directly consume TileDefinition Resources.")
	_expect(not location_registry_source.contains("DefinitionRegistry") and not location_registry_source.contains("definition_id"), "LocationRegistry must remain a pure runtime index.")
	_expect(not entity_state_source.contains("definition_id"), "EntityState must not persist Definition identity.")
	_expect(new_game_setup_source.contains("data/locations/tavern.tres"), "NewGameSetup Resource must directly reference LocationDefinition Resources.")
	_expect(not game_source.contains("uid://") and not location_registry_source.contains("ResourceUID"), "Business code must not manually store or resolve Resource UID strings.")


func _find_representation(location: LocationScene, instance_id: StringName) -> Node:
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
	for _frame in range(60):
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
		print("Project Definition Resources: %d checks passed." % _checks)
		quit(0)
		return
	push_error("Project Definition Resources: %d of %d checks failed." % [_failures, _checks])
	quit(1)
