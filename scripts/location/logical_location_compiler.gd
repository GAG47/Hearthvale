@tool
class_name LogicalLocationCompiler
extends RefCounted

const COMPILER_VERSION := 1
const WALKABLE_LAYER := &"walkable"
const MOVEMENT_COST_LAYER := &"movement_cost"


static func bake_definition(definition: LocationDefinition, force := false) -> bool:
	if definition == null:
		push_error("Location Bake requires a LocationDefinition.")
		return false
	var fingerprint := compute_source_fingerprint(definition.scene_path)
	if fingerprint.is_empty():
		return false
	if not force and not needs_bake(definition, fingerprint):
		print("Location Bake: '%s' is current; skipped." % definition.location_id)
		return true

	var data := compile_scene(definition.scene_path, fingerprint)
	if data == null:
		push_error(
			"Location Bake failed for '%s'; stale output must not be used."
			% definition.location_id
		)
		return false
	if data.location_id != definition.location_id:
		push_error(
			"Location Bake Scene '%s' declares location_id '%s', expected '%s'."
			% [definition.scene_path, data.location_id, definition.location_id]
		)
		return false

	var output_path := definition.logical_data_path
	var absolute_directory := ProjectSettings.globalize_path(output_path.get_base_dir())
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK:
		push_error(
			"Location Bake could not create '%s': %s."
			% [output_path.get_base_dir(), error_string(directory_error)]
		)
		return false
	var save_error := ResourceSaver.save(data, output_path)
	if save_error != OK:
		push_error(
			"Location Bake could not save '%s': %s."
			% [output_path, error_string(save_error)]
		)
		return false
	print("Location Bake: generated '%s'." % output_path)
	return true


static func needs_bake(definition: LocationDefinition, fingerprint := "") -> bool:
	if definition == null or definition.logical_data_path.is_empty():
		return true
	if not ResourceLoader.exists(definition.logical_data_path):
		return true
	var existing := ResourceLoader.load(
		definition.logical_data_path,
		"LogicalLocationData",
		ResourceLoader.CACHE_MODE_IGNORE
	) as LogicalLocationData
	if existing == null:
		return true
	var current_fingerprint := fingerprint
	if current_fingerprint.is_empty():
		current_fingerprint = compute_source_fingerprint(definition.scene_path)
	return not is_data_current(definition, existing, current_fingerprint)


static func is_data_current(
	definition: LocationDefinition,
	data: LogicalLocationData,
	fingerprint: String
) -> bool:
	return (
		definition != null
		and data != null
		and data.location_id == definition.location_id
		and data.compiler_version == COMPILER_VERSION
		and data.source_fingerprint == fingerprint
		and data.has_valid_grid_shape()
	)


static func validate_baked_graph(definitions: Array[LocationDefinition]) -> bool:
	var data_by_location: Dictionary[StringName, LogicalLocationData] = {}
	for definition in definitions:
		var data := ResourceLoader.load(
			definition.logical_data_path,
			"LogicalLocationData",
			ResourceLoader.CACHE_MODE_IGNORE
		) as LogicalLocationData
		if data == null or data.location_id != definition.location_id:
			push_error("Location Bake graph validation could not load '%s'." % definition.logical_data_path)
			return false
		data_by_location[definition.location_id] = data

	var valid := true
	for definition in definitions:
		var source := data_by_location[definition.location_id]
		for edge in definition.outgoing_edges:
			var target := data_by_location.get(edge.to_location) as LogicalLocationData
			if target == null or target.get_entry(edge.to_entry).is_empty():
				push_error(
					"Location Bake edge '%s/%s' targets missing logical Entry '%s/%s'."
					% [definition.location_id, edge.edge_key, edge.to_location, edge.to_entry]
				)
				valid = false
			if source.get_exit(edge.edge_key).is_empty():
				push_error(
					"Location Bake output '%s' has no Exit for edge_key '%s'."
					% [definition.location_id, edge.edge_key]
				)
				valid = false
	return valid


static func compile_scene(scene_path: String, fingerprint := "") -> LogicalLocationData:
	var packed_scene := ResourceLoader.load(
		scene_path,
		"PackedScene",
		ResourceLoader.CACHE_MODE_IGNORE
	) as PackedScene
	if packed_scene == null:
		push_error("Location Bake could not load Scene '%s'." % scene_path)
		return null
	var instance := packed_scene.instantiate()
	var location := instance as GridScene
	if location == null:
		push_error("Location Bake Scene '%s' must instantiate as GridScene." % scene_path)
		if is_instance_valid(instance):
			instance.free()
		return null
	if location.location_id.is_empty():
		push_error("Location Bake Scene '%s' requires a non-empty location_id." % scene_path)
		location.free()
		return null

	var tile_layers: Array[TileMapLayer] = []
	_collect_tile_layers(location, tile_layers)
	if tile_layers.is_empty():
		push_error("Location Bake Scene '%s' contains no TileMapLayer." % scene_path)
		location.free()
		return null

	var cell_values: Dictionary[Vector2i, Dictionary] = {}
	for layer in tile_layers:
		if not _collect_layer_cells(location, layer, cell_values, scene_path):
			location.free()
			return null
	if cell_values.is_empty():
		push_error("Location Bake Scene '%s' contains no logical Tiles." % scene_path)
		location.free()
		return null

	var bounds := _calculate_bounds(cell_values.keys())
	var walkability := PackedByteArray()
	var movement_costs := PackedInt32Array()
	var cell_count := bounds.size.x * bounds.size.y
	walkability.resize(cell_count)
	movement_costs.resize(cell_count)
	for cell_value: Variant in cell_values.keys():
		var cell: Vector2i = cell_value
		var index := _cell_index(bounds, cell)
		var values: Dictionary = cell_values[cell]
		walkability[index] = 1 if values["walkable"] else 0
		movement_costs[index] = values["movement_cost"] if values["walkable"] else 0

	var entries: Dictionary = {}
	var location_entries: Array[LocationEntry] = []
	_collect_location_entries(location, location_entries)
	for entry in location_entries:
		if entry.entry_id.is_empty() or entries.has(entry.entry_id):
			push_error(
				"Location Bake Scene '%s' has an empty or duplicate Entry ID '%s'."
				% [scene_path, entry.entry_id]
			)
			location.free()
			return null
		var entry_position := location.to_local(entry.global_position)
		var entry_cell := _position_to_cell(entry_position)
		if not bounds.has_point(entry_cell) or not _cell_is_walkable(cell_values, entry_cell):
			push_error(
				"Location Bake Entry '%s/%s' must be on a statically walkable Cell."
				% [location.location_id, entry.entry_id]
			)
			location.free()
			return null
		entries[entry.entry_id] = {
			"entry_id": entry.entry_id,
			"cell": entry_cell,
			"facing": int(entry.facing),
			"local_position": entry_position,
		}

	var exits: Dictionary = {}
	var location_exits: Array[LocationExit] = []
	_collect_location_exits(location, location_exits)
	for location_exit in location_exits:
		if location_exit.edge_key.is_empty() or exits.has(location_exit.edge_key):
			push_error(
				"Location Bake Scene '%s' has an empty or duplicate Exit edge_key '%s'."
				% [scene_path, location_exit.edge_key]
			)
			location.free()
			return null
		exits[location_exit.edge_key] = {
			"edge_key": location_exit.edge_key,
			"cell_rect": location_exit.cell_rect,
		}

	var data := LogicalLocationData.new()
	data.location_id = location.location_id
	data.bounds = bounds
	data.walkability = walkability
	data.movement_costs = movement_costs
	data.entries = entries
	data.exits = exits
	data.source_fingerprint = (
		fingerprint if not fingerprint.is_empty() else compute_source_fingerprint(scene_path)
	)
	data.compiler_version = COMPILER_VERSION
	location.free()
	return data


static func compute_source_fingerprint(scene_path: String) -> String:
	var source_paths: Dictionary[String, bool] = {}
	if not _collect_logical_sources(scene_path, source_paths):
		return ""
	var sorted_paths := source_paths.keys()
	sorted_paths.sort()
	var context := HashingContext.new()
	var start_error := context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		push_error("Location Bake could not initialize source fingerprint hashing.")
		return ""
	for path_value: Variant in sorted_paths:
		var path: String = path_value
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			var open_error := FileAccess.get_open_error()
			push_error(
				"Location Bake could not fingerprint '%s': %s."
				% [path, error_string(open_error)]
			)
			return ""
		context.update(path.to_utf8_buffer())
		context.update(file.get_buffer(file.get_length()))
		file.close()
	return context.finish().hex_encode()


static func _collect_logical_sources(
	scene_path: String,
	collected: Dictionary[String, bool]
) -> bool:
	if scene_path.is_empty() or not FileAccess.file_exists(scene_path):
		push_error("Location Bake source Scene '%s' does not exist." % scene_path)
		return false
	collected[scene_path] = true
	var file := FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		push_error("Location Bake could not inspect source Scene '%s'." % scene_path)
		return false
	var scene_text := file.get_as_text()
	file.close()
	for line in scene_text.split("\n"):
		if not line.begins_with("[ext_resource") or not line.contains("type=\"TileSet\""):
			continue
		var path_marker := "path=\""
		var path_start := line.find(path_marker)
		if path_start < 0:
			continue
		path_start += path_marker.length()
		var path_end := line.find("\"", path_start)
		if path_end < 0:
			continue
		var tile_set_path := line.substr(path_start, path_end - path_start)
		if not FileAccess.file_exists(tile_set_path):
			push_error("Location Bake TileSet source '%s' does not exist." % tile_set_path)
			return false
		collected[tile_set_path] = true
	return true


static func _collect_layer_cells(
	location: GridScene,
	layer: TileMapLayer,
	cell_values: Dictionary[Vector2i, Dictionary],
	scene_path: String
) -> bool:
	var tile_set := layer.tile_set
	if tile_set == null:
		push_error("Location Bake TileMapLayer '%s' in '%s' has no TileSet." % [layer.name, scene_path])
		return false
	if (
		tile_set.get_custom_data_layer_by_name(WALKABLE_LAYER) < 0
		or tile_set.get_custom_data_layer_by_name(MOVEMENT_COST_LAYER) < 0
	):
		push_error(
			"Location Bake TileSet on '%s' requires '%s' and '%s' Custom Data Layers."
			% [layer.name, WALKABLE_LAYER, MOVEMENT_COST_LAYER]
		)
		return false
	for source_cell in layer.get_used_cells():
		var tile_data := layer.get_cell_tile_data(source_cell)
		if tile_data == null:
			continue
		var raw_walkable: Variant = tile_data.get_custom_data(WALKABLE_LAYER)
		var raw_movement_cost: Variant = tile_data.get_custom_data(MOVEMENT_COST_LAYER)
		if not raw_walkable is bool or not raw_movement_cost is int:
			push_error(
				"Location Bake Tile '%s:%s' requires bool walkable and int movement_cost."
				% [layer.name, source_cell]
			)
			return false
		if raw_movement_cost <= 0:
			push_error(
				"Location Bake logical Tile '%s:%s' requires movement_cost > 0."
				% [layer.name, source_cell]
			)
			return false
		var layer_position := layer.map_to_local(source_cell)
		var location_position := location.to_local(layer.to_global(layer_position))
		var logical_cell := _position_to_cell(location_position)
		if cell_values.has(logical_cell):
			var existing: Dictionary = cell_values[logical_cell]
			existing["walkable"] = existing["walkable"] and raw_walkable
			if raw_walkable:
				existing["movement_cost"] = maxi(existing["movement_cost"], raw_movement_cost)
			cell_values[logical_cell] = existing
		else:
			cell_values[logical_cell] = {
				"walkable": raw_walkable,
				"movement_cost": raw_movement_cost if raw_walkable else 0,
			}
	return true


static func _calculate_bounds(cells: Array) -> Rect2i:
	var minimum: Vector2i = cells[0]
	var maximum := minimum
	for cell_value: Variant in cells:
		var cell: Vector2i = cell_value
		minimum = minimum.min(cell)
		maximum = maximum.max(cell)
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


static func _cell_index(bounds: Rect2i, cell: Vector2i) -> int:
	var relative := cell - bounds.position
	return relative.y * bounds.size.x + relative.x


static func _cell_is_walkable(
	cell_values: Dictionary[Vector2i, Dictionary],
	cell: Vector2i
) -> bool:
	return cell_values.has(cell) and (cell_values[cell] as Dictionary)["walkable"]


static func _position_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(
		floori(position.x / LogicalLocationData.CELL_SIZE),
		floori(position.y / LogicalLocationData.CELL_SIZE)
	)


static func _collect_tile_layers(node: Node, layers: Array[TileMapLayer]) -> void:
	for child in node.get_children():
		if child is TileMapLayer:
			layers.append(child as TileMapLayer)
		_collect_tile_layers(child, layers)


static func _collect_location_entries(node: Node, entries: Array[LocationEntry]) -> void:
	for child in node.get_children():
		if child is LocationEntry:
			entries.append(child as LocationEntry)
		_collect_location_entries(child, entries)


static func _collect_location_exits(node: Node, exits: Array[LocationExit]) -> void:
	for child in node.get_children():
		if child is LocationExit:
			exits.append(child as LocationExit)
		_collect_location_exits(child, exits)
