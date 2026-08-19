extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const MARTHA_DEFINITION: ActorDefinition = preload("res://data/actors/martha.tres")
const GRASS: GroundTileDefinition = preload("res://data/tiles/ground/grass.tres")
const PLAYER_INSTANCE_ID := &"90000000-0000-4000-8000-000000000001"
const CHEST_INSTANCE_ID := &"5543caf7-2a10-4a40-84de-3a39ffdf670e"

var _checks := 0
var _failures := 0
var _location_registry: LocationRegistry
var _state_registry: StateRegistry
var _registry: EntityRegistryRuntime
var _movement: LogicalMovementRuntime


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_location_registry = root.get_node_or_null("LocationRegistry") as LocationRegistry
	_state_registry = root.get_node_or_null("StateRegistry") as StateRegistry
	_registry = root.get_node_or_null("EntityRegistry") as EntityRegistryRuntime
	_movement = root.get_node_or_null("LogicalMovement") as LogicalMovementRuntime
	_expect(_location_registry != null, "V11.2 tests require LocationRegistry.")
	_expect(_state_registry != null, "V11.2 tests require StateRegistry.")
	_expect(_registry != null, "V11.2 tests require EntityRegistry.")
	_expect(_movement != null, "V11.2 tests require LogicalMovement.")
	if _location_registry == null or _state_registry == null or _registry == null or _movement == null:
		_finish()
		return
	_movement.set_physics_process(false)
	_movement.cancel_all()

	_test_cell_authority_contract()
	_test_formal_grid_step_and_occupancy()
	_test_direction_intent_continuity_and_latest_input()
	await _test_player_controller_uses_logical_movement()
	_test_npc_astar_candidates_and_long_distance_alignment()
	_test_same_head_conflict()
	_test_priority_inheritance_chain()
	_test_backtracking_and_request_cycle()
	_test_independent_move_speeds()
	await _test_scene_unload_and_rebuild()
	_test_no_formal_martha_initialization()
	_test_removed_resolver_mechanisms()
	_finish()


func _test_cell_authority_contract() -> void:
	var state := ActorState.new(
		&"d2000000-0000-4000-8000-000000000000",
		&"d1000000-0000-4000-8000-000000000000",
		Vector2i(7, 9),
		ActorState.Facing.DOWN
	)
	var actor := Actor.new(MARTHA_DEFINITION, state)
	_expect(state.local_cell == Vector2i(7, 9), "EntityState must store its logical position as Vector2i local_cell.")
	_expect(not _has_property(state, &"local_position"), "EntityState must not retain local_position as a second logical authority.")
	_expect(actor.current_cell == state.local_cell, "Entity.current_cell must directly expose the committed EntityState.local_cell.")


func _test_formal_grid_step_and_occupancy() -> void:
	_movement.cancel_all()
	var location_id := &"d1000000-0000-4000-8000-000000000001"
	var location := _create_location(location_id, Vector2i(5, 3))
	var actor := _create_actor(
		&"d2000000-0000-4000-8000-000000000001",
		location_id,
		Vector2i(1, 1),
		64.0
	)
	_expect(
		not _movement.request_step(actor, Vector2i(1, 1)),
		"A direction Movement Intent must reject diagonal movement."
	)
	_expect(
		_movement.request_step(actor, Vector2i.RIGHT),
		"A cardinal single-Cell Movement Intent must be accepted."
	)
	var request := _movement.get_request(actor)
	_expect(
		request != null and request.phase == ActorMovementRequest.Phase.CONTRACTED,
		"A new participant must begin contracted."
	)
	_expect(
		_movement.get_actor_occupied_cells(actor) == [Vector2i(1, 1)],
		"contracted occupancy must contain only tail."
	)
	_expect(actor.state.local_cell == Vector2i(1, 1), "contracted ActorState.local_cell must equal tail.")

	_movement.call("_activate_contracted", request)
	_expect(
		request.phase == ActorMovementRequest.Phase.REQUESTING
		and request.tail_cell == Vector2i(1, 1)
		and request.head_cell == Vector2i(2, 1),
		"The first formal activation must request exactly one cardinal neighbor."
	)
	_expect(
		_movement.get_actor_occupied_cells(actor) == [Vector2i(1, 1)],
		"requesting occupancy must contain only tail."
	)
	_expect(
		actor.state.local_cell == Vector2i(1, 1) and actor.current_cell == Vector2i(1, 1),
		"requesting must leave the committed logical Cell at tail."
	)
	_expect(
		not _movement.is_actor_cell_occupied(location_id, request.head_cell),
		"A requesting head must remain an intention rather than hard occupancy."
	)
	var entry := LocationEntry.new(
		&"requesting_head_entry",
		[request.head_cell, Vector2i(3, 1)],
		ActorState.Facing.RIGHT
	)
	_expect(
		location.select_arrival_cell(entry).get("cell") == request.head_cell,
		"Location Entry must not reject a Cell only because it is a requesting head."
	)

	_movement.call("_activate_requesting", request)
	_expect(
		request.phase == ActorMovementRequest.Phase.EXTENDED,
		"An unoccupied requested neighbor must enter extended on the next activation."
	)
	_expect(
		_movement.get_actor_occupied_cells(actor) == [Vector2i(1, 1), Vector2i(2, 1)],
		"extended occupancy must contain both tail and head."
	)
	_expect(
		is_equal_approx(request.step_duration, 0.5)
		and is_zero_approx(request.step_elapsed)
		and is_zero_approx(request.get_step_progress()),
		"An extended request must expose elapsed, duration, and normalized progress."
	)
	_expect(
		location.select_arrival_cell(entry).get("cell") == request.head_cell,
		"Location static arrival validation must not include transient Actor occupancy."
	)
	_expect(
		_movement.is_actor_cell_occupied(location_id, request.head_cell),
		"LogicalMovement must report the extended head as hard Actor occupancy."
	)

	for progress_delta in [0.125, 0.125, 0.245]:
		_movement.advance(progress_delta)
		_expect(
			request.phase == ActorMovementRequest.Phase.EXTENDED
			and actor.state.local_cell == Vector2i(1, 1)
			and actor.current_cell == Vector2i(1, 1),
			"At 25%%, 50%%, and 99%% progress the committed logical Cell must remain tail."
		)
		_expect(
			_movement.get_actor_occupied_cells(actor) == [Vector2i(1, 1), Vector2i(2, 1)],
			"Every incomplete extended progress point must retain tail-and-head hard occupancy."
		)
	_expect(is_equal_approx(request.get_step_progress(), 0.99), "Step progress must derive from elapsed divided by duration.")
	_movement.advance(0.01)
	_expect(
		actor.state.local_cell == Vector2i(2, 1) and actor.current_cell == Vector2i(2, 1),
		"A completed step must commit ActorState.local_cell to head exactly once."
	)
	_expect(
		not _movement.is_participant(actor)
		and _movement.get_actor_phase(actor) == ActorMovementRequest.Phase.CONTRACTED,
		"A completed one-step intent must finish as contracted."
	)
	_expect(
		_movement.get_actor_occupied_cells(actor) == [Vector2i(2, 1)],
		"Completed occupancy must release the old tail."
	)


func _test_direction_intent_continuity_and_latest_input() -> void:
	_movement.cancel_all()
	var location_id := &"d1000000-0000-4000-8000-000000000002"
	_create_location(location_id, Vector2i(7, 4))
	var actor := _create_actor(
		&"d2000000-0000-4000-8000-000000000002",
		location_id,
		Vector2i(0, 2),
		64.0
	)
	_expect(
		_movement.set_direction_intent(actor, Vector2i.RIGHT),
		"A held cardinal direction must enter Logical Movement."
	)
	var request := _movement.get_request(actor)
	_expect(
		request != null
		and request.intent_kind == ActorMovementRequest.IntentKind.DIRECTION
		and request.candidate_cells == [Vector2i(1, 2), Vector2i(0, 2)],
		"Direction intent C_i must contain only the requested neighbor plus WAIT."
	)
	_movement.advance(0.0)
	for expected_x in [1, 2, 3]:
		_movement.advance(0.5)
		_expect(
			actor.current_cell == Vector2i(expected_x, 2),
			"Held direction must commit consecutive exact Grid Cells without drift."
		)
		_expect(
			_movement.is_participant(actor),
			"A held direction must prepare the next step without a visible per-Cell stop."
		)
	_movement.set_direction_intent(actor, Vector2i.ZERO)
	_movement.advance(0.5)
	_expect(
		actor.current_cell == Vector2i(4, 2) and not _movement.is_participant(actor),
		"Releasing a direction during extended must finish the current step and then stop."
	)
	_expect(actor.state.local_cell == actor.current_cell, "Stopping must leave one committed Cell authority.")

	var turning_actor := _create_actor(
		&"d2000000-0000-4000-8000-000000000003",
		location_id,
		Vector2i(1, 2),
		64.0
	)
	_movement.set_direction_intent(turning_actor, Vector2i.RIGHT)
	_movement.advance(0.0)
	var turning_request := _movement.get_request(turning_actor)
	_expect(
		turning_request != null
		and turning_request.phase == ActorMovementRequest.Phase.EXTENDED
		and turning_request.head_cell == Vector2i(2, 2),
		"The current direction step must be approved through Logical Movement."
	)
	_movement.advance(0.25)
	_movement.set_direction_intent(turning_actor, Vector2i.UP)
	_expect(
		turning_request.head_cell == Vector2i(2, 2)
		and turning_actor.current_cell == Vector2i(1, 2),
		"Changing direction while extended must not interrupt or redirect the current step."
	)
	_movement.advance(0.25)
	turning_request = _movement.get_request(turning_actor)
	_expect(
		turning_actor.current_cell == Vector2i(2, 2),
		"The old step must finish at its original head before applying cached input."
	)
	_expect(
		turning_request != null
		and turning_request.direction_intent == Vector2i.UP
		and turning_request.tail_cell == Vector2i(2, 2)
		and turning_request.head_cell == Vector2i(2, 1),
		"The next step must use the latest valid cached direction."
	)
	_movement.set_direction_intent(turning_actor, Vector2i.ZERO)
	_movement.advance(0.5)
	_expect(
		turning_actor.current_cell == Vector2i(2, 1),
		"The cached turn must also finish at an exact logical Cell."
	)


func _test_player_controller_uses_logical_movement() -> void:
	_movement.cancel_all()
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var controller := game.get_node_or_null("PlayerController") as PlayerController
	var player := _registry.get_entity(PLAYER_INSTANCE_ID) as Actor
	_expect(controller != null and player != null, "Main must initialize the controlled ordinary Actor.")
	if controller == null or player == null:
		game.queue_free()
		await process_frame
		return
	var representation := controller.controlled_representation
	_expect(
		controller.controlled_actor == player and is_instance_valid(representation),
		"PlayerController must bind an ordinary Actor and shared ActorRepresentation."
	)
	_expect(
		representation.position == LocationGridSpace.cell_to_center_position(player.current_cell),
		"A contracted ActorRepresentation must begin at the committed Cell center."
	)
	var controller_source := FileAccess.get_file_as_string("res://scripts/player_controller.gd")
	_expect(
		controller_source.contains("set_direction_intent")
		and not controller_source.contains("move_and_slide")
		and not controller_source.contains("sync_state_from_representation")
		and not controller_source.contains("velocity ="),
		"PlayerController must emit intent without owning velocity or Representation-to-State sync."
	)

	var start_cell := player.current_cell
	Input.action_press(&"ui_right")
	await physics_frame
	var request := _movement.get_request(player)
	_expect(
		request != null
		and request.intent_kind == ActorMovementRequest.IntentKind.DIRECTION
		and request.direction_intent == Vector2i.RIGHT,
		"Player input must create the same direction Movement Request used by Logical Movement."
	)
	_movement.advance(0.0)
	request = _movement.get_request(player)
	_expect(
		request != null
		and request.phase == ActorMovementRequest.Phase.EXTENDED
		and request.head_cell == start_cell + Vector2i.RIGHT,
		"The controlled Actor must enter the shared Grid extended phase."
	)
	var half_step := LocationGridSpace.CELL_SIZE / player.definition.move_speed * 0.5
	_movement.advance(half_step)
	await physics_frame
	var expected_half_position := LocationGridSpace.cell_to_center_position(start_cell).lerp(
		LocationGridSpace.cell_to_center_position(start_cell + Vector2i.RIGHT),
		0.5
	)
	_expect(
		representation.position.is_equal_approx(expected_half_position)
		and player.current_cell == start_cell,
		"ActorRepresentation must interpolate Cell centers while logical State remains at tail."
	)
	Input.action_release(&"ui_right")
	await physics_frame
	_movement.advance(half_step)
	await physics_frame
	_expect(
		player.current_cell == start_cell + Vector2i.RIGHT
		and representation.position == LocationGridSpace.cell_to_center_position(player.current_cell),
		"Player movement must finish exactly one Cell after input release."
	)
	_expect(
		not _movement.is_participant(player),
		"Released Player direction must not leave a stale Movement participant."
	)

	var chest := _registry.get_entity(CHEST_INSTANCE_ID) as Furniture
	_expect(chest != null, "Blocked-facing integration requires the project Chest.")
	if chest != null:
		_movement.cancel_all()
		var interaction_cell := Vector2i(13, 6)
		player.state.local_cell = interaction_cell
		(player.state as ActorState).facing = ActorState.Facing.UP
		representation.position = LocationGridSpace.cell_to_center_position(interaction_cell)
		Input.action_press(&"ui_right")
		await physics_frame
		Input.action_release(&"ui_right")
		await physics_frame
		_expect(
			player.current_cell == interaction_cell
			and player.facing == ActorState.Facing.RIGHT
			and not _movement.is_participant(player),
			"Facing must update immediately when blocking Furniture prevents the requested step."
		)
		var interaction_result := controller.request_interaction()
		_expect(
			interaction_result.success and interaction_result.target_id == CHEST_INSTANCE_ID,
			"Facing a blocking Furniture must still permit its valid V10 interaction."
		)

		var action_id := chest.get_primary_action(player)
		var spatial_action := WorldAction.new(action_id, player, chest)
		_expect(
			ActionSpatialRule.evaluate(spatial_action).allowed,
			"A contracted Actor at a valid UseSlot must remain eligible for Spatial Action."
		)
		_expect(_movement.request_step(player, Vector2i.LEFT), "UseSlot phase test must create a stable step request.")
		var spatial_request := _movement.get_request(player)
		_movement.call("_activate_contracted", spatial_request)
		_expect(
			spatial_request.phase == ActorMovementRequest.Phase.REQUESTING
			and ActionSpatialRule.evaluate(spatial_action).allowed,
			"A requesting Actor still committed at the Slot Cell must remain eligible."
		)
		_movement.call("_activate_requesting", spatial_request)
		(player.state as ActorState).facing = ActorState.Facing.RIGHT
		var extended_decision := ActionSpatialRule.evaluate(spatial_action)
		_expect(
			spatial_request.phase == ActorMovementRequest.Phase.EXTENDED
			and not extended_decision.allowed
			and extended_decision.failure_code == &"actor_in_cell_transition",
			"An extended Actor must be rejected by the world Spatial Rule before starting a UseSlot Action."
		)
		_movement.cancel_all()
	game.queue_free()
	await process_frame


func _test_npc_astar_candidates_and_long_distance_alignment() -> void:
	_movement.cancel_all()
	var location_id := &"d1000000-0000-4000-8000-000000000003"
	_create_location(location_id, Vector2i(14, 3))
	var actor := _create_actor(
		&"d2000000-0000-4000-8000-000000000004",
		location_id,
		Vector2i(0, 1),
		64.0
	)
	_expect(
		_movement.request_move(actor, Vector2i(12, 1)),
		"A target intent must be accepted for NPC-style AStarGrid2D guidance."
	)
	var request := _movement.get_request(actor)
	_expect(
		request != null
		and request.intent_kind == ActorMovementRequest.IntentKind.TARGET
		and request.candidate_cells.front() == Vector2i(1, 1)
		and request.candidate_cells.size() > 2,
		"NPC target C_i must prefer the A* next Cell while retaining alternate neighbors and WAIT."
	)
	for candidate in request.candidate_cells:
		_expect(
			candidate == request.tail_cell
			or _manhattan_distance(candidate, request.tail_cell) == 1,
			"Every Causal-PIBT candidate must be a cardinal neighbor or WAIT."
		)

	for _step in range(80):
		if not _movement.is_participant(actor):
			break
		_movement.advance(0.25)
		request = _movement.get_request(actor)
		if request != null and request.phase != ActorMovementRequest.Phase.CONTRACTED:
			_expect(
				_manhattan_distance(request.tail_cell, request.head_cell) == 1,
				"Every requesting or extended target step must remain one cardinal Cell."
			)
	_expect(actor.current_cell == Vector2i(12, 1), "NPC target guidance must reach the requested Cell.")
	_expect(
		actor.state.local_cell == Vector2i(12, 1),
		"Many consecutive target steps must retain exact integer Cell authority without pixel drift."
	)
	_expect(not _movement.is_participant(actor), "Completed target guidance must clear its request.")

	var detour_id := &"d1000000-0000-4000-8000-000000000004"
	_create_location(detour_id, Vector2i(5, 3))
	var npc := _create_actor(
		&"d2000000-0000-4000-8000-000000000005",
		detour_id,
		Vector2i(1, 1),
		64.0
	)
	_create_actor(
		&"d2000000-0000-4000-8000-000000000006",
		detour_id,
		Vector2i(2, 1),
		64.0
	)
	_movement.request_move(npc, Vector2i(4, 1))
	_movement.advance(0.0)
	_movement.advance(0.0)
	var detour_request := _movement.get_request(npc)
	_expect(
		detour_request != null
		and detour_request.phase == ActorMovementRequest.Phase.EXTENDED
		and detour_request.head_cell != Vector2i(2, 1)
		and detour_request.head_cell != detour_request.tail_cell,
		"NPC C_i must backtrack from a non-participant hard obstacle to another A*-ranked neighbor."
	)


func _test_same_head_conflict() -> void:
	_movement.cancel_all()
	var location_id := &"d1000000-0000-4000-8000-000000000005"
	_create_location(location_id, Vector2i(5, 3))
	var first := _create_actor(
		&"d2000000-0000-4000-8000-000000000010",
		location_id,
		Vector2i(1, 1),
		32.0
	)
	var second := _create_actor(
		&"d2000000-0000-4000-8000-000000000011",
		location_id,
		Vector2i(3, 1),
		32.0
	)
	_movement.request_step(second, Vector2i.LEFT)
	_movement.request_step(first, Vector2i.RIGHT)
	_movement.advance(0.0)
	var first_request := _movement.get_request(first)
	var second_request := _movement.get_request(second)
	var extended_count := 0
	for candidate in [first_request, second_request]:
		if candidate != null and candidate.phase == ActorMovementRequest.Phase.EXTENDED:
			extended_count += 1
	_expect(extended_count == 1, "Only one same-head contender may enter extended.")
	_expect(
		first_request != null and first_request.phase == ActorMovementRequest.Phase.EXTENDED,
		"Equal base priority must use stable instance UUID as the same-head tiebreaker."
	)
	_expect(
		_actor_occupancies_do_not_overlap([first, second]),
		"Same-head coordination must preserve unique hard occupancy."
	)


func _test_priority_inheritance_chain() -> void:
	_movement.cancel_all()
	var location_id := &"d1000000-0000-4000-8000-000000000006"
	_create_location(location_id, Vector2i(5, 1))
	var first := _create_actor(
		&"d2000000-0000-4000-8000-000000000020",
		location_id,
		Vector2i(0, 0),
		32.0
	)
	var second := _create_actor(
		&"d2000000-0000-4000-8000-000000000021",
		location_id,
		Vector2i(1, 0),
		16.0
	)
	var third := _create_actor(
		&"d2000000-0000-4000-8000-000000000022",
		location_id,
		Vector2i(2, 0),
		32.0
	)
	_movement.request_move(first, Vector2i(4, 0))
	_movement.request_move(second, Vector2i(4, 0))
	_movement.request_move(third, Vector2i(4, 0))
	_movement.advance(0.0)
	var first_request := _movement.get_request(first)
	var second_request := _movement.get_request(second)
	var third_request := _movement.get_request(third)
	_expect(
		first_request != null
		and second_request != null
		and third_request != null,
		"Every Actor in the dependency chain must remain a participant."
	)
	if first_request == null or second_request == null or third_request == null:
		return
	_expect(
		first_request.phase == ActorMovementRequest.Phase.REQUESTING
		and second_request.phase == ActorMovementRequest.Phase.REQUESTING
		and third_request.phase == ActorMovementRequest.Phase.EXTENDED,
		"Only the unoccupied dependency leaf may extend before upstream tails are released."
	)
	_expect(
		second_request.parent_actor_id == first.instance_id
		and first_request.children_actor_ids.has(second.instance_id),
		"Priority inheritance must establish the root-to-child parent relation."
	)
	_expect(
		third_request.parent_actor_id == third.instance_id
		and not second_request.children_actor_ids.has(third.instance_id),
		"An extending leaf must detach from its parent and be released from children."
	)
	_expect(
		second_request.current_priority_instance_id == first.instance_id
		and third_request.current_priority_instance_id == first.instance_id,
		"Inherited current priority must propagate through the dependency chain."
	)
	_expect(
		second_request.original_priority_instance_id == second.instance_id
		and third_request.original_priority_instance_id == third.instance_id,
		"Priority inheritance must not overwrite any Actor's original request priority."
	)
	_expect(
		second_request.searched_cells.has(Vector2i(0, 0))
		and second_request.searched_cells.has(Vector2i(1, 0))
		and second_request.searched_cells.has(Vector2i(2, 0))
		and third_request.searched_cells.has(Vector2i(3, 0)),
		"S_i must copy the parent search and add each inherited/requested node."
	)
	_expect(
		_actor_occupancies_do_not_overlap([first, second, third]),
		"Inherited requests must never overlap contracted or extended occupancy."
	)
	_movement.advance(1.0)
	first_request = _movement.get_request(first)
	second_request = _movement.get_request(second)
	_expect(
		first_request != null and first_request.phase != ActorMovementRequest.Phase.EXTENDED,
		"The root must still wait while the intermediate tail remains occupied."
	)
	_expect(
		second_request != null and second_request.phase == ActorMovementRequest.Phase.EXTENDED,
		"The intermediate Actor may extend only after the leaf releases its tail."
	)
	_expect(
		_actor_occupancies_do_not_overlap([first, second, third]),
		"Dependency promotion must preserve unique occupancy with independent durations."
	)
	_movement.cancel_all()
	_expect(
		not _movement.is_participant(first)
		and not _movement.is_participant(second)
		and not _movement.is_participant(third),
		"Cancelling all movement must remove all temporary coordination participants."
	)
	_expect(
		first_request.children_actor_ids.is_empty()
		and second_request.parent_actor_id == second.instance_id
		and third_request.parent_actor_id == third.instance_id,
		"Cancellation must detach all retained parent/children coordination references."
	)


func _test_backtracking_and_request_cycle() -> void:
	_movement.cancel_all()
	var backtrack_id := &"d1000000-0000-4000-8000-000000000007"
	_create_location(
		backtrack_id,
		Vector2i(4, 3),
		[Vector2i(2, 0), Vector2i(2, 2), Vector2i(3, 1)]
	)
	var root_actor := _create_actor(
		&"d2000000-0000-4000-8000-000000000030",
		backtrack_id,
		Vector2i(1, 1),
		32.0
	)
	var blocker := _create_actor(
		&"d2000000-0000-4000-8000-000000000031",
		backtrack_id,
		Vector2i(2, 1),
		32.0
	)
	_movement.request_move(root_actor, Vector2i(2, 1))
	_movement.request_move(blocker, Vector2i(0, 1))
	_movement.advance(0.0)
	var root_request := _movement.get_request(root_actor)
	_expect(
		root_request != null
		and root_request.phase == ActorMovementRequest.Phase.EXTENDED
		and root_request.head_cell != Vector2i(2, 1)
		and root_request.head_cell != root_request.tail_cell,
		"Backtracking must make the root try a remaining C_i candidate after the inherited child fails."
	)
	_expect(
		root_request != null and root_request.searched_cells.has(Vector2i(2, 1)),
		"Backtracking must propagate the failed child's S_i into the parent search."
	)

	_movement.cancel_all()
	var cycle_id := &"d1000000-0000-4000-8000-000000000008"
	_create_location(cycle_id, Vector2i(2, 2))
	var first := _create_actor(
		&"d2000000-0000-4000-8000-000000000032",
		cycle_id,
		Vector2i(0, 0),
		32.0
	)
	var second := _create_actor(
		&"d2000000-0000-4000-8000-000000000033",
		cycle_id,
		Vector2i(1, 0),
		32.0
	)
	_movement.request_move(first, Vector2i(1, 0))
	_movement.request_move(second, Vector2i(0, 0))
	_movement.advance(0.0)
	var first_request := _movement.get_request(first)
	var second_request := _movement.get_request(second)
	_expect(
		first_request != null and second_request != null,
		"A local swap request cycle must remain represented by formal participant state."
	)
	_expect(
		(first_request.phase == ActorMovementRequest.Phase.EXTENDED)
		!= (second_request.phase == ActorMovementRequest.Phase.EXTENDED),
		"S_i cycle exclusion and backtracking must let only one Actor use a free alternate Cell."
	)
	var extending := first_request if first_request.phase == ActorMovementRequest.Phase.EXTENDED else second_request
	var waiting := second_request if extending == first_request else first_request
	_expect(
		extending.head_cell != waiting.tail_cell,
		"Request-cycle recovery must not approve the direct swap edge into an occupied tail."
	)
	_expect(
		_actor_occupancies_do_not_overlap([first, second]),
		"Request-cycle recovery must preserve hard occupancy without recursive snapshots."
	)


func _test_independent_move_speeds() -> void:
	_movement.cancel_all()
	var location_id := &"d1000000-0000-4000-8000-000000000009"
	_create_location(location_id, Vector2i(3, 3))
	var slow := _create_actor(
		&"d2000000-0000-4000-8000-000000000040",
		location_id,
		Vector2i(0, 0),
		32.0
	)
	var fast := _create_actor(
		&"d2000000-0000-4000-8000-000000000041",
		location_id,
		Vector2i(0, 2),
		64.0
	)
	_movement.request_step(slow, Vector2i.RIGHT)
	_movement.request_step(fast, Vector2i.RIGHT)
	_movement.advance(0.0)
	var slow_request := _movement.get_request(slow)
	var fast_request := _movement.get_request(fast)
	_expect(
		slow_request != null
		and fast_request != null
		and is_equal_approx(slow_request.step_duration, 1.0)
		and is_equal_approx(fast_request.step_duration, 0.5),
		"ActorDefinition.move_speed must determine each Actor's independent Cell-step duration."
	)
	_movement.advance(0.5)
	_expect(
		slow.current_cell == Vector2i(0, 0)
		and slow_request != null
		and is_equal_approx(slow_request.get_step_progress(), 0.5)
		and _movement.get_actor_phase(slow) == ActorMovementRequest.Phase.EXTENDED,
		"A 32 px/s Actor must remain logically at tail while halfway through its one-second step."
	)
	_expect(
		fast.current_cell == Vector2i(1, 2)
		and not _movement.is_participant(fast),
		"A 64 px/s Actor must complete independently in the same elapsed time."
	)


func _test_scene_unload_and_rebuild() -> void:
	_movement.cancel_all()
	var location_id := &"d1000000-0000-4000-8000-000000000010"
	var location := _create_location(location_id, Vector2i(6, 3))
	var actor := _create_actor(
		&"d2000000-0000-4000-8000-000000000050",
		location_id,
		Vector2i(1, 1),
		32.0
	)
	var first_scene := _build_location_scene(location)
	_expect(first_scene != null, "A Location Scene must build for a logical Actor.")
	if first_scene == null:
		return
	root.add_child(first_scene)
	await process_frame
	await physics_frame
	var first_representation := _find_actor_representation(first_scene, actor.instance_id)
	_expect(first_representation != null, "A loaded Actor must have ActorRepresentation.")
	_movement.request_move(actor, Vector2i(4, 1))
	_movement.advance(0.0)
	_movement.advance(0.25)
	await physics_frame
	var quarter_position := LocationGridSpace.cell_to_center_position(Vector2i(1, 1)).lerp(
		LocationGridSpace.cell_to_center_position(Vector2i(2, 1)),
		0.25
	)
	_expect(
		first_representation != null
		and first_representation.position.is_equal_approx(quarter_position)
		and actor.current_cell == Vector2i(1, 1),
		"Loaded Representation must interpolate current progress without changing logical tail."
	)
	first_scene.queue_free()
	await process_frame

	var midway_scene := _build_location_scene(location)
	_expect(midway_scene != null, "A Location Scene must rebuild while an Actor is extended.")
	if midway_scene == null:
		return
	root.add_child(midway_scene)
	await process_frame
	await physics_frame
	var midway_representation := _find_actor_representation(midway_scene, actor.instance_id)
	_expect(
		midway_representation != null
		and midway_representation.position.is_equal_approx(quarter_position),
		"A mid-step Scene rebuild must restore the existing tail/head progress instead of restarting."
	)
	midway_scene.queue_free()
	await process_frame

	var unloaded_cell := actor.current_cell
	_advance_until_complete(actor, 0.5, 30)
	_expect(
		actor.current_cell != unloaded_cell
		and actor.current_cell == Vector2i(4, 1),
		"Logical Movement must finish off-screen without a Location Scene."
	)
	var final_scene := _build_location_scene(location)
	_expect(final_scene != null, "The Location Scene must rebuild after off-screen movement.")
	if final_scene == null:
		return
	root.add_child(final_scene)
	await process_frame
	await physics_frame
	var final_representation := _find_actor_representation(final_scene, actor.instance_id)
	_expect(
		final_representation != null
		and final_representation.position == LocationGridSpace.cell_to_center_position(actor.current_cell),
		"Rebuilt contracted Representation must restore the committed Cell center."
	)
	final_scene.queue_free()
	await process_frame


func _test_no_formal_martha_initialization() -> void:
	var found_formal_martha := false
	for entity in _registry.get_entities():
		if entity is Actor and (entity as Actor).definition == MARTHA_DEFINITION:
			found_formal_martha = true
			break
	_expect(
		not found_formal_martha,
		"V11.2 must leave Martha definition-only and must not add formal NPC initialization."
	)


func _test_removed_resolver_mechanisms() -> void:
	var movement_source := FileAccess.get_file_as_string("res://scripts/movement/logical_movement.gd")
	var representation_source := FileAccess.get_file_as_string(
		"res://scripts/actors/actor_representation.gd"
	)
	var entity_state_source := FileAccess.get_file_as_string("res://scripts/entities/entity_state.gd")
	var entity_source := FileAccess.get_file_as_string("res://scripts/entities/entity.gd")
	var grid_source := FileAccess.get_file_as_string("res://scripts/location/location_grid_space.gd")
	var furniture_representation_source := FileAccess.get_file_as_string(
		"res://scripts/furniture/furniture_representation.gd"
	)
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	var location_entry_source := FileAccess.get_file_as_string("res://scripts/location/location_entry.gd")
	var scene_builder_source := FileAccess.get_file_as_string(
		"res://scripts/location/location_scene_builder.gd"
	)
	for removed_term in [
		"STATUS_VISITING",
		"STATUS_RESOLVED",
		"STATUS_FAILED",
		"_resolve_movement",
		"_snapshot_context",
		"_restore_context",
		"set_actor_externally_controlled",
		"is_actor_externally_controlled",
	]:
		_expect(
			not movement_source.contains(removed_term),
			"Logical Movement must remove old resolver mechanism '%s'." % removed_term
		)
	_expect(
		not representation_source.contains("sync_state_from_representation")
		and not representation_source.contains("_state_driven")
		and not representation_source.contains("set(value)"),
		"ActorRepresentation must remain a read-only Cell/progress/facing consumer for every Actor."
	)
	_expect(
		not game_source.contains("representation).facing")
		and not game_source.contains("representation as ActorRepresentation).facing"),
		"Location Transfer must write facing once to ActorState without Representation-to-State duplication."
	)
	_expect(
		not location_entry_source.contains("get_center_position")
		and not location_entry_source.contains("cell_to_center_position"),
		"LocationEntry must expose logical arrival Cells only, without pixel Presentation conversion."
	)
	_expect(
		scene_builder_source.contains("LocationGridSpace.cell_to_center_position(entry.arrival_cells[arrival_index])"),
		"LocationSceneBuilder must own Entry Cell-to-Pixel marker conversion."
	)
	_expect(
		entity_state_source.contains("local_cell: Vector2i")
		and not entity_state_source.contains("local_position"),
		"EntityState source must expose only Cell-authoritative logical position."
	)
	_expect(
		not entity_source.contains("local_position_to_cell")
		and not grid_source.contains("local_position_to_cell"),
		"Logical code must not derive an Entity Cell from pixel position."
	)
	_expect(
		not movement_source.contains("move_toward")
		and not movement_source.contains("local_position"),
		"LogicalMovement must advance elapsed/duration rather than a per-frame Vector2 State."
	)
	_expect(
		not furniture_representation_source.contains("state.local_cell =")
		and not furniture_representation_source.contains("func _exit_tree"),
		"FurnitureRepresentation must not synchronize Scene position back into logical State."
	)
	_expect(
		not game_source.contains("spawn_position")
		and not game_source.contains("local_position"),
		"Initialization and Location transfer must pass and commit Cells only."
	)


func _create_location(
	location_id: StringName,
	grid_size: Vector2i,
	blocked_cells: Array[Vector2i] = []
) -> Location:
	var definition := LocationDefinition.new()
	definition.display_name = "V11.2 Test Location"
	definition.grid_size = grid_size
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			definition.ground_layer[Vector2i(x, y)] = GRASS
	for cell in blocked_cells:
		var blocker := StructureTileDefinition.new()
		blocker.blocks_movement = true
		definition.structure_layer[cell] = blocker
	var definitions: Dictionary = _location_registry.get("_definitions_by_location")
	definitions[location_id] = definition
	_expect(
		_state_registry.register_location_state(LocationState.new(location_id)),
		"V11.2 test LocationState must register."
	)
	var location := _location_registry.get_location(location_id)
	_expect(location != null, "V11.2 test Location must resolve.")
	return location


func _create_actor(
	instance_id: StringName,
	location_id: StringName,
	cell: Vector2i,
	move_speed: float
) -> Actor:
	var definition := MARTHA_DEFINITION.duplicate(true) as ActorDefinition
	definition.move_speed = move_speed
	var state := ActorState.new(
		instance_id,
		location_id,
		cell,
		ActorState.Facing.DOWN
	)
	var actor := Actor.new(definition, state)
	_expect(_state_registry.register_entity_state(state), "V11.2 test ActorState must register.")
	_expect(_registry.register_entity(actor), "V11.2 test Actor must register.")
	return actor


func _build_location_scene(location: Location) -> LocationScene:
	var prepared := LocationSceneBuilder.new().prepare_scene(
		location,
		EntityRepresentationRegistry.create_default()
	)
	if prepared.is_empty():
		return null
	var scene := prepared["scene"] as LocationScene
	if not scene.prepare_activation(location):
		scene.free()
		return null
	return scene


func _find_actor_representation(
	location_scene: LocationScene,
	instance_id: StringName
) -> ActorRepresentation:
	var representation_root := location_scene.get_node_or_null("EntityRepresentationRoot")
	if representation_root == null:
		return null
	for child in representation_root.get_children():
		if child is ActorRepresentation and (child as ActorRepresentation).instance_id == instance_id:
			return child as ActorRepresentation
	return null


func _advance_until_complete(actor: Actor, delta: float, maximum_steps: int) -> void:
	for _step in range(maximum_steps):
		if not _movement.is_participant(actor):
			return
		_movement.advance(delta)


func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	var difference := a - b
	return absi(difference.x) + absi(difference.y)


func _actor_occupancies_do_not_overlap(actors: Array) -> bool:
	var occupied: Dictionary[Vector2i, bool] = {}
	for actor: Actor in actors:
		for cell in _movement.get_actor_occupied_cells(actor):
			if occupied.has(cell):
				return false
			occupied[cell] = true
	return true


func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if property["name"] == property_name:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("Test failure: %s" % message)


func _finish() -> void:
	if _failures == 0:
		print("V11.2 Unified Grid Movement: %d checks passed." % _checks)
		quit(0)
		return
	push_error("V11.2 Unified Grid Movement: %d of %d checks failed." % [_failures, _checks])
	quit(1)
