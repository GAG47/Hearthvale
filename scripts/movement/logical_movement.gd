class_name LogicalMovementRuntime
extends Node

const DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
]

const STATUS_VISITING := 1
const STATUS_RESOLVED := 2
const STATUS_FAILED := 3

var _requests: Dictionary[StringName, ActorMovementRequest] = {}
var _externally_controlled_actors: Dictionary[StringName, bool] = {}
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
	if (
		actor == null
		or actor.definition == null
		or actor.state == null
		or actor.current_location_id.is_empty()
		or actor.definition.move_speed <= 0.0
		or is_actor_externally_controlled(actor)
	):
		return false
	if (
		_entity_registry == null
		or not _entity_registry.has_entity(actor.instance_id)
		or _entity_registry.get_entity(actor.instance_id) != actor
	):
		return false
	var location := _get_location(actor.current_location_id)
	if location == null or not location.is_cell_statically_walkable(target_cell, actor):
		return false
	if actor.current_cell == target_cell:
		cancel_move(actor)
		return true

	if _requests.has(actor.instance_id):
		var existing := _requests[actor.instance_id]
		if existing.actor == actor and existing.target_cell == target_cell:
			return true
		cancel_move(actor)
	_requests[actor.instance_id] = ActorMovementRequest.new(
		actor,
		target_cell,
		_movement_clock
	)
	return true


func cancel_move(actor: Actor) -> void:
	if actor != null:
		_requests.erase(actor.instance_id)


func cancel_all() -> void:
	_requests.clear()


func set_actor_externally_controlled(actor: Actor, enabled: bool) -> void:
	if actor == null:
		return
	if enabled:
		cancel_move(actor)
		_externally_controlled_actors[actor.instance_id] = true
	else:
		_externally_controlled_actors.erase(actor.instance_id)


func is_actor_externally_controlled(actor: Actor) -> bool:
	return actor != null and _externally_controlled_actors.get(actor.instance_id, false)


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


func is_actor_cell_claimed(
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
		var actor := entity as Actor
		var request := get_request(actor)
		if request == null:
			if actor.current_cell == cell:
				return true
			continue
		if request.get_occupied_cells().has(cell):
			return true
		if request.phase == ActorMovementRequest.Phase.REQUESTING and request.head_cell == cell:
			return true
	return false


func advance(delta: float) -> void:
	_resolve_dependencies()
	if _world_definition == null or _entity_registry == null:
		return
	_advance_extended(maxf(delta, 0.0))
	_promote_approved_requesting()
	_resolve_requesting()
	_prepare_contracted()
	_movement_clock += 1


func _advance_extended(delta: float) -> void:
	var completed_ids: Array[StringName] = []
	for actor_id in _requests:
		var request := _requests[actor_id]
		if not _is_request_current(request):
			completed_ids.append(actor_id)
			continue
		if request.phase != ActorMovementRequest.Phase.EXTENDED:
			continue
		var speed := maxf(request.actor.definition.move_speed, 0.0)
		request.actor.state.local_position = request.actor.local_position.move_toward(
			request.step_target_position,
			speed * delta
		)
		if not request.actor.local_position.is_equal_approx(request.step_target_position):
			continue
		request.actor.state.local_position = request.step_target_position
		request.tail_cell = request.head_cell
		request.head_cell = request.tail_cell
		request.phase = ActorMovementRequest.Phase.CONTRACTED
		request.candidates.clear()
		request.coordination_approved = false
		if request.tail_cell == request.target_cell:
			completed_ids.append(actor_id)
	for actor_id in completed_ids:
		_requests.erase(actor_id)


func _resolve_requesting() -> void:
	var requesting: Array[ActorMovementRequest] = []
	var context := {
		"assignments": {},
		"head_owners": {},
		"status": {},
	}
	for request in _requests.values():
		if request.phase != ActorMovementRequest.Phase.REQUESTING:
			continue
		if request.coordination_approved:
			(context["assignments"] as Dictionary)[request.actor.instance_id] = request.head_cell
			(context["head_owners"] as Dictionary)[request.head_cell] = request.actor.instance_id
			(context["status"] as Dictionary)[request.actor.instance_id] = STATUS_RESOLVED
			continue
		requesting.append(request)
	if requesting.is_empty():
		return
	requesting.sort_custom(_request_has_higher_priority)
	for request in requesting:
		_resolve_movement(
			request,
			context,
			request.effective_priority_started_at,
			request.effective_priority_instance_id
		)
	_apply_assignments(context["assignments"])
	_promote_approved_requesting()


func _promote_approved_requesting() -> void:
	var approved: Array[ActorMovementRequest] = []
	for request in _requests.values():
		if (
			request.phase == ActorMovementRequest.Phase.REQUESTING
			and request.coordination_approved
		):
			approved.append(request)
	approved.sort_custom(_request_has_higher_effective_priority)
	for request in approved:
		var location := _get_location(request.location_id)
		if (
			location == null
			or not location.is_cell_statically_walkable(request.head_cell, request.actor)
		):
			_reset_to_contracted(request)
			continue
		var occupant := _get_actor_occupant(
			request.location_id,
			request.head_cell,
			request.actor
		)
		if occupant == null:
			_start_extended(request)
			continue
		var occupant_request := get_request(occupant)
		if occupant_request == null:
			_reset_to_contracted(request)
			continue
		if occupant_request.phase == ActorMovementRequest.Phase.EXTENDED:
			if occupant_request.tail_cell != request.head_cell:
				_reset_to_contracted(request)
			continue
		if (
			occupant_request.phase != ActorMovementRequest.Phase.REQUESTING
			or not occupant_request.coordination_approved
			or occupant_request.tail_cell != request.head_cell
		):
			_reset_to_contracted(request)


func _prepare_contracted() -> void:
	var completed_ids: Array[StringName] = []
	for actor_id in _requests:
		var request := _requests[actor_id]
		if not _is_request_current(request):
			completed_ids.append(actor_id)
			continue
		if request.phase != ActorMovementRequest.Phase.CONTRACTED:
			continue
		if request.tail_cell == request.target_cell:
			completed_ids.append(actor_id)
			continue
		_prepare_requesting(request)
	for actor_id in completed_ids:
		_requests.erase(actor_id)


func _prepare_requesting(request: ActorMovementRequest) -> bool:
	var location := _get_location(request.location_id)
	if location == null:
		return false
	request.candidates = _build_candidates(request, location)
	if request.candidates.is_empty():
		request.candidates = [request.tail_cell]
	request.head_cell = request.candidates[0]
	request.phase = ActorMovementRequest.Phase.REQUESTING
	request.coordination_approved = false
	request.reset_effective_priority()
	return true


func _resolve_movement(
	request: ActorMovementRequest,
	context: Dictionary,
	inherited_started_at: int,
	inherited_instance_id: StringName
) -> bool:
	if request == null or not _is_request_current(request):
		return false
	var actor_id := request.actor.instance_id
	var status: Dictionary = context["status"]
	var current_status := int(status.get(actor_id, 0))
	if current_status == STATUS_RESOLVED:
		return true
	if current_status == STATUS_VISITING or current_status == STATUS_FAILED:
		return false
	if request.phase == ActorMovementRequest.Phase.CONTRACTED:
		if not _prepare_requesting(request):
			status[actor_id] = STATUS_FAILED
			return false
	if request.phase != ActorMovementRequest.Phase.REQUESTING:
		return false

	_inherit_priority(request, inherited_started_at, inherited_instance_id)
	status[actor_id] = STATUS_VISITING
	for candidate in request.candidates:
		var context_snapshot := _snapshot_context(context)
		var request_snapshot := _snapshot_request_coordination()
		request.head_cell = candidate
		if _try_candidate(request, candidate, context):
			var assignments: Dictionary = context["assignments"]
			var head_owners: Dictionary = context["head_owners"]
			assignments[actor_id] = candidate
			head_owners[candidate] = actor_id
			(context["status"] as Dictionary)[actor_id] = STATUS_RESOLVED
			return true
		_restore_context(context, context_snapshot)
		_restore_request_coordination(request_snapshot)
	status = context["status"]
	status[actor_id] = STATUS_FAILED
	return false


func _try_candidate(
	request: ActorMovementRequest,
	candidate: Vector2i,
	context: Dictionary
) -> bool:
	var location := _get_location(request.location_id)
	if location == null or not location.is_cell_statically_walkable(candidate, request.actor):
		return false
	var head_owners: Dictionary = context["head_owners"]
	if head_owners.has(candidate) and head_owners[candidate] != request.actor.instance_id:
		return false
	var occupant := _get_actor_occupant(request.location_id, candidate, request.actor)
	if occupant == null:
		return true
	var occupant_request := get_request(occupant)
	if occupant_request == null or occupant_request.phase == ActorMovementRequest.Phase.EXTENDED:
		return false
	var assignments: Dictionary = context["assignments"]
	if assignments.has(occupant.instance_id):
		return assignments[occupant.instance_id] != occupant_request.tail_cell
	_inherit_priority(
		occupant_request,
		request.effective_priority_started_at,
		request.effective_priority_instance_id
	)
	if not _resolve_movement(
		occupant_request,
		context,
		request.effective_priority_started_at,
		request.effective_priority_instance_id
	):
		return false
	assignments = context["assignments"]
	return (
		assignments.has(occupant.instance_id)
		and assignments[occupant.instance_id] != occupant_request.tail_cell
	)


func _apply_assignments(assignments: Dictionary) -> void:
	for request in _requests.values():
		if request.phase != ActorMovementRequest.Phase.REQUESTING:
			continue
		var next_cell: Vector2i = assignments.get(request.actor.instance_id, request.tail_cell)
		request.head_cell = next_cell
		if next_cell == request.tail_cell:
			_reset_to_contracted(request)
			continue
		request.coordination_approved = true


func _start_extended(request: ActorMovementRequest) -> void:
	request.phase = ActorMovementRequest.Phase.EXTENDED
	request.coordination_approved = false
	request.step_start_position = request.actor.local_position
	request.step_target_position = (
		request.step_start_position
		+ Vector2(request.head_cell - request.tail_cell) * GridSpace.CELL_SIZE
	)
	_set_actor_facing(request.actor, request.head_cell - request.tail_cell)


func _reset_to_contracted(request: ActorMovementRequest) -> void:
	request.phase = ActorMovementRequest.Phase.CONTRACTED
	request.head_cell = request.tail_cell
	request.candidates.clear()
	request.coordination_approved = false
	request.reset_effective_priority()


func _build_candidates(
	request: ActorMovementRequest,
	location: LocationRuntime
) -> Array[Vector2i]:
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


func _get_actor_occupant(
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


func _inherit_priority(
	request: ActorMovementRequest,
	started_at: int,
	instance_id: StringName
) -> void:
	if _priority_is_higher(
		started_at,
		instance_id,
		request.effective_priority_started_at,
		request.effective_priority_instance_id
	):
		request.effective_priority_started_at = started_at
		request.effective_priority_instance_id = instance_id


func _request_has_higher_priority(
	a: ActorMovementRequest,
	b: ActorMovementRequest
) -> bool:
	return _priority_is_higher(
		a.started_at,
		a.actor.instance_id,
		b.started_at,
		b.actor.instance_id
	)


func _request_has_higher_effective_priority(
	a: ActorMovementRequest,
	b: ActorMovementRequest
) -> bool:
	return _priority_is_higher(
		a.effective_priority_started_at,
		a.effective_priority_instance_id,
		b.effective_priority_started_at,
		b.effective_priority_instance_id
	)


func _priority_is_higher(
	a_started_at: int,
	a_instance_id: StringName,
	b_started_at: int,
	b_instance_id: StringName
) -> bool:
	if a_started_at != b_started_at:
		return a_started_at < b_started_at
	return String(a_instance_id) < String(b_instance_id)


func _snapshot_context(context: Dictionary) -> Dictionary:
	return {
		"assignments": (context["assignments"] as Dictionary).duplicate(),
		"head_owners": (context["head_owners"] as Dictionary).duplicate(),
		"status": (context["status"] as Dictionary).duplicate(),
	}


func _restore_context(context: Dictionary, snapshot: Dictionary) -> void:
	context["assignments"] = snapshot["assignments"]
	context["head_owners"] = snapshot["head_owners"]
	context["status"] = snapshot["status"]


func _snapshot_request_coordination() -> Dictionary:
	var snapshot: Dictionary = {}
	for actor_id in _requests:
		var request := _requests[actor_id]
		snapshot[actor_id] = {
			"phase": request.phase,
			"head_cell": request.head_cell,
			"candidates": request.candidates.duplicate(),
			"effective_started_at": request.effective_priority_started_at,
			"effective_instance_id": request.effective_priority_instance_id,
			"coordination_approved": request.coordination_approved,
		}
	return snapshot


func _restore_request_coordination(snapshot: Dictionary) -> void:
	for actor_id in snapshot:
		if not _requests.has(actor_id):
			continue
		var request := _requests[actor_id]
		var values: Dictionary = snapshot[actor_id]
		request.phase = values["phase"]
		request.head_cell = values["head_cell"]
		request.candidates = values["candidates"]
		request.effective_priority_started_at = values["effective_started_at"]
		request.effective_priority_instance_id = values["effective_instance_id"]
		request.coordination_approved = values["coordination_approved"]


func _is_request_current(request: ActorMovementRequest) -> bool:
	return (
		request != null
		and request.actor != null
		and request.actor.current_location_id == request.location_id
		and not is_actor_externally_controlled(request.actor)
	)


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
