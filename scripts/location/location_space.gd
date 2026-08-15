class_name LocationSpaceRuntime
extends Node

var locations_valid := false

var _locations: Dictionary[StringName, LogicalLocation] = {}
var _world_definition: WorldDefinitionRuntime
var _entity_registry: EntityRegistryRuntime


func _ready() -> void:
	if OS.get_cmdline_args().has("res://tools/bake_logical_locations.gd"):
		return
	_world_definition = get_node_or_null("/root/WorldDefinition") as WorldDefinitionRuntime
	_entity_registry = get_node_or_null("/root/EntityRegistry") as EntityRegistryRuntime
	if _world_definition == null or _entity_registry == null:
		push_error("LocationSpace requires WorldDefinition and EntityRegistry Autoloads.")
		return
	if not _load_logical_locations():
		push_error("LocationSpace initialization failed; logical spatial queries are unavailable.")
		return
	_entity_registry.entities_committed.connect(_on_entities_committed)
	rebuild_spatial_indexes()
	locations_valid = true


func has_location(location_id: StringName) -> bool:
	return locations_valid and _locations.has(location_id)


func get_location(location_id: StringName) -> LogicalLocation:
	if not locations_valid:
		push_error("Cannot query logical Location '%s': LocationSpace is invalid." % location_id)
		return null
	if not _locations.has(location_id):
		push_error("LocationSpace has no logical Location '%s'." % location_id)
		return null
	return _locations[location_id]


func get_locations() -> Array[LogicalLocation]:
	var locations: Array[LogicalLocation] = []
	var location_ids := _locations.keys()
	location_ids.sort()
	for location_id in location_ids:
		locations.append(_locations[location_id])
	return locations


func rebuild_spatial_indexes() -> void:
	for location in _locations.values():
		(location as LogicalLocation).rebuild_spatial_index()


func can_move_entity(
	entity: Entity,
	target_location_id: StringName,
	target_local_position: Vector2
) -> bool:
	if entity == null or not has_location(target_location_id):
		return false
	return _locations[target_location_id].can_place_entity_at(entity, target_local_position)


func try_move_entity(
	entity: Entity,
	target_location_id: StringName,
	target_local_position: Vector2
) -> bool:
	if not can_move_entity(entity, target_location_id, target_local_position):
		return false
	var previous_location := _locations.get(entity.current_location_id) as LogicalLocation
	var target_location := _locations[target_location_id] as LogicalLocation
	if previous_location != null:
		previous_location.remove_entity(entity.entity_id)
	entity.state.current_location_id = target_location_id
	entity.state.local_position = target_local_position
	target_location.index_entity(entity)
	return true


func _load_logical_locations() -> bool:
	if not _world_definition.definitions_valid:
		return false
	var valid := true
	for definition in _world_definition.get_locations():
		var fingerprint := LogicalLocationCompiler.compute_source_fingerprint(definition.scene_path)
		if fingerprint.is_empty() or LogicalLocationCompiler.needs_bake(definition, fingerprint):
			push_error(
				"LogicalLocationData for '%s' is missing or stale. Run the Location Bake preflight."
				% definition.location_id
			)
			valid = false
			continue
		var data := ResourceLoader.load(
			definition.logical_data_path,
			"LogicalLocationData",
			ResourceLoader.CACHE_MODE_IGNORE
		) as LogicalLocationData
		if data == null or data.location_id != definition.location_id:
			push_error("Location '%s' has invalid LogicalLocationData." % definition.location_id)
			valid = false
			continue
		_locations[definition.location_id] = LogicalLocation.new(data, _entity_registry)
	if not valid:
		_locations.clear()
		return false
	return _validate_location_graph()


func _validate_location_graph() -> bool:
	var valid := true
	for definition in _world_definition.get_locations():
		var source := _locations.get(definition.location_id) as LogicalLocation
		if source == null:
			valid = false
			continue
		for edge in definition.outgoing_edges:
			var target := _locations.get(edge.to_location) as LogicalLocation
			if target == null or target.get_entry(edge.to_entry).is_empty():
				push_error(
					"Location edge '%s/%s' targets missing logical Entry '%s/%s'."
					% [definition.location_id, edge.edge_key, edge.to_location, edge.to_entry]
				)
				valid = false
			if source.get_exit(edge.edge_key).is_empty():
				push_error(
					"Logical Location '%s' has no Exit for edge_key '%s'."
					% [definition.location_id, edge.edge_key]
				)
				valid = false
	return valid


func _on_entities_committed(entities: Array[Entity]) -> void:
	for entity in entities:
		var location := _locations.get(entity.current_location_id) as LogicalLocation
		if location != null:
			location.index_entity(entity)
