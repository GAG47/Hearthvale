extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const PLAYER_DEFINITION: ActorDefinition = preload("res://data/actors/player.tres")
const MARTHA_DEFINITION: ActorDefinition = preload("res://data/actors/martha.tres")
const GRASS: GroundTileDefinition = preload("res://data/tiles/ground/grass.tres")

var _checks := 0
var _failures := 0
var _world_definition: WorldDefinitionRuntime
var _world_state: WorldStateRuntime
var _registry: EntityRegistryRuntime
var _movement: LogicalMovementRuntime


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_world_definition = root.get_node_or_null("WorldDefinition") as WorldDefinitionRuntime
	_world_state = root.get_node_or_null("WorldState") as WorldStateRuntime
	_registry = root.get_node_or_null("EntityRegistry") as EntityRegistryRuntime
	_movement = root.get_node_or_null("LogicalMovement") as LogicalMovementRuntime
	_expect(_world_definition != null, "V11 tests require WorldDefinition.")
	_expect(_world_state != null, "V11 tests require WorldState.")
	_expect(_registry != null, "V11 tests require EntityRegistry.")
	_expect(_movement != null, "V11 tests require LogicalMovement.")
	if _world_definition == null or _world_state == null or _registry == null or _movement == null:
		_finish()
		return
	_movement.set_physics_process(false)
	_movement.cancel_all()

	_test_single_actor_continuous_movement()
	_test_astar_movement_cost()
	_test_astar_blocking_entity()
	_test_independent_move_speeds()
	_test_stable_same_cell_conflict()
	_test_priority_inheritance_chain()
	_test_backtracking_to_alternate_candidate()
	_test_external_actor_blocking_and_resume()
	_test_arrival_cell_claim_selection()
	await _test_scene_unload_and_rebuild()
	await _test_location_transfer_arrival_cells()
	_finish()


func _test_single_actor_continuous_movement() -> void:
	_movement.cancel_all()
	var location_id := &"c1000000-0000-4000-8000-000000000001"
	_create_location(location_id, Vector2i(6, 3))
	var offset := Vector2(7.0, 11.0)
	var start_position := GridSpace.cell_to_local_position(Vector2i(1, 1), offset)
	var actor := _create_actor(
		&"c2000000-0000-4000-8000-000000000001",
		location_id,
		start_position,
		32.0
	)
	_expect(_movement.request_move(actor, Vector2i(3, 1)), "A valid Actor movement request must be accepted.")
	_expect(_movement.get_actor_phase(actor) == ActorMovementRequest.Phase.CONTRACTED, "A new Movement Request must begin contracted.")
	_expect(_movement.get_actor_occupied_cells(actor) == [Vector2i(1, 1)], "Contracted occupancy must contain only tail.")

	_movement.advance(0.0)
	var request := _movement.get_request(actor)
	_expect(request != null and request.phase == ActorMovementRequest.Phase.REQUESTING, "The planning phase must expose requesting before movement approval.")
	_expect(_movement.get_actor_occupied_cells(actor) == [Vector2i(1, 1)], "Requesting occupancy must still contain only tail.")

	_movement.advance(0.0)
	request = _movement.get_request(actor)
	_expect(request != null and request.phase == ActorMovementRequest.Phase.EXTENDED, "An approved step must enter extended.")
	_expect(request != null and request.tail_cell == Vector2i(1, 1) and request.head_cell == Vector2i(2, 1), "A* must recommend the next cardinal path Cell.")
	_expect(_movement.get_actor_occupied_cells(actor) == [Vector2i(1, 1), Vector2i(2, 1)], "Extended occupancy must contain tail and head.")
	_expect(actor.local_position == start_position, "Approving a step must not teleport ActorState.")

	_movement.advance(0.25)
	_expect(actor.local_position == start_position + Vector2(8.0, 0.0), "Logical movement must advance through a continuous Vector2 position.")
	_expect(_movement.get_actor_occupied_cells(actor) == [Vector2i(1, 1), Vector2i(2, 1)], "Extended movement must retain tail after crossing no completion boundary.")
	_movement.advance(0.6)
	_expect(actor.current_cell == Vector2i(2, 1), "Continuous local_position may cross into head before the logical step completes.")
	_expect(_movement.get_actor_occupied_cells(actor) == [Vector2i(1, 1), Vector2i(2, 1)], "Extended occupancy must retain tail even after local_position crosses the Cell boundary.")
	_advance_until_complete(actor, 1.0)
	_expect(actor.local_position == start_position + Vector2(64.0, 0.0), "Each approved step must preserve the Actor's original in-Cell offset.")
	_expect(actor.current_cell == Vector2i(3, 1), "A single Actor must reach its target Cell.")
	_expect(not _movement.is_participant(actor), "A completed Movement Request must clear its movement priority.")
	_expect(_movement.get_actor_occupied_cells(actor) == [Vector2i(3, 1)], "Completion must release the old tail and occupy only the new Cell.")
	_expect(_movement.request_move(actor, Vector2i(4, 1)), "A follow-up request must be accepted before cancellation.")
	_movement.cancel_move(actor)
	_expect(not _movement.is_participant(actor), "Cancelling a Movement Request must clear its participant and priority state.")
	_expect(_movement.get_actor_occupied_cells(actor) == [Vector2i(3, 1)], "Cancellation must return occupancy to the Actor's current Cell.")


func _test_astar_movement_cost() -> void:
	_movement.cancel_all()
	var location_id := &"c1000000-0000-4000-8000-000000000010"
	var location := _create_location(location_id, Vector2i(4, 3))
	for costly_cell in [Vector2i(1, 1), Vector2i(2, 1)]:
		var costly_ground := GRASS.duplicate(true) as GroundTileDefinition
		costly_ground.movement_cost = 20.0
		location.definition.ground_layer[costly_cell] = costly_ground
	var actor := _create_actor(
		&"c2000000-0000-4000-8000-000000000080",
		location_id,
		_cell_position(Vector2i(0, 1)),
		32.0
	)
	_expect(_movement.request_move(actor, Vector2i(3, 1)), "Movement-cost route request must be accepted.")
	_movement.advance(0.0)
	var request := _movement.get_request(actor)
	_expect(request != null and request.head_cell != Vector2i(1, 1), "AStarGrid2D must prefer a lower-cost detour over costly Ground.")


func _test_astar_blocking_entity() -> void:
	_movement.cancel_all()
	var location_id := &"c1000000-0000-4000-8000-000000000011"
	var location := _create_location(location_id, Vector2i(5, 3))
	var blocked_cell := Vector2i(2, 1)
	_create_blocking_furniture(
		&"c3000000-0000-4000-8000-000000000001",
		location_id,
		_cell_position(blocked_cell)
	)
	var actor := _create_actor(
		&"c2000000-0000-4000-8000-000000000081",
		location_id,
		_cell_position(Vector2i(1, 1)),
		64.0
	)
	_expect(not location.is_cell_statically_walkable(blocked_cell, actor), "A blocking Furniture footprint must be a static navigation obstacle.")
	_expect(_movement.request_move(actor, Vector2i(3, 1)), "A route around blocking Furniture must be accepted.")
	_movement.advance(0.0)
	var request := _movement.get_request(actor)
	_expect(request != null and request.head_cell != blocked_cell, "AStarGrid2D must route around blocking Furniture from LocationRuntime.")
	_advance_until_complete(actor, 1.0)
	_expect(actor.current_cell == Vector2i(3, 1), "A logical Actor must reach its target around a blocking Entity.")


func _test_independent_move_speeds() -> void:
	_movement.cancel_all()
	var location_id := &"c1000000-0000-4000-8000-000000000002"
	_create_location(location_id, Vector2i(4, 3))
	var slow := _create_actor(
		&"c2000000-0000-4000-8000-000000000002",
		location_id,
		_cell_position(Vector2i(0, 0)),
		32.0
	)
	var fast := _create_actor(
		&"c2000000-0000-4000-8000-000000000003",
		location_id,
		_cell_position(Vector2i(0, 2)),
		64.0
	)
	_expect(_movement.request_move(slow, Vector2i(1, 0)), "Slow Actor request must be accepted.")
	_expect(_movement.request_move(fast, Vector2i(1, 2)), "Fast Actor request must be accepted.")
	_movement.advance(0.0)
	_movement.advance(0.0)
	_movement.advance(0.5)
	_expect(slow.local_position.x == _cell_position(Vector2i(0, 0)).x + 16.0, "Slow Actor must remain mid-step after half a second.")
	_expect(_movement.get_actor_phase(slow) == ActorMovementRequest.Phase.EXTENDED, "Slow Actor must stay extended until its own step completes.")
	_expect(fast.local_position == _cell_position(Vector2i(1, 2)), "Fast Actor must complete the same Cell independently.")
	_expect(not _movement.is_participant(fast), "Fast Actor completion must not wait for slower participants.")


func _test_stable_same_cell_conflict() -> void:
	_movement.cancel_all()
	var location_id := &"c1000000-0000-4000-8000-000000000003"
	_create_location(location_id, Vector2i(5, 3))
	var first := _create_actor(
		&"c2000000-0000-4000-8000-000000000010",
		location_id,
		_cell_position(Vector2i(1, 1)),
		32.0
	)
	var second := _create_actor(
		&"c2000000-0000-4000-8000-000000000011",
		location_id,
		_cell_position(Vector2i(3, 1)),
		32.0
	)
	_expect(_movement.request_move(second, Vector2i(2, 1)), "Second same-target request must be accepted.")
	_expect(_movement.request_move(first, Vector2i(2, 1)), "First same-target request must be accepted in the same movement clock.")
	_movement.advance(0.0)
	_movement.advance(0.0)
	var first_request := _movement.get_request(first)
	var second_request := _movement.get_request(second)
	_expect(first_request != null and first_request.head_cell == Vector2i(2, 1), "Same-start conflict must use stable instance UUID as the base priority tiebreaker.")
	_expect(second_request != null and second_request.head_cell != Vector2i(2, 1), "Two Actors must never receive the same head Cell.")


func _test_priority_inheritance_chain() -> void:
	_movement.cancel_all()
	var location_id := &"c1000000-0000-4000-8000-000000000004"
	_create_location(location_id, Vector2i(5, 1))
	var first := _create_actor(&"c2000000-0000-4000-8000-000000000020", location_id, _cell_position(Vector2i(0, 0)), 32.0)
	var second := _create_actor(&"c2000000-0000-4000-8000-000000000021", location_id, _cell_position(Vector2i(1, 0)), 16.0)
	var third := _create_actor(&"c2000000-0000-4000-8000-000000000022", location_id, _cell_position(Vector2i(2, 0)), 32.0)
	_expect(_movement.request_move(first, Vector2i(4, 0)), "First dependency request must be accepted.")
	_expect(_movement.request_move(second, Vector2i(4, 0)), "Second dependency request must be accepted.")
	_expect(_movement.request_move(third, Vector2i(4, 0)), "Third dependency request must be accepted.")
	_movement.advance(0.0)
	_movement.advance(0.0)
	var first_request := _movement.get_request(first)
	var second_request := _movement.get_request(second)
	var third_request := _movement.get_request(third)
	_expect(first_request.head_cell == Vector2i(1, 0), "Dependency chain root must contract the occupied preferred Cell.")
	_expect(second_request.head_cell == Vector2i(2, 0), "Priority inheritance must move the first blocker forward.")
	_expect(third_request.head_cell == Vector2i(3, 0), "Priority inheritance must propagate through the dependency chain.")
	_expect(second_request.effective_priority_instance_id == first.instance_id, "Blocked Actor must temporarily inherit the root priority.")
	_expect(third_request.effective_priority_instance_id == first.instance_id, "Inherited priority must propagate to downstream blockers.")
	_expect(first_request.phase == ActorMovementRequest.Phase.REQUESTING, "The chain root must remain requesting while its head Cell is still occupied.")
	_expect(second_request.phase == ActorMovementRequest.Phase.REQUESTING, "An intermediate dependency must remain requesting until the downstream tail is released.")
	_expect(third_request.phase == ActorMovementRequest.Phase.EXTENDED, "Only the unblocked dependency leaf may enter extended first.")
	_expect(_actor_occupancies_do_not_overlap([first, second, third]), "Causal dependency planning must not create overlapping phase occupancy.")
	_movement.advance(1.0)
	first_request = _movement.get_request(first)
	second_request = _movement.get_request(second)
	_expect(first_request.phase == ActorMovementRequest.Phase.REQUESTING, "The root must continue waiting while the intermediate Actor moves.")
	_expect(second_request.phase == ActorMovementRequest.Phase.EXTENDED, "The intermediate Actor may extend only after the leaf releases its tail.")
	_expect(_actor_occupancies_do_not_overlap([first, second, third]), "Causal dependency promotion must preserve unique occupancy after the leaf completes.")
	_movement.advance(1.0)
	first_request = _movement.get_request(first)
	second_request = _movement.get_request(second)
	_expect(first_request.phase == ActorMovementRequest.Phase.REQUESTING, "A faster upstream Actor must wait for a slower extended dependency to finish.")
	_expect(second_request.phase == ActorMovementRequest.Phase.EXTENDED, "A slower dependency must retain tail and head for its own full duration.")
	_expect(_actor_occupancies_do_not_overlap([first, second, third]), "Independent move speeds must not collapse the causal dependency order.")
	_movement.advance(1.0)
	first_request = _movement.get_request(first)
	_expect(first_request.phase == ActorMovementRequest.Phase.EXTENDED, "The root may extend only after the intermediate Actor releases its tail.")
	_expect(_actor_occupancies_do_not_overlap([first, second, third]), "Different dependency completion times must never overlap logical occupancy.")


func _test_backtracking_to_alternate_candidate() -> void:
	_movement.cancel_all()
	var location_id := &"c1000000-0000-4000-8000-000000000005"
	_create_location(
		location_id,
		Vector2i(4, 3),
		[Vector2i(2, 0), Vector2i(2, 2), Vector2i(3, 1)]
	)
	var first := _create_actor(&"c2000000-0000-4000-8000-000000000030", location_id, _cell_position(Vector2i(1, 1)), 32.0)
	var blocker := _create_actor(&"c2000000-0000-4000-8000-000000000031", location_id, _cell_position(Vector2i(2, 1)), 32.0)
	_expect(_movement.request_move(first, Vector2i(2, 1)), "Backtracking root request must be accepted.")
	_expect(_movement.request_move(blocker, Vector2i(0, 1)), "Backtracking blocker request must be accepted.")
	_movement.advance(0.0)
	_movement.advance(0.0)
	var first_request := _movement.get_request(first)
	_expect(first_request != null and first_request.head_cell == Vector2i(1, 0), "A failed dependency candidate must backtrack to the next A*-ranked neighbor.")
	_expect(first_request.head_cell != Vector2i(2, 1), "Backtracking must not keep the blocked preferred head.")


func _test_external_actor_blocking_and_resume() -> void:
	_movement.cancel_all()
	var detour_location_id := &"c1000000-0000-4000-8000-000000000006"
	_create_location(detour_location_id, Vector2i(5, 3))
	var external := _create_actor(&"c2000000-0000-4000-8000-000000000040", detour_location_id, _cell_position(Vector2i(2, 1)), 140.0)
	var npc := _create_actor(&"c2000000-0000-4000-8000-000000000041", detour_location_id, _cell_position(Vector2i(1, 1)), 32.0)
	_movement.set_actor_externally_controlled(external, true)
	var external_position := external.local_position
	_expect(not _movement.request_move(external, Vector2i(3, 1)), "Externally controlled Actor must not become a PIBT participant.")
	_expect(_movement.request_move(npc, Vector2i(3, 1)), "NPC request around an external Actor must be accepted.")
	_movement.advance(0.0)
	var npc_request := _movement.get_request(npc)
	_expect(npc_request != null and npc_request.head_cell == external.current_cell, "Dynamic Actors must not become permanent walls in the static A* grid.")
	_movement.advance(0.0)
	npc_request = _movement.get_request(npc)
	_expect(npc_request != null and npc_request.head_cell != external.current_cell, "NPC must not enter or push an externally controlled Actor's Cell.")
	_expect(npc_request != null and npc_request.head_cell != npc_request.tail_cell, "NPC may use another legal candidate around an external Actor.")
	_expect(external.local_position == external_position, "PIBT must never move the externally controlled Actor.")

	_movement.cancel_all()
	var wait_location_id := &"c1000000-0000-4000-8000-000000000007"
	_create_location(wait_location_id, Vector2i(4, 1))
	var corridor_external := _create_actor(&"c2000000-0000-4000-8000-000000000042", wait_location_id, _cell_position(Vector2i(1, 0)), 140.0)
	var corridor_npc := _create_actor(&"c2000000-0000-4000-8000-000000000043", wait_location_id, _cell_position(Vector2i(0, 0)), 32.0)
	_movement.set_actor_externally_controlled(corridor_external, true)
	_expect(_movement.request_move(corridor_npc, Vector2i(3, 0)), "Corridor NPC request must be accepted.")
	_movement.advance(0.0)
	_movement.advance(0.0)
	var corridor_request := _movement.get_request(corridor_npc)
	_expect(corridor_request != null and corridor_request.phase == ActorMovementRequest.Phase.REQUESTING, "NPC with no available candidate must WAIT without entering extended.")
	_expect(_movement.get_actor_occupied_cells(corridor_npc) == [Vector2i(0, 0)], "Waiting NPC must occupy only its tail.")
	corridor_external.state.local_position = _cell_position(Vector2i(2, 0))
	_movement.advance(0.0)
	corridor_request = _movement.get_request(corridor_npc)
	_expect(corridor_request != null and corridor_request.phase == ActorMovementRequest.Phase.EXTENDED, "NPC must continue once the external Actor leaves the blocking Cell.")
	_expect(corridor_request != null and corridor_request.head_cell == Vector2i(1, 0), "Resumed NPC must contract the newly available next Cell.")


func _test_arrival_cell_claim_selection() -> void:
	_movement.cancel_all()
	var location_id := &"c1000000-0000-4000-8000-000000000008"
	var location := _create_location(location_id, Vector2i(4, 3))
	var claimant := _create_actor(&"c2000000-0000-4000-8000-000000000050", location_id, _cell_position(Vector2i(0, 1)), 32.0)
	var entry := LocationEntry.new(
		&"multi_arrival",
		[Vector2i(1, 1), Vector2i(2, 1)],
		ActorState.Facing.RIGHT
	)
	_expect(_movement.request_move(claimant, Vector2i(1, 1)), "Arrival claim movement request must be accepted.")
	_movement.advance(0.0)
	var request := _movement.get_request(claimant)
	_expect(request != null and request.phase == ActorMovementRequest.Phase.REQUESTING, "Arrival claim test requires a requesting head claim.")
	var selected := location.select_arrival_cell(entry)
	_expect(selected.get("cell") == Vector2i(2, 1), "Arrival selection must skip a requesting movement claim and preserve Definition order.")


func _test_scene_unload_and_rebuild() -> void:
	_movement.cancel_all()
	var location_id := &"c1000000-0000-4000-8000-000000000009"
	var location := _create_location(location_id, Vector2i(6, 3))
	var actor := _create_actor(&"c2000000-0000-4000-8000-000000000060", location_id, _cell_position(Vector2i(1, 1)), 32.0)
	var first_scene := _build_location_scene(location)
	_expect(first_scene != null, "A logical movement Location Scene must build.")
	if first_scene == null:
		return
	root.add_child(first_scene)
	await process_frame
	await physics_frame
	var first_representation := _find_actor_representation(first_scene, actor.instance_id)
	_expect(first_representation != null, "Loaded logical Actor must have an ActorRepresentation.")
	_expect(_movement.request_move(actor, Vector2i(4, 1)), "Off-screen continuity request must be accepted.")
	_movement.advance(0.0)
	_movement.advance(0.0)
	_movement.advance(0.5)
	await physics_frame
	_expect(first_representation != null and first_representation.position == actor.local_position, "Loaded Representation must follow logical ActorState.")

	first_scene.queue_free()
	await process_frame
	var unloaded_position := actor.local_position
	_movement.advance(1.0)
	_movement.advance(0.0)
	_movement.advance(1.0)
	_expect(actor.local_position != unloaded_position, "Logical movement must continue without a Location Scene.")
	var second_scene := _build_location_scene(location)
	_expect(second_scene != null, "Location Scene must rebuild after off-screen movement.")
	if second_scene == null:
		return
	root.add_child(second_scene)
	await process_frame
	await physics_frame
	var second_representation := _find_actor_representation(second_scene, actor.instance_id)
	_expect(second_representation != null and second_representation.position == actor.local_position, "Rebuilt Representation must start from the current ActorState position.")
	second_scene.queue_free()
	await process_frame


func _test_location_transfer_arrival_cells() -> void:
	_movement.cancel_all()
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var controller := game.get_node("PlayerController") as PlayerController
	var player := controller.controlled_actor
	_expect(player is Actor, "PlayerController must control an ordinary Actor.")
	_expect(is_equal_approx(player.definition.move_speed, PLAYER_DEFINITION.move_speed), "Player movement must consume ActorDefinition.move_speed.")
	_expect(not _has_property(controller, &"move_speed"), "PlayerController must not own a second base move_speed.")
	_expect(not _has_property(player.definition, &"is_player"), "ActorDefinition must not store Player identity.")
	_expect(not _has_property(player.state, &"is_player"), "ActorState must not store Player identity.")
	_expect(_movement.is_actor_externally_controlled(player), "Player-controlled Actor must register as external movement control.")

	var tavern_id := _world_definition.get_project_location_id(&"tavern")
	var yard_id := _world_definition.get_project_location_id(&"tavern_yard")
	var yard := _world_definition.get_location(yard_id)
	var entry := yard.get_entry(&"tavern_entrance")
	var original_arrivals: Array[Vector2i] = entry.arrival_cells.duplicate()
	var first_cell: Vector2i = original_arrivals[0]
	var second_cell := _find_alternate_arrival_cell(yard, first_cell)
	entry.arrival_cells = [first_cell, second_cell]
	var first_blocker := _create_actor(&"c2000000-0000-4000-8000-000000000070", yard_id, _cell_position(first_cell), 32.0)
	var edge := _world_definition.get_edge(tavern_id, &"back_door")
	var prepared: Dictionary = game.call("_prepare_location_change", yard_id, tavern_id, edge)
	_expect(not prepared.is_empty(), "Transfer Prepare must use a later arrival Cell when the first is occupied.")
	_expect(prepared.get("spawn_position") == GridSpace.cell_to_local_position(second_cell), "Transfer Prepare must choose the first currently legal arrival Cell in order.")
	if not prepared.is_empty():
		(prepared["location"] as GridScene).free()

	var second_blocker := _create_actor(&"c2000000-0000-4000-8000-000000000071", yard_id, _cell_position(second_cell), 32.0)
	var rejected: Dictionary = game.call("_prepare_location_change", yard_id, tavern_id, edge)
	_expect(rejected.is_empty(), "Transfer Prepare must reject when every arrival Cell is occupied.")
	_expect(player.current_location_id == tavern_id, "Rejected transfer must not migrate the controlled Actor.")
	_expect(first_blocker.current_cell == first_cell and second_blocker.current_cell == second_cell, "Rejected transfer must not push or overlap arrival blockers.")
	entry.arrival_cells = original_arrivals
	game.queue_free()
	await process_frame
	_expect(not _movement.is_actor_externally_controlled(player), "PlayerController exit must clear external movement control.")


func _create_location(
	location_id: StringName,
	grid_size: Vector2i,
	blocked_cells: Array[Vector2i] = []
) -> LocationRuntime:
	var definition := LocationDefinition.new()
	definition.display_name = "V11 Test Location"
	definition.grid_size = grid_size
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			definition.ground_layer[Vector2i(x, y)] = GRASS
	for cell in blocked_cells:
		var blocker := StructureTileDefinition.new()
		blocker.blocks_movement = true
		definition.structure_layer[cell] = blocker
	var definitions: Dictionary = _world_definition.get("_definitions_by_location")
	definitions[location_id] = definition
	_expect(_world_state.register_location_state(LocationState.new(location_id)), "V11 test LocationState must register.")
	var location := _world_definition.get_location(location_id)
	_expect(location != null, "V11 test LocationRuntime must resolve.")
	return location


func _create_actor(
	instance_id: StringName,
	location_id: StringName,
	position: Vector2,
	move_speed: float
) -> Actor:
	var definition := MARTHA_DEFINITION.duplicate(true) as ActorDefinition
	definition.move_speed = move_speed
	var state := ActorState.new(instance_id, location_id, position, ActorState.Facing.DOWN)
	var actor := Actor.new(definition, state)
	_expect(_world_state.register_entity_state(state), "V11 test ActorState must register.")
	_expect(_registry.register_entity(actor), "V11 test Actor must register.")
	return actor


func _create_blocking_furniture(
	instance_id: StringName,
	location_id: StringName,
	position: Vector2
) -> Furniture:
	var definition := FurnitureDefinition.new()
	definition.display_name = "V11 Blocking Furniture"
	definition.footprint_cells = [Vector2i.ZERO]
	definition.blocks_movement = true
	var state := FurnitureState.new(instance_id, location_id, position)
	var furniture := Furniture.new(definition, state)
	_expect(_world_state.register_entity_state(state), "V11 test FurnitureState must register.")
	_expect(_registry.register_entity(furniture), "V11 test blocking Furniture must register.")
	return furniture


func _build_location_scene(location: LocationRuntime) -> GridScene:
	var prepared := LocationSceneBuilder.new().prepare_scene(
		location,
		EntityRepresentationRegistry.create_default()
	)
	if prepared.is_empty():
		return null
	var scene := prepared["scene"] as GridScene
	if not scene.prepare_activation(_world_state, location):
		scene.free()
		return null
	return scene


func _find_actor_representation(
	location_scene: GridScene,
	instance_id: StringName
) -> ActorRepresentation:
	var representation_root := location_scene.get_node_or_null("EntityRepresentationRoot")
	if representation_root == null:
		return null
	for child in representation_root.get_children():
		if child is ActorRepresentation and (child as ActorRepresentation).instance_id == instance_id:
			return child as ActorRepresentation
	return null


func _find_alternate_arrival_cell(
	location: LocationRuntime,
	first_cell: Vector2i
) -> Vector2i:
	var directions: Array[Vector2i] = [
		Vector2i.RIGHT,
		Vector2i.LEFT,
		Vector2i.DOWN,
		Vector2i.UP,
	]
	for direction in directions:
		var cell: Vector2i = first_cell + direction
		if location.is_cell_statically_walkable(cell):
			return cell
	return first_cell


func _advance_until_complete(actor: Actor, delta: float) -> void:
	for _step in range(20):
		if not _movement.is_participant(actor):
			return
		_movement.advance(delta)


func _cell_position(cell: Vector2i) -> Vector2:
	return GridSpace.cell_to_local_position(cell, Vector2(8.0, 12.0))


func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if property["name"] == property_name:
			return true
	return false


func _actor_occupancies_do_not_overlap(actors: Array) -> bool:
	var occupied: Dictionary[Vector2i, bool] = {}
	for actor: Actor in actors:
		for cell in _movement.get_actor_occupied_cells(actor):
			if occupied.has(cell):
				return false
			occupied[cell] = true
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("Test failure: %s" % message)


func _finish() -> void:
	if _failures == 0:
		print("V11 Logical Actor Movement: %d checks passed." % _checks)
		quit(0)
		return
	push_error("V11 Logical Actor Movement: %d of %d checks failed." % [_failures, _checks])
	quit(1)
