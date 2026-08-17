class_name ProjectWorldDataLoader
extends RefCounted


static func load_from_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ProjectWorldDataLoader failed to open '%s'." % path)
		return {}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		push_error(
			"ProjectWorldDataLoader failed to parse '%s' at line %d: %s."
			% [path, parser.get_error_line(), parser.get_error_message()]
		)
		return {}
	if not parser.data is Dictionary:
		push_error("ProjectWorldDataLoader expected a Dictionary root in '%s'." % path)
		return {}
	var data: Dictionary = parser.data
	if not data.get("definitions", null) is Array or not data.get("instances", null) is Array:
		push_error("ProjectWorldDataLoader '%s' requires definitions and instances Arrays." % path)
		return {}
	var definitions: Array[Definition] = []
	for raw_definition in data["definitions"]:
		if not raw_definition is Dictionary:
			push_error("ProjectWorldDataLoader '%s' contains a non-Dictionary Definition." % path)
			return {}
		var definition := _definition_from_data(raw_definition)
		if definition == null:
			return {}
		definitions.append(definition)
	var instances: Array[Dictionary] = []
	for raw_instance in data["instances"]:
		if not raw_instance is Dictionary:
			push_error("ProjectWorldDataLoader '%s' contains a non-Dictionary instance." % path)
			return {}
		var instance: Dictionary = raw_instance
		instances.append({
			"key": StringName(instance.get("key", "")),
			"instance_id": StringName(instance.get("instance_id", "")),
			"definition_id": StringName(instance.get("definition_id", "")),
		})
	return {"definitions": definitions, "instances": instances}


static func _definition_from_data(data: Dictionary) -> Definition:
	var definition_type := StringName(data.get("type", ""))
	var definition_id := StringName(data.get("definition_id", ""))
	match definition_type:
		&"ground_tile":
			return GroundTileDefinition.new(
				definition_id,
				StringName(data.get("key", "")),
				data.get("walkable", false),
				float(data.get("movement_cost", 1.0)),
				int(data.get("source_id", -1)),
				_vector2i(data.get("atlas_coords", [])),
				int(data.get("alternative_tile", 0))
			)
		&"decoration_tile":
			return DecorationTileDefinition.new(
				definition_id,
				StringName(data.get("key", "")),
				int(data.get("source_id", -1)),
				_vector2i(data.get("atlas_coords", [])),
				int(data.get("alternative_tile", 0))
			)
		&"structure_tile":
			return StructureTileDefinition.new(
				definition_id,
				StringName(data.get("key", "")),
				data.get("blocks_movement", false),
				int(data.get("source_id", -1)),
				_vector2i(data.get("atlas_coords", [])),
				int(data.get("alternative_tile", 0))
			)
		&"location":
			return _location_from_data(data)
		_:
			push_error(
				"ProjectWorldDataLoader does not support Definition type '%s'."
				% definition_type
			)
			return null


static func _location_from_data(data: Dictionary) -> LocationDefinition:
	var edges: Array[LocationEdgeDefinition] = []
	for raw_edge in data.get("topology", []):
		var edge: Dictionary = raw_edge
		edges.append(LocationEdgeDefinition.new(
			StringName(edge.get("edge_id", "")),
			StringName(edge.get("edge_key", "")),
			StringName(edge.get("target_location_id", "")),
			StringName(edge.get("target_entry_id", ""))
		))
	var layout: Dictionary = data.get("spatial_layout", {})
	var ground := _tile_layer_from_data(layout.get("ground_layer", []))
	var decorations := _tile_layer_from_data(layout.get("decoration_layer", []))
	var structures := _tile_layer_from_data(layout.get("structure_layer", []))
	var entries: Array[LocationEntry] = []
	for raw_entry in layout.get("entries", []):
		var entry: Dictionary = raw_entry
		entries.append(LocationEntry.new(
			StringName(entry.get("entry_id", "")),
			_vector2i(entry.get("cell", [])),
			int(entry.get("facing", ActorState.Facing.DOWN)) as ActorState.Facing
		))
	var exits: Array[LocationExit] = []
	for raw_exit in layout.get("exits", []):
		var exit_data: Dictionary = raw_exit
		exits.append(LocationExit.new(
			StringName(exit_data.get("edge_key", "")),
			_rect2i(exit_data.get("cell_rect", []))
		))
	return LocationDefinition.new(
		StringName(data.get("definition_id", "")),
		String(data.get("display_name", "")),
		_vector2i(data.get("grid_size", [])),
		edges,
		ground,
		decorations,
		structures,
		entries,
		exits
	)


static func _tile_layer_from_data(raw_layer: Variant) -> Dictionary[Vector2i, StringName]:
	var layer: Dictionary[Vector2i, StringName] = {}
	if not raw_layer is Array:
		return layer
	for raw_tile in raw_layer:
		if not raw_tile is Dictionary:
			continue
		var tile: Dictionary = raw_tile
		layer[_vector2i(tile.get("cell", []))] = StringName(tile.get("definition_id", ""))
	return layer


static func _vector2i(raw_value: Variant) -> Vector2i:
	if not raw_value is Array or raw_value.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(raw_value[0]), int(raw_value[1]))


static func _rect2i(raw_value: Variant) -> Rect2i:
	if not raw_value is Array or raw_value.size() != 4:
		return Rect2i()
	return Rect2i(
		int(raw_value[0]),
		int(raw_value[1]),
		int(raw_value[2]),
		int(raw_value[3])
	)
