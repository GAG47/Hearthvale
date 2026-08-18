class_name LogicalMovementRuntime
extends Node

const DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
]

var _requests: Dictionary[StringName, ActorMovementRequest] = {}
var _direction_intents: Dictionary[StringName, Vector2i] = {}
var _movement_clock := 0
var _world_definition: WorldDefinitionRuntime
var _entity_registry: EntityRegistryRuntime


func _ready() -> void:
	_world_definition = get_node_or_null("/root/WorldDefinition") as WorldDefinitionRuntime
	_entity_registry = get_node_or_null("/root/EntityRegistry") as EntityRegistryRuntime


func _physics_process(delta: float) -> void:
	advance(delta)


func request_move(actor: Actor, target_cell: Vector2i) -> bool:
	_resolve_dependencies()
	if not _can_accept_request(actor):
		return false
	var location := _get_location(actor.current_location_id)
	if location == null or not location.is_cell_statically_walkable(target_cell, actor):
		return false
	if actor.current_cell == target_cell:
		cancel_move(actor)
		return true
	var existing := get_request(actor)
	if existing != null:
		if (
			existing.intent_kind == ActorMovementRequest.IntentKind.TARGET
			and existing.target_cell == target_cell
		):
			return true
		if existing.phase == ActorMovementRequest.Phase.EXTENDED:
			return false
		_remove_request(actor.instance_id)
	_direction_intents.erase(actor.instance_id)
	return _create_request(
		actor,
		target_cell,
		ActorMovementRequest.IntentKind.TARGET,
		Vector2i.ZERO
	)


func request_step(actor: Actor, direction: Vector2i) -> bool:
	_resolve_dependencies()
	if not _is_cardinal_direction(direction) or not _can_accept_request(actor):
		return false
	var existing := get_request(actor)
	if existing != null:
		if (
			existing.intent_kind == ActorMovementRequest.IntentKind.DIRECTION
			and existing.direction_intent == direction
		):
			return true
		if existing.phase == ActorMovementRequest.Phase.EXTENDED:
			return false
		_remove_request(actor.instance_id)
	return _create_direction_request(actor, direction)


func set_direction_intent(actor: Actor, direction: Vector2i) -> bool:
	_resolve_dependencies()
	if actor == null or (direction != Vector2i.ZERO and not _is_cardinal_direction(direction)):
		return false
	if direction == Vector2i.ZERO:
		_direction_intents.erase(actor.instance_id)
		var stopping_request := get_request(actor)
		if (
			stopping_request != null
			and stopping_request.intent_kind == ActorMovementRequest.IntentKind.DIRECTION
		):
			if stopping_request.phase == ActorMovementRequest.Phase.EXTENDED:
				stopping_request.cancel_after_step = true
			else:
				_remove_request(actor.instance_id)
		return true
	if not _can_accept_actor(actor):
		return false

	_direction_intents[actor.instance_id] = direction
	var existing := get_request(actor)
	if (
		existing != null
		and existing.intent_kind == ActorMovementRequest.IntentKind.DIRECTION
		and existing.phase != ActorMovementRequest.Phase.EXTENDED
		and existing.direction_intent != direction
	):
		_remove_request(actor.instance_id)
	if not is_participant(actor):
		_create_direction_request(actor, direction)
	return true


func get_direction_intent(actor: Actor) -> Vector2i:
	return (
		_direction_intents.get(actor.instance_id, Vector2i.ZERO)
		if actor != null
		else Vector2i.ZERO
	)


func cancel_move(actor: Actor) -> void:
	if actor == null:
		return
	_direction_intents.erase(actor.instance_id)
	var request := get_request(actor)
	if request == null:
		return
	if request.phase == ActorMovementRequest.Phase.EXTENDED:
		request.cancel_after_step = true
	else:
		_remove_request(actor.instance_id)


func cancel_all() -> void:
	_direction_intents.clear()
	var actor_ids := _requests.keys()
	actor_ids.sort()
	for actor_id: StringName in actor_ids:
		_remove_request(actor_id)


func is_participant(actor: Actor) -> bool:
	return (
		actor != null
		and _requests.has(actor.instance_id)
		and _requests[actor.instance_id].actor == actor
	)


func get_request(actor: Actor) -> ActorMovementRequest:
	if not is_participant(actor):
		return null
	return _requests[actor.instance_id]


func get_actor_phase(actor: Actor) -> ActorMovementRequest.Phase:
	var request := get_request(actor)
	return request.phase if request != null else ActorMovementRequest.Phase.CONTRACTED


func get_actor_occupied_cells(actor: Actor) -> Array[Vector2i]:
	var request := get_request(actor)
	if request != null:
		return request.get_occupied_cells()
	var cells: Array[Vector2i] = []
	if actor != null:
		cells.append(actor.current_cell)
	return cells


func is_actor_cell_occupied(
	location_id: StringName,
	cell: Vector2i,
	ignored_actor: Actor = null
) -> bool:
	_resolve_dependencies()
	if _entity_registry == null:
		return false
	for entity in _entity_registry.get_entities_in_location(location_id):
		if not entity is Actor or entity == ignored_actor:
			continue
		if get_actor_occupied_cells(entity as Actor).has(cell):
			return true
	return false


func advance(delta: float) -> void:
	_resolve_dependencies()
	if _world_definition == null or _entity_registry == null:
		return
	_remove_invalid_requests()
	_advance_extended(maxf(delta, 0.0))
	_ensure_direction_requests()
	_activate_participants()
	_movement_clock += 1


func _create_request(
	actor: Actor,
	target_cell: Vector2i,
	intent_kind: ActorMovementRequest.IntentKind,
	direction: Vector2i
) -> bool:
	if not _can_accept_request(actor):
		return false
	var request := ActorMovementRequest.new(
		actor,
		target_cell,
		_movement_clock,
		intent_kind,
		direction
	)
	_requests[actor.instance_id] = request
	_reset_request(request)
	return true


func _create_direction_request(actor: Actor, direction: Vector2i) -> bool:
	if not _is_cardinal_direction(direction) or not _can_accept_request(actor):
		return false
	var target_cell := actor.current_cell + direction
	var location := _get_location(actor.current_location_id)
	if location == null or not location.is_cell_statically_walkable(target_cell, actor):
		return false
	return _create_request(
		actor,
		target_cell,
		ActorMovementRequest.IntentKind.DIRECTION,
		direction
	)


func _can_accept_actor(actor: Actor) -> bool:
	return (
		actor != null
		and actor.definition != null
		and actor.state != null
		and not actor.current_location_id.is_empty()
		and actor.definition.move_speed > 0.0
		and _entity_registry != null
		and _entity_registry.has_entity(actor.instance_id)
		and _entity_registry.get_entity(actor.instance_id) == actor
	)


func _can_accept_request(actor: Actor) -> bool:
	return _can_accept_actor(actor) and _is_actor_on_standard_cell(actor)


func _is_actor_on_standard_cell(actor: Actor) -> bool:
	return (
		actor != null
		and actor.local_position.is_equal_approx(
			GridSpace.cell_to_local_position(actor.current_cell)
		)
	)


func _remove_invalid_requests() -> void:
	var invalid_ids: Array[StringName] = []
	for actor_id in _requests:
		if not _is_request_current(_requests[actor_id]):
			invalid_ids.append(actor_id)
	for actor_id in invalid_ids:
		_remove_request(actor_id)


func _advance_extended(delta: float) -> void:
	var completed_ids: Array[StringName] = []
	for actor_id in _requests:
		var request := _requests[actor_id]
		if request.phase != ActorMovementRequest.Phase.EXTENDED:
			continue
		var speed := maxf(request.actor.definition.move_speed, 0.0)
		request.actor.state.local_position = request.actor.local_position.move_toward(
			request.step_target_position,
			speed * delta
		)
		if not request.actor.local_position.is_equal_approx(request.step_target_position):
			continue
		request.actor.state.local_position = GridSpace.cell_to_local_position(request.head_cell)
		request.tail_cell = request.head_cell
		request.head_cell = request.tail_cell
		request.phase = ActorMovementRequest.Phase.CONTRACTED
		_detach_from_parent(request)
		_release_children(request)
		if (
			request.cancel_after_step
			or request.intent_kind == ActorMovementRequest.IntentKind.DIRECTION
			or request.tail_cell == request.target_cell
		):
			completed_ids.append(actor_id)
		else:
			_reset_request(request)
	for actor_id in completed_ids:
		_remove_request(actor_id)


func _ensure_direction_requests() -> void:
	var actor_ids := _direction_intents.keys()
	actor_ids.sort()
	for actor_id: StringName in actor_ids:
		if _requests.has(actor_id) or not _entity_registry.has_entity(actor_id):
			continue
		var actor := _entity_registry.get_entity(actor_id) as Actor
		if actor == null:
			continue
		_create_direction_request(actor, _direction_intents[actor_id])


func _activate_participants() -> void:
	var activation_rounds := maxi(2, _requests.size() + 1)
	for _round in range(activation_rounds):
		var activatable: Array[ActorMovementRequest] = []
		for request in _requests.values():
			if request.phase != ActorMovementRequest.Phase.EXTENDED:
				activatable.append(request)
		activatable.sort_custom(_request_has_higher_current_priority)
		for request in activatable:
			if not _requests.has(request.actor.instance_id):
				continue
			if request.phase == ActorMovementRequest.Phase.CONTRACTED:
				_activate_contracted(request)
			elif request.phase == ActorMovementRequest.Phase.REQUESTING:
				_activate_requesting(request)


func _activate_contracted(request: ActorMovementRequest) -> void:
	if request.candidate_cells.is_empty() and request.is_root():
		_release_children(request)
		_reset_request(request)

	_priority_inheritance(request)
	if request.candidate_cells.is_empty():
		if not request.is_root():
			_backtrack_to_parent(request)
		return

	while not request.candidate_cells.is_empty():
		var candidate: Vector2i = request.candidate_cells.pop_front()
		if candidate == request.tail_cell:
			_release_children(request)
			_reset_request(request)
			return
		var location := _get_location(request.location_id)
		if location == null or not location.is_cell_statically_walkable(candidate, request.actor):
			request.searched_cells[candidate] = true
			continue
		request.searched_cells[candidate] = true
		request.searched_cells[request.tail_cell] = true
		request.head_cell = candidate
		request.phase = ActorMovementRequest.Phase.REQUESTING
		return


func _activate_requesting(request: ActorMovementRequest) -> void:
	_priority_inheritance(request)
	var parent := _get_parent_request(request)
	if (
		parent != null
		and parent != request
		and parent.searched_cells.has(request.head_cell)
	):
		_revert_to_contracted(request)
		return

	var location := _get_location(request.location_id)
	if location == null or not location.is_cell_statically_walkable(request.head_cell, request.actor):
		_revert_to_contracted(request)
		return

	var occupant := _get_actor_hard_occupant(
		request.location_id,
		request.head_cell,
		request.actor
	)
	if occupant != null:
		if get_request(occupant) == null:
			_revert_to_contracted(request)
		return

	var contenders := _get_head_contenders(request.location_id, request.head_cell)
	var winner := _get_highest_priority_request(contenders)
	for contender in contenders:
		if contender == winner:
			continue
		_revert_to_contracted(contender)
	if winner != request:
		return

	_detach_from_parent(request)
	_release_children(request)
	_start_extended(request)


func _priority_inheritance(request: ActorMovementRequest) -> void:
	var inheritors: Array[ActorMovementRequest] = []
	for candidate in _requests.values():
		if (
			candidate != request
			and candidate.location_id == request.location_id
			and candidate.phase == ActorMovementRequest.Phase.REQUESTING
			and candidate.head_cell == request.tail_cell
		):
			inheritors.append(candidate)
	var parent := _get_highest_priority_request(inheritors)
	if parent == null or not _priority_is_higher(
		parent.current_priority_started_at,
		parent.current_priority_instance_id,
		request.current_priority_started_at,
		request.current_priority_instance_id
	):
		return

	_release_children(request)
	_detach_from_parent(request)
	request.parent_actor_id = parent.actor.instance_id
	parent.children_actor_ids[request.actor.instance_id] = true
	request.inherit_priority_from(parent)
	request.searched_cells = parent.searched_cells.duplicate()
	request.searched_cells[request.head_cell] = true
	request.candidate_cells = _filter_searched_cells(
		_build_candidate_cells(request),
		request.searched_cells
	)


func _backtrack_to_parent(request: ActorMovementRequest) -> void:
	var parent := _get_parent_request(request)
	if parent == null or parent == request or parent.head_cell != request.tail_cell:
		return
	for cell in request.searched_cells:
		parent.searched_cells[cell] = true
	parent.candidate_cells = _filter_searched_cells(
		parent.candidate_cells,
		parent.searched_cells
	)
	_revert_to_contracted(parent)


func _start_extended(request: ActorMovementRequest) -> void:
	request.phase = ActorMovementRequest.Phase.EXTENDED
	request.step_start_position = GridSpace.cell_to_local_position(request.tail_cell)
	request.step_target_position = GridSpace.cell_to_local_position(request.head_cell)
	request.actor.state.local_position = request.step_start_position
	_set_actor_facing(request.actor, request.head_cell - request.tail_cell)


func _revert_to_contracted(request: ActorMovementRequest) -> void:
	request.head_cell = request.tail_cell
	request.phase = ActorMovementRequest.Phase.CONTRACTED


func _reset_request(request: ActorMovementRequest) -> void:
	request.reset_current_priority()
	request.searched_cells.clear()
	request.candidate_cells = _build_candidate_cells(request)
	request.head_cell = request.tail_cell
	request.phase = ActorMovementRequest.Phase.CONTRACTED


func _release_children(request: ActorMovementRequest) -> void:
	for child_id in request.children_actor_ids:
		if not _requests.has(child_id):
			continue
		var child := _requests[child_id]
		if child.parent_actor_id == request.actor.instance_id:
			child.parent_actor_id = child.actor.instance_id
	request.children_actor_ids.clear()


func _detach_from_parent(request: ActorMovementRequest) -> void:
	if request.is_root():
		return
	if _requests.has(request.parent_actor_id):
		_requests[request.parent_actor_id].children_actor_ids.erase(request.actor.instance_id)
	request.parent_actor_id = request.actor.instance_id


func _remove_request(actor_id: StringName) -> void:
	if not _requests.has(actor_id):
		return
	var request := _requests[actor_id]
	var parent := _get_parent_request(request)
	if parent != null and parent != request and parent.head_cell == request.tail_cell:
		for cell in request.searched_cells:
			parent.searched_cells[cell] = true
		parent.candidate_cells = _filter_searched_cells(
			parent.candidate_cells,
			parent.searched_cells
		)
		_revert_to_contracted(parent)
	_release_children(request)
	_detach_from_parent(request)
	_requests.erase(actor_id)


func _get_parent_request(request: ActorMovementRequest) -> ActorMovementRequest:
	if request == null or not _requests.has(request.parent_actor_id):
		return request
	return _requests[request.parent_actor_id]


func _build_candidate_cells(request: ActorMovementRequest) -> Array[Vector2i]:
	if request.intent_kind == ActorMovementRequest.IntentKind.DIRECTION:
		var direction_candidates: Array[Vector2i] = []
		var requested_cell := request.tail_cell + request.direction_intent
		var location := _get_location(request.location_id)
		if (
			location != null
			and location.is_cell_statically_walkable(requested_cell, request.actor)
		):
			direction_candidates.append(requested_cell)
		direction_candidates.append(request.tail_cell)
		return direction_candidates

	var location := _get_location(request.location_id)
	if location == null:
		return [request.tail_cell]
	var grid := _build_navigation_grid(location, request.actor)
	if grid == null:
		return [request.tail_cell]
	var primary_path := grid.get_id_path(request.tail_cell, request.target_cell)
	var primary_next := request.tail_cell
	if primary_path.size() > 1:
		primary_next = primary_path[1]
	var ranked: Array[Dictionary] = []
	for direction_index in range(DIRECTIONS.size()):
		var cell := request.tail_cell + DIRECTIONS[direction_index]
		if not location.is_cell_statically_walkable(cell, request.actor):
			continue
		var path := grid.get_id_path(cell, request.target_cell)
		if path.is_empty():
			continue
		ranked.append({
			"cell": cell,
			"primary": cell == primary_next,
			"cost": _get_path_cost(path, location),
			"direction_index": direction_index,
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["primary"] != b["primary"]:
			return a["primary"]
		if not is_equal_approx(a["cost"], b["cost"]):
			return a["cost"] < b["cost"]
		return a["direction_index"] < b["direction_index"]
	)
	var candidates: Array[Vector2i] = []
	for entry in ranked:
		candidates.append(entry["cell"])
	candidates.append(request.tail_cell)
	return candidates


func _filter_searched_cells(
	candidates: Array[Vector2i],
	searched_cells: Dictionary[Vector2i, bool]
) -> Array[Vector2i]:
	var remaining: Array[Vector2i] = []
	for cell in candidates:
		if not searched_cells.has(cell):
			remaining.append(cell)
	return remaining


func _build_navigation_grid(
	location: LocationRuntime,
	actor: Actor
) -> AStarGrid2D:
	if location == null or location.definition == null:
		return null
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, location.definition.grid_size)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.update()
	for y in range(location.definition.grid_size.y):
		for x in range(location.definition.grid_size.x):
			var cell := Vector2i(x, y)
			if not location.is_cell_statically_walkable(cell, actor):
				grid.set_point_solid(cell, true)
				continue
			var ground := location.get_ground_tile(cell)
			if ground != null:
				grid.set_point_weight_scale(cell, maxf(ground.movement_cost, 0.001))
	return grid


func _get_path_cost(path: Array[Vector2i], location: LocationRuntime) -> float:
	var cost := 0.0
	for index in range(1, path.size()):
		var ground := location.get_ground_tile(path[index])
		cost += maxf(ground.movement_cost, 0.001) if ground != null else 1.0
	return cost


func _get_actor_hard_occupant(
	location_id: StringName,
	cell: Vector2i,
	ignored_actor: Actor
) -> Actor:
	if _entity_registry == null:
		return null
	for entity in _entity_registry.get_entities_in_location(location_id):
		if not entity is Actor or entity == ignored_actor:
			continue
		var actor := entity as Actor
		if get_actor_occupied_cells(actor).has(cell):
			return actor
	return null


func _get_head_contenders(
	location_id: StringName,
	head_cell: Vector2i
) -> Array[ActorMovementRequest]:
	var contenders: Array[ActorMovementRequest] = []
	for request in _requests.values():
		if (
			request.location_id == location_id
			and request.phase == ActorMovementRequest.Phase.REQUESTING
			and request.head_cell == head_cell
		):
			contenders.append(request)
	return contenders


func _get_highest_priority_request(
	requests: Array[ActorMovementRequest]
) -> ActorMovementRequest:
	if requests.is_empty():
		return null
	var highest := requests[0]
	for index in range(1, requests.size()):
		if _request_has_higher_current_priority(requests[index], highest):
			highest = requests[index]
	return highest


func _request_has_higher_current_priority(
	a: ActorMovementRequest,
	b: ActorMovementRequest
) -> bool:
	if _priority_is_higher(
		a.current_priority_started_at,
		a.current_priority_instance_id,
		b.current_priority_started_at,
		b.current_priority_instance_id
	):
		return true
	if (
		a.current_priority_started_at == b.current_priority_started_at
		and a.current_priority_instance_id == b.current_priority_instance_id
	):
		return String(a.actor.instance_id) < String(b.actor.instance_id)
	return false


func _priority_is_higher(
	a_started_at: int,
	a_instance_id: StringName,
	b_started_at: int,
	b_instance_id: StringName
) -> bool:
	if a_started_at != b_started_at:
		return a_started_at < b_started_at
	return String(a_instance_id) < String(b_instance_id)


func _is_request_current(request: ActorMovementRequest) -> bool:
	return (
		request != null
		and request.actor != null
		and request.actor.current_location_id == request.location_id
	)


func _is_cardinal_direction(direction: Vector2i) -> bool:
	return DIRECTIONS.has(direction)


func _get_location(location_id: StringName) -> LocationRuntime:
	return _world_definition.get_location(location_id) if _world_definition != null else null


func _resolve_dependencies() -> void:
	if _world_definition == null:
		_world_definition = get_node_or_null("/root/WorldDefinition") as WorldDefinitionRuntime
	if _entity_registry == null:
		_entity_registry = get_node_or_null("/root/EntityRegistry") as EntityRegistryRuntime


func _set_actor_facing(actor: Actor, direction: Vector2i) -> void:
	if actor == null or not actor.state is ActorState:
		return
	var facing := ActorState.Facing.DOWN
	if direction == Vector2i.UP:
		facing = ActorState.Facing.UP
	elif direction == Vector2i.LEFT:
		facing = ActorState.Facing.LEFT
	elif direction == Vector2i.RIGHT:
		facing = ActorState.Facing.RIGHT
	(actor.state as ActorState).facing = facing
