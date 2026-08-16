class_name DefinitionCodec
extends RefCounted


static func from_data(data: Dictionary) -> Definition:
	var definition_type := StringName(data.get("type", ""))
	var definition_id := StringName(data.get("definition_id", ""))
	match definition_type:
		&"ground":
			return GroundDefinition.new(
				definition_id,
				StringName(data.get("key", "")),
				data.get("walkable", false),
				float(data.get("movement_cost", 1.0)),
				(data.get("presentation", {}) as Dictionary)
			)
		&"decoration":
			return DecorationDefinition.new(
				definition_id,
				StringName(data.get("key", "")),
				(data.get("presentation", {}) as Dictionary)
			)
		&"structure":
			var occupied_cells: Array[Vector2i] = []
			for raw_cell in data.get("occupied_cells", []):
				occupied_cells.append(_vector2i(raw_cell))
			return StructureDefinition.new(
				definition_id,
				StringName(data.get("key", "")),
				occupied_cells,
				data.get("blocks_movement", false),
				(data.get("presentation", {}) as Dictionary)
			)
		&"location":
			return _location_from_data(data)
		&"actor":
			var visuals: Dictionary[String, String] = {}
			for direction in data.get("visuals", {}):
				visuals[String(direction)] = String(data["visuals"][direction])
			return ActorDefinition.new(
				definition_id,
				String(data.get("display_name", "")),
				visuals
			)
		&"furniture":
			var occupied_size := _vector2i(data.get("occupied_cells", []))
			return FurnitureDefinition.new(
				definition_id,
				String(data.get("display_name", "")),
				String(data.get("visual_ref", "")),
				(data.get("behaviors", {}) as Dictionary),
				occupied_size,
				data.get("blocks_movement", false)
			)
		_:
			push_error("DefinitionCodec does not support Definition type '%s'." % definition_type)
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
	var ground: Dictionary[Vector2i, StringName] = {}
	for raw_group in layout.get("ground_layer", []):
		var group: Dictionary = raw_group
		var ground_definition_id := StringName(group.get("definition_id", ""))
		for raw_cell in group.get("cells", []):
			ground[_vector2i(raw_cell)] = ground_definition_id
	var decorations: Array[DecorationPlacement] = []
	for raw_placement in layout.get("decoration_placements", []):
		var placement: Dictionary = raw_placement
		decorations.append(DecorationPlacement.new(
			StringName(placement.get("placement_id", "")),
			StringName(placement.get("definition_id", "")),
			_vector2i(placement.get("cell", [])),
			_vector2(placement.get("local_offset", []))
		))
	var structures: Array[StructurePlacement] = []
	for raw_placement in layout.get("structure_placements", []):
		var placement: Dictionary = raw_placement
		structures.append(StructurePlacement.new(
			StringName(placement.get("placement_id", "")),
			StringName(placement.get("definition_id", "")),
			_vector2i(placement.get("origin_cell", [])),
			int(placement.get("orientation", 0))
		))
	var anchors: Array[LocationAnchor] = []
	for raw_anchor in layout.get("anchors", []):
		var anchor: Dictionary = raw_anchor
		match StringName(anchor.get("type", "")):
			&"entry":
				anchors.append(LocationEntryAnchor.new(
					StringName(anchor.get("entry_id", "")),
					_vector2i(anchor.get("cell", [])),
					int(anchor.get("facing", ActorState.Facing.DOWN)) as ActorState.Facing,
					_vector2(anchor.get("local_offset", [16, 16]))
				))
			&"exit":
				anchors.append(LocationExitAnchor.new(
					StringName(anchor.get("edge_key", "")),
					_rect2i(anchor.get("cell_rect", []))
				))
	return LocationDefinition.new(
		StringName(data.get("definition_id", "")),
		String(data.get("display_name", "")),
		_vector2i(data.get("grid_size", [])),
		edges,
		ground,
		decorations,
		structures,
		anchors
	)


static func _vector2i(raw_value: Variant) -> Vector2i:
	if not raw_value is Array or raw_value.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(raw_value[0]), int(raw_value[1]))


static func _vector2(raw_value: Variant) -> Vector2:
	if not raw_value is Array or raw_value.size() != 2:
		return Vector2.ZERO
	return Vector2(float(raw_value[0]), float(raw_value[1]))


static func _rect2i(raw_value: Variant) -> Rect2i:
	if not raw_value is Array or raw_value.size() != 4:
		return Rect2i()
	return Rect2i(
		int(raw_value[0]),
		int(raw_value[1]),
		int(raw_value[2]),
		int(raw_value[3])
	)
