extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const PLAYER_DEFINITION: ActorDefinition = preload("res://data/actors/player.tres")
const SIGN_DEFINITION: FurnitureDefinition = preload("res://data/furniture/sign.tres")
const GRASS: GroundTileDefinition = preload("res://data/tiles/ground/grass.tres")

const TEST_LOCATION_ID := &"a0000000-0000-4000-8000-000000000010"
const TARGET_ID := &"a0000000-0000-4000-8000-000000000011"
const BLOCKER_ID := &"a0000000-0000-4000-8000-000000000012"
const TEST_ACTOR_ID := &"a0000000-0000-4000-8000-000000000013"
const NON_BLOCKING_ID := &"a0000000-0000-4000-8000-000000000014"
const FACING_PRIORITY_ID := &"a0000000-0000-4000-8000-000000000118"
const PLAYER_ID := &"90000000-0000-4000-8000-000000000001"
const CHEST_ID := &"5543caf7-2a10-4a40-84de-3a39ffdf670e"

var _checks := 0
var _failures := 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_default_blocking_slots()
	_test_default_two_by_two_slots()
	_test_irregular_footprint_slots()
	_test_furniture_representation_has_no_movement_collision()
	_test_non_blocking_footprint_slots()
	_test_explicit_action_slots()
	_test_slot_entrances_and_movement()
	_test_runtime_slot_validation()
	_test_facing_mask_semantics()
	_test_allowed_facing()
	_test_missing_location_rejects()
	await _test_existing_interaction_and_scene_rebuild()
	_finish()


func _test_default_blocking_slots() -> void:
	var furniture := _create_furniture(Vector2i.ONE, true, Vector2i(3, 3), TARGET_ID)
	var slots := furniture.get_use_slots(&"inspect")
	var expected := {
		Vector2i.UP: UseSlot.facing_mask(ActorState.Facing.DOWN),
		Vector2i.DOWN: UseSlot.facing_mask(ActorState.Facing.UP),
		Vector2i.LEFT: UseSlot.facing_mask(ActorState.Facing.RIGHT),
		Vector2i.RIGHT: UseSlot.facing_mask(ActorState.Facing.LEFT),
	}
	_expect(slots.size() == 4, "1x1 blocking Furniture must generate four default UseSlots.")
	for slot in slots:
		_expect(expected.has(slot.local_cell), "1x1 defaults must contain only cardinal neighboring Cells.")
		_expect(slot.allowed_facings == expected.get(slot.local_cell), "Default external UseSlot facing must point toward the Entity.")
		_expect(slot.supported_actions == [&"inspect"], "A generated UseSlot must belong to the queried Action.")
		var entrances := slot.get_slot_entrances()
		_expect(entrances.size() == 1 and entrances[0].local_cell == slot.local_cell, "A UseSlot without explicit SlotEntrance must default Entrance to itself.")
	_expect(not _slot_cells(slots).has(Vector2i(-1, -1)), "Default UseSlots must not include diagonals.")


func _test_default_two_by_two_slots() -> void:
	var furniture := _create_furniture(
		Vector2i(2, 2),
		true,
		Vector2i(2, 2),
		&"a0000000-0000-4000-8000-000000000015"
	)
	var slots := furniture.get_use_slots(&"inspect")
	var expected_cells := {
		Vector2i(0, -1): true,
		Vector2i(1, -1): true,
		Vector2i(0, 2): true,
		Vector2i(1, 2): true,
		Vector2i(-1, 0): true,
		Vector2i(-1, 1): true,
		Vector2i(2, 0): true,
		Vector2i(2, 1): true,
	}
	_expect(slots.size() == 8, "2x2 blocking Furniture must generate eight unique perimeter UseSlots.")
	_expect(_slot_cells(slots) == expected_cells, "2x2 defaults must cover the cardinal footprint perimeter exactly once.")


func _test_irregular_footprint_slots() -> void:
	var footprint: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]
	var furniture := _create_furniture_with_footprint(
		footprint,
		true,
		Vector2i(3, 3),
		&"a0000000-0000-4000-8000-000000000115"
	)
	var expected_location_cells := [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4)]
	_expect(furniture.get_footprint_local_cells() == footprint, "Furniture must expose Definition-local footprint cells unchanged.")
	_expect(furniture.get_occupied_location_cells() == expected_location_cells, "An L-shaped footprint must occupy exactly its local cells in Location space.")
	var slots := furniture.get_use_slots(&"inspect")
	var expected_slots := {
		Vector2i(0, -1): UseSlot.facing_mask(ActorState.Facing.DOWN),
		Vector2i(-1, 0): UseSlot.facing_mask(ActorState.Facing.RIGHT),
		Vector2i(1, -1): UseSlot.facing_mask(ActorState.Facing.DOWN),
		Vector2i(2, 0): UseSlot.facing_mask(ActorState.Facing.LEFT),
		Vector2i(1, 1): UseSlot.facing_mask(ActorState.Facing.UP) | UseSlot.facing_mask(ActorState.Facing.LEFT),
		Vector2i(0, 2): UseSlot.facing_mask(ActorState.Facing.UP),
		Vector2i(-1, 1): UseSlot.facing_mask(ActorState.Facing.RIGHT),
	}
	_expect(slots.size() == expected_slots.size(), "L-shaped Furniture defaults must follow the real perimeter, not its bounding rectangle.")
	for slot in slots:
		_expect(expected_slots.get(slot.local_cell) == slot.allowed_facings, "L-shaped default UseSlot facing must preserve every adjacent legal direction.")
	furniture.state.local_cell += Vector2i(2, 1)
	_expect(furniture.get_occupied_location_cells() == [Vector2i(5, 4), Vector2i(6, 4), Vector2i(5, 5)], "Moving an irregular Furniture footprint must translate every occupied Cell together.")
	_expect(furniture.get_footprint_local_cells() == footprint, "Moving Furniture must not mutate its Definition-local footprint.")


func _test_non_blocking_footprint_slots() -> void:
	var furniture := _create_furniture(
		Vector2i.ONE,
		false,
		Vector2i(3, 3),
		&"a0000000-0000-4000-8000-000000000016"
	)
	var slots := furniture.get_use_slots(&"inspect")
	var foot_slot := _find_slot(slots, Vector2i.ZERO)
	_expect(slots.size() == 5, "A non-blocking 1x1 Entity must add its occupied Cell to four external UseSlots.")
	_expect(foot_slot != null, "A non-blocking Entity must expose a foot interaction UseSlot.")
	_expect(foot_slot != null and foot_slot.allowed_facings == UseSlot.ALL_FACINGS, "A foot UseSlot must explicitly allow every normal Actor facing.")
	for facing in [ActorState.Facing.UP, ActorState.Facing.DOWN, ActorState.Facing.LEFT, ActorState.Facing.RIGHT]:
		_expect(foot_slot != null and foot_slot.is_facing_allowed(facing), "A foot UseSlot must allow facing %s." % facing)


func _test_facing_mask_semantics() -> void:
	var default_slot := UseSlot.new()
	_expect(default_slot.allowed_facings == UseSlot.ALL_FACINGS, "UseSlot must default allowed_facings to ALL_FACINGS.")
	_expect(not default_slot.has_facing_restriction(), "A default UseSlot must be unrestricted.")

	var none_slot := UseSlot.new(Vector2i.ZERO, 0)
	for facing in [ActorState.Facing.UP, ActorState.Facing.DOWN, ActorState.Facing.LEFT, ActorState.Facing.RIGHT]:
		_expect(not none_slot.is_facing_allowed(facing), "A zero allowed_facings mask must reject every normal facing.")
	_expect(none_slot.has_facing_restriction(), "A zero allowed_facings mask must be classified as restricted.")

	var right_slot := UseSlot.new(Vector2i.ZERO, UseSlot.facing_mask(ActorState.Facing.RIGHT))
	_expect(right_slot.is_facing_allowed(ActorState.Facing.RIGHT), "A single RIGHT bit must allow RIGHT.")
	_expect(not right_slot.is_facing_allowed(ActorState.Facing.UP), "A single RIGHT bit must reject UP.")
	_expect(not right_slot.is_facing_allowed(ActorState.Facing.DOWN), "A single RIGHT bit must reject DOWN.")
	_expect(not right_slot.is_facing_allowed(ActorState.Facing.LEFT), "A single RIGHT bit must reject LEFT.")
	_expect(right_slot.has_facing_restriction(), "A single facing bit must be classified as restricted.")

	var up_left_slot := UseSlot.new(
		Vector2i.ZERO,
		UseSlot.facing_mask(ActorState.Facing.UP) | UseSlot.facing_mask(ActorState.Facing.LEFT)
	)
	_expect(up_left_slot.is_facing_allowed(ActorState.Facing.UP), "UP | LEFT must allow UP.")
	_expect(up_left_slot.is_facing_allowed(ActorState.Facing.LEFT), "UP | LEFT must allow LEFT.")
	_expect(not up_left_slot.is_facing_allowed(ActorState.Facing.DOWN), "UP | LEFT must reject DOWN.")
	_expect(not up_left_slot.is_facing_allowed(ActorState.Facing.RIGHT), "UP | LEFT must reject RIGHT.")
	_expect(up_left_slot.has_facing_restriction(), "A multi-facing subset must be classified as restricted.")

	var all_slot := UseSlot.new(Vector2i.ZERO, UseSlot.ALL_FACINGS)
	for facing in [ActorState.Facing.UP, ActorState.Facing.DOWN, ActorState.Facing.LEFT, ActorState.Facing.RIGHT]:
		_expect(all_slot.is_facing_allowed(facing), "ALL_FACINGS must allow every normal facing.")
	_expect(not all_slot.has_facing_restriction(), "ALL_FACINGS must be classified as unrestricted.")
	_expect(not all_slot.is_facing_allowed(ActorState.Facing.NONE), "ALL_FACINGS must reject the non-facing sentinel.")


func _test_furniture_representation_has_no_movement_collision() -> void:
	var footprint: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]
	var furniture := _create_furniture_with_footprint(
		footprint,
		true,
		Vector2i(3, 3),
		&"a0000000-0000-4000-8000-000000000119"
	)
	var location := LocationScene.new()
	location.location_id = TEST_LOCATION_ID
	var representation := FurnitureRepresentationFactory.new().prepare(
		furniture,
		location,
		furniture.current_cell
	) as FurnitureRepresentation
	_expect(representation != null, "An L-shaped Furniture Representation must prepare successfully.")
	if representation == null:
		location.free()
		return
	_expect(
		representation.get_node_or_null("Blocking" + "Body") == null
		and _find_descendant_physics_node(representation) == null,
		"FurnitureRepresentation must not duplicate logical footprint blocking with Physics nodes."
	)
	representation.free()
	location.free()


func _find_descendant_physics_node(node: Node) -> Node:
	for child in node.get_children():
		if child is PhysicsBody2D or child.get_class() == "Collision" + "Shape2D":
			return child
		var nested := _find_descendant_physics_node(child)
		if nested != null:
			return nested
	return null


func _test_explicit_action_slots() -> void:
	var furniture := _create_furniture(
		Vector2i.ONE,
		true,
		Vector2i(3, 3),
		&"a0000000-0000-4000-8000-000000000017"
	)
	var explicit_slot := UseSlot.new()
	explicit_slot.local_cell = Vector2i(0, 2)
	explicit_slot.allowed_facings = UseSlot.facing_mask(ActorState.Facing.UP)
	explicit_slot.supported_actions = [&"sleep"]
	explicit_slot.slot_entrances = [SlotEntrance.new(Vector2i(0, 3))]
	furniture.definition.use_slots = [explicit_slot]

	var sleep_slots := furniture.get_use_slots(&"sleep")
	_expect(sleep_slots.size() == 1 and sleep_slots[0] == explicit_slot, "An Action with an explicit UseSlot must not receive default Slots.")
	_expect(furniture.get_use_slots(&"inspect").size() == 4, "An Action without an explicit UseSlot must still receive defaults.")
	_expect(furniture.definition.use_slots == [explicit_slot], "Default generation must not mutate Definition use_slots.")
	var copied_definition := furniture.definition.duplicate(true) as FurnitureDefinition
	_expect(copied_definition.use_slots[0] is UseSlot, "UseSlot must remain a typed Resource inside copied Entity Definition data.")
	_expect(copied_definition.use_slots[0].slot_entrances[0] is SlotEntrance, "SlotEntrance must remain a typed Resource inside copied UseSlot data.")


func _test_slot_entrances_and_movement() -> void:
	var furniture := _create_furniture(
		Vector2i(2, 2),
		true,
		Vector2i(3, 4),
		&"a0000000-0000-4000-8000-000000000018"
	)
	var slot := UseSlot.new()
	slot.local_cell = Vector2i(1, 0)
	slot.allowed_facings = UseSlot.ALL_FACINGS
	slot.supported_actions = [&"sleep"]
	slot.slot_entrances = [
		SlotEntrance.new(Vector2i(0, 0)),
		SlotEntrance.new(Vector2i(2, 0)),
	]
	furniture.definition.use_slots = [slot]

	var entrances := slot.get_slot_entrances()
	_expect(entrances.size() == 2, "A UseSlot must preserve every explicit SlotEntrance.")
	_expect(furniture.get_use_slot_location_cell(slot) == Vector2i(4, 4), "UseSlot Location Cell must add Entity footprint origin and Slot local Cell.")
	_expect(furniture.get_slot_entrance_location_cell(entrances[0]) == Vector2i(3, 4), "First explicit SlotEntrance must convert from Entity-local coordinates.")
	_expect(furniture.get_slot_entrance_location_cell(entrances[1]) == Vector2i(5, 4), "Second explicit SlotEntrance must convert from Entity-local coordinates.")

	var original_slot_cell := slot.local_cell
	var original_entrance_cells := [entrances[0].local_cell, entrances[1].local_cell]
	furniture.state.local_cell += Vector2i(2, 1)
	_expect(slot.local_cell == original_slot_cell, "Moving EntityState must not modify UseSlot Definition coordinates.")
	_expect([entrances[0].local_cell, entrances[1].local_cell] == original_entrance_cells, "Moving EntityState must not modify SlotEntrance Definition coordinates.")
	_expect(furniture.get_use_slot_location_cell(slot) == Vector2i(6, 5), "UseSlot Location Cell must follow EntityState movement.")
	_expect(furniture.get_slot_entrance_location_cell(entrances[1]) == Vector2i(7, 5), "SlotEntrance Location Cell must follow EntityState movement.")


func _test_runtime_slot_validation() -> void:
	var registry := preload("res://scripts/entities/entity_registry.gd").new()
	var location := _create_location(registry)
	var target := _create_furniture(Vector2i.ONE, true, Vector2i(2, 2), TARGET_ID)
	var slot := UseSlot.new()
	slot.local_cell = Vector2i.ZERO
	slot.supported_actions = [&"sleep"]
	var entrance := SlotEntrance.new(Vector2i(0, 1))
	slot.slot_entrances = [entrance]
	target.definition.use_slots = [slot]
	_expect(registry.register_entity(target), "Runtime validation target must register in EntityRegistry.")
	_expect(location.is_use_slot_valid(target, slot), "A UseSlot inside its blocking target footprint must ignore that target's own occupancy.")
	_expect(location.is_slot_entrance_valid(target, entrance), "An unobstructed SlotEntrance must be currently valid.")

	var entrance_location_cell := location.get_slot_entrance_location_cell(target, entrance)
	var wall := StructureTileDefinition.new()
	wall.blocks_movement = true
	location.definition.structure_layer[entrance_location_cell] = wall
	_expect(not location.is_slot_entrance_valid(target, entrance), "A structure-blocked SlotEntrance must be currently invalid.")
	_expect(slot.slot_entrances.has(entrance), "Blocking must not delete SlotEntrance Definition data.")
	location.definition.structure_layer.erase(entrance_location_cell)

	var blocker := _create_furniture(Vector2i.ONE, true, entrance_location_cell, BLOCKER_ID)
	_expect(registry.register_entity(blocker), "Entrance blocker must register in EntityRegistry.")
	_expect(not location.is_slot_entrance_valid(target, entrance), "Another blocking Entity must invalidate SlotEntrance runtime availability.")
	_expect(location.get_slot_entrances(slot) == [entrance], "Runtime filtering must not rewrite explicit SlotEntrance data.")
	registry.free()


func _test_allowed_facing() -> void:
	var location_registry := root.get_node_or_null("LocationRegistry") as LocationRegistry
	var state_registry := root.get_node_or_null("StateRegistry") as StateRegistry
	var entity_registry := root.get_node_or_null("EntityRegistry") as EntityRegistry
	_expect(location_registry != null, "Allowed facing test needs LocationRegistry.")
	if location_registry == null or state_registry == null or entity_registry == null:
		return
	var location_id := location_registry.get_project_location_id(&"tavern")
	var location_state := state_registry.get_location_state(location_id)
	if location_state == null:
		location_state = LocationState.new(location_id)
		state_registry.register_location_state(location_state)
	if location_registry.get_location(location_id) == null:
		location_registry.register(Location.new(
			location_registry.get_location_definition(location_id),
			location_state,
			entity_registry
		), &"tavern")
	var location := location_registry.get_location(location_id)
	var target_origin := _find_open_pair_origin(location)
	var target := _create_furniture(Vector2i.ONE, true, target_origin, TARGET_ID)
	var inspectable := InspectableBehavior.new("Facing test")
	target.definition.behaviors = [inspectable]
	target.behaviors = [inspectable]
	target.state.current_location_id = location_id
	var explicit_slot := UseSlot.new()
	explicit_slot.local_cell = Vector2i.LEFT
	explicit_slot.allowed_facings = (
		UseSlot.facing_mask(ActorState.Facing.RIGHT)
		| UseSlot.facing_mask(ActorState.Facing.DOWN)
	)
	explicit_slot.supported_actions = [&"inspect"]
	target.definition.use_slots = [explicit_slot]
	var actor := Actor.new(
		PLAYER_DEFINITION,
		ActorState.new(
			TEST_ACTOR_ID,
			location_id,
			target_origin + Vector2i.LEFT,
			ActorState.Facing.UP
		)
	)
	var action := EntityAction.new(&"inspect", actor, target)
	var wrong_facing := ActionSpatialRule.evaluate(action)
	_expect(not wrong_facing.allowed, "Action spatial validation must reject a matching Slot with wrong facing.")
	(actor.state as ActorState).facing = ActorState.Facing.RIGHT
	_expect(ActionSpatialRule.evaluate(action).allowed, "Action spatial validation must accept one allowed facing.")
	(actor.state as ActorState).facing = ActorState.Facing.DOWN
	_expect(ActionSpatialRule.evaluate(action).allowed, "Action spatial validation must accept every allowed facing.")


func _test_missing_location_rejects() -> void:
	var actor := Actor.new(
		PLAYER_DEFINITION,
		ActorState.new(
			&"a0000000-0000-4000-8000-000000000116",
			TEST_LOCATION_ID,
			Vector2i(2, 2),
			ActorState.Facing.RIGHT
		)
	)
	var target := _create_furniture(Vector2i.ONE, true, Vector2i(3, 2), &"a0000000-0000-4000-8000-000000000117")
	var location_registry := root.get_node_or_null("LocationRegistry") as LocationRegistry
	if location_registry != null:
		location_registry.name = "UnavailableLocationRegistry"
	var decision := ActionSpatialRule.evaluate(EntityAction.new(&"inspect", actor, target))
	if location_registry != null:
		location_registry.name = "LocationRegistry"
	_expect(not decision.allowed, "ActionSpatialRule must reject when Location cannot be obtained.")
	_expect(decision.failure_code == &"location_unavailable", "Missing Location must report an explicit unavailable failure.")


func _test_existing_interaction_and_scene_rebuild() -> void:
	var location_registry := root.get_node_or_null("LocationRegistry") as LocationRegistry
	var state_registry := root.get_node_or_null("StateRegistry") as StateRegistry
	var registry := root.get_node_or_null("EntityRegistry") as EntityRegistry
	if location_registry == null or state_registry == null or registry == null:
		_expect(false, "V10 integration requires project world Autoloads.")
		return
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var player := registry.get_entity(PLAYER_ID) as Actor
	var chest := registry.get_entity(CHEST_ID) as Furniture
	_expect(player != null and chest != null, "Project Player and Chest must initialize for V10 integration.")
	if player == null or chest == null:
		game.queue_free()
		await process_frame
		return

	var tavern_id := location_registry.get_project_location_id(&"tavern")
	player.state.local_cell = Vector2i(13, 6)
	(player.state as ActorState).facing = ActorState.Facing.RIGHT
	_expect(chest.definition.use_slots.is_empty(), "Ordinary project Furniture must remain valid without explicit V10 data.")
	var controller := game.get_node("PlayerController") as PlayerController
	_expect(controller.call("_select_interaction").get("entity") == chest, "Default UseSlots must preserve ordinary front interaction selection.")
	_expect(ActionSpatialRule.evaluate(EntityAction.new(&"open", player, chest)).allowed, "Default UseSlots must preserve ordinary front Action validation.")

	var location := location_registry.get_location(tavern_id)
	var foot_cell := _find_unclaimed_walkable_cell(location, player)
	var foot_definition := SIGN_DEFINITION.duplicate(true) as FurnitureDefinition
	foot_definition.blocks_movement = false
	foot_definition.use_slots.clear()
	var foot_state := FurnitureState.new(NON_BLOCKING_ID, tavern_id, foot_cell)
	var foot_entity := Furniture.new(foot_definition, foot_state)
	_expect(state_registry.register_entity_state(foot_state), "Non-blocking test EntityState must register.")
	_expect(registry.register_entity(foot_entity), "Non-blocking test Entity must register.")
	player.state.local_cell = foot_cell
	(player.state as ActorState).facing = ActorState.Facing.LEFT
	_expect(controller.call("_select_interaction").get("entity") == foot_entity, "A non-blocking Entity must remain selectable from its foot UseSlot.")
	_expect(EntityAction.new(&"inspect", player, foot_entity).execute().success, "A non-blocking Entity must remain interactable from its occupied Cell.")

	var priority_definition := SIGN_DEFINITION.duplicate(true) as FurnitureDefinition
	priority_definition.blocks_movement = false
	var priority_inspect := InspectableBehavior.new("Priority inspect")
	var priority_open := OpenableBehavior.new()
	priority_open.open_visual = SIGN_DEFINITION.visual
	priority_definition.behaviors = [priority_inspect, priority_open]
	var unrestricted_slot := UseSlot.new(
		Vector2i.ZERO,
		UseSlot.ALL_FACINGS,
		[&"inspect"]
	)
	var facing_slot := UseSlot.new(
		Vector2i.ZERO,
		UseSlot.facing_mask(ActorState.Facing.RIGHT) | UseSlot.facing_mask(ActorState.Facing.DOWN),
		[&"open"]
	)
	priority_definition.use_slots = [unrestricted_slot, facing_slot]
	var priority_state := FurnitureState.new(FACING_PRIORITY_ID, tavern_id, foot_cell)
	var priority_entity := Furniture.new(priority_definition, priority_state)
	_expect(state_registry.register_entity_state(priority_state), "Facing priority test EntityState must register.")
	_expect(registry.register_entity(priority_entity), "Facing priority test Entity must register.")
	(player.state as ActorState).facing = ActorState.Facing.RIGHT
	var priority_selection: Dictionary = controller.call("_select_interaction")
	_expect(priority_selection.get("entity") == priority_entity, "A matching facing Slot must outrank an unrestricted Slot at the same Cell.")
	_expect(priority_selection.get("action_id") == &"open", "Facing Slot priority must preserve the Action attached to the selected Slot.")
	(player.state as ActorState).facing = ActorState.Facing.DOWN
	priority_selection = controller.call("_select_interaction")
	_expect(priority_selection.get("entity") == priority_entity, "PlayerController must consume every facing allowed by a multi-facing Slot.")
	_expect(priority_selection.get("action_id") == &"open", "A second allowed facing must preserve the selected Action.")

	var stable_definition := SIGN_DEFINITION.duplicate(true) as FurnitureDefinition
	stable_definition.blocks_movement = false
	stable_definition.behaviors = [priority_inspect]
	stable_definition.use_slots = [UseSlot.new(
		Vector2i.ZERO,
		UseSlot.facing_mask(ActorState.Facing.RIGHT) | UseSlot.facing_mask(ActorState.Facing.UP),
		[&"inspect"]
	)]
	var stable_state := FurnitureState.new(
		&"a0000000-0000-4000-8000-000000000001",
		tavern_id,
		foot_cell
	)
	var stable_entity := Furniture.new(stable_definition, stable_state)
	_expect(state_registry.register_entity_state(stable_state), "Stable restricted Slot test EntityState must register.")
	_expect(registry.register_entity(stable_entity), "Stable restricted Slot test Entity must register.")
	(player.state as ActorState).facing = ActorState.Facing.RIGHT
	priority_selection = controller.call("_select_interaction")
	_expect(priority_selection.get("entity") == stable_entity, "Matching restricted Slots must remain tied and use stable instance UUID ordering.")
	_expect(priority_selection.get("action_id") == &"inspect", "Stable ordering must preserve the selected restricted Slot Action.")

	var before_slots := chest.get_use_slots(&"open")
	var before_slot_cells := _slot_cells(before_slots)
	var before_entrance_cells := _entrance_location_cells(location, chest, before_slots)
	game.call("request_location_change", &"back_door")
	await _wait_for_transition(game)
	game.call("request_location_change", &"tavern_door")
	await _wait_for_transition(game)
	var rebuilt_location := location_registry.get_location(tavern_id)
	var after_slots := chest.get_use_slots(&"open")
	_expect(before_slot_cells == _slot_cells(after_slots), "UseSlot results must survive Location Scene destruction and rebuilding.")
	_expect(before_entrance_cells == _entrance_location_cells(rebuilt_location, chest, after_slots), "SlotEntrance results must survive Location Scene destruction and rebuilding.")
	_expect(chest.definition.use_slots.is_empty(), "Scene rebuilding must not materialize defaults into FurnitureDefinition.")
	game.queue_free()
	await process_frame


func _create_furniture(
	size: Vector2i,
	blocking: bool,
	origin_cell: Vector2i,
	instance_id: StringName
) -> Furniture:
	return _create_furniture_with_footprint(_rectangular_footprint(size), blocking, origin_cell, instance_id)


func _create_furniture_with_footprint(
	footprint: Array[Vector2i],
	blocking: bool,
	origin_cell: Vector2i,
	instance_id: StringName
) -> Furniture:
	var definition := FurnitureDefinition.new()
	definition.display_name = "V10 Test Furniture"
	definition.visual = SIGN_DEFINITION.visual
	definition.footprint_cells = footprint
	definition.blocks_movement = blocking
	return Furniture.new(
		definition,
		FurnitureState.new(instance_id, TEST_LOCATION_ID, origin_cell)
	)


func _rectangular_footprint(size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(size.y):
		for x in range(size.x):
			cells.append(Vector2i(x, y))
	return cells


func _create_location(registry: EntityRegistry) -> Location:
	var definition := LocationDefinition.new()
	definition.display_name = "V10 Test Location"
	definition.grid_size = Vector2i(6, 6)
	for y in range(definition.grid_size.y):
		for x in range(definition.grid_size.x):
			definition.ground_layer[Vector2i(x, y)] = GRASS
	return Location.new(definition, LocationState.new(TEST_LOCATION_ID), registry)


func _find_open_pair_origin(location: Location) -> Vector2i:
	for y in range(1, location.definition.grid_size.y - 1):
		for x in range(2, location.definition.grid_size.x - 1):
			var origin := Vector2i(x, y)
			if location.is_cell_walkable(origin) and location.is_cell_walkable(origin + Vector2i.LEFT):
				return origin
	return Vector2i(2, 2)


func _find_unclaimed_walkable_cell(location: Location, actor: Actor) -> Vector2i:
	for y in range(1, location.definition.grid_size.y - 1):
		for x in range(1, location.definition.grid_size.x - 1):
			var cell := Vector2i(x, y)
			if not location.is_cell_walkable(cell):
				continue
			var claimed := false
			for entity in location.get_entities():
				if entity == actor:
					continue
				for action_id in entity.get_supported_actions(actor):
					if entity.has_use_slot_at(action_id, cell):
						claimed = true
						break
				if claimed:
					break
			if not claimed:
				return cell
	return Vector2i(1, 1)


func _slot_cells(slots: Array[UseSlot]) -> Dictionary[Vector2i, bool]:
	var cells: Dictionary[Vector2i, bool] = {}
	for slot in slots:
		cells[slot.local_cell] = true
	return cells


func _entrance_location_cells(
	location: Location,
	entity: Entity,
	slots: Array[UseSlot]
) -> Dictionary[Vector2i, bool]:
	var cells: Dictionary[Vector2i, bool] = {}
	for slot in slots:
		for entrance in location.get_slot_entrances(slot):
			cells[location.get_slot_entrance_location_cell(entity, entrance)] = true
	return cells


func _find_slot(slots: Array[UseSlot], local_cell: Vector2i) -> UseSlot:
	for slot in slots:
		if slot.local_cell == local_cell:
			return slot
	return null


func _wait_for_transition(game: Node) -> void:
	for _frame in range(60):
		await process_frame
		await physics_frame
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
		print("V10 Entity Interaction Space: %d checks passed." % _checks)
		quit(0)
		return
	push_error("V10 Entity Interaction Space: %d of %d checks failed." % [_failures, _checks])
	quit(1)
