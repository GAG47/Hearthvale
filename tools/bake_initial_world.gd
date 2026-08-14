extends SceneTree

const OUTPUT_PATH := "res://data/world/initial_entities.json"
const OUTPUT_ARGUMENT_PREFIX := "--output="


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world_definition := root.get_node_or_null("WorldDefinition") as WorldDefinitionRuntime
	var output_path := _read_output_path(OS.get_cmdline_user_args())
	var success := bake_initial_world(world_definition, output_path)
	if success:
		print("Bake Initial World wrote '%s'." % output_path)
	quit(0 if success else 1)


static func _read_output_path(arguments: PackedStringArray) -> String:
	for argument in arguments:
		if argument.begins_with(OUTPUT_ARGUMENT_PREFIX):
			return argument.trim_prefix(OUTPUT_ARGUMENT_PREFIX)
	return OUTPUT_PATH


static func bake_initial_world(
	world_definition: WorldDefinitionRuntime,
	output_path: String = OUTPUT_PATH
) -> bool:
	if world_definition == null or not world_definition.definitions_valid:
		push_error("Bake Initial World requires valid WorldDefinition data.")
		return false
	return bake_definitions(
		world_definition.get_locations(),
		EntityBakerRegistry.create_default(),
		output_path
	)


static func bake_definitions(
	location_definitions: Array[LocationDefinition],
	baker_registry: EntityBakerRegistry,
	output_path: String
) -> bool:
	if baker_registry == null:
		push_error("Bake Initial World requires an EntityBakerRegistry.")
		return false
	if output_path.strip_edges().is_empty():
		push_error("Bake Initial World requires a non-empty output path.")
		return false
	if not WorldDefinitionRuntime.validate_definitions(location_definitions):
		push_error("Bake Initial World received invalid LocationDefinition data.")
		return false

	var sorted_definitions := location_definitions.duplicate()
	sorted_definitions.sort_custom(
		func(a: LocationDefinition, b: LocationDefinition) -> bool:
			return String(a.location_id) < String(b.location_id)
	)
	var baked_entities: Array[Dictionary] = []
	for definition in sorted_definitions:
		var packed_scene := ResourceLoader.load(definition.scene_path) as PackedScene
		if packed_scene == null:
			push_error(
				"Bake Initial World could not load Location '%s' Scene '%s'."
				% [definition.location_id, definition.scene_path]
			)
			return false
		var scene_instance := packed_scene.instantiate()
		var location := scene_instance as GridScene
		if location == null:
			push_error(
				"Bake Initial World expected GridScene for Location '%s' Scene '%s'."
				% [definition.location_id, definition.scene_path]
			)
			if is_instance_valid(scene_instance):
				scene_instance.free()
			return false
		if location.location_id != definition.location_id:
			push_error(
				"Bake Initial World requested Location '%s', but Scene '%s' declares '%s'."
				% [definition.location_id, definition.scene_path, location.location_id]
			)
			location.free()
			return false

		var placements: Array[EntityPlacement] = []
		_collect_placements(location, placements)
		for placement in placements:
			var baker := baker_registry.get_baker(placement)
			if baker == null:
				location.free()
				return false
			var location_local_position := location.to_local(placement.global_position)
			var entity_data := baker.bake(
				placement,
				definition.location_id,
				location_local_position
			)
			if entity_data.is_empty() or not _validate_baked_entity(entity_data):
				location.free()
				return false
			baked_entities.append(entity_data)
		location.free()

	return _write_output(output_path, baked_entities)


static func _collect_placements(
	node: Node,
	placements: Array[EntityPlacement]
) -> void:
	for child in node.get_children():
		if child is EntityPlacement:
			placements.append(child as EntityPlacement)
		_collect_placements(child, placements)


static func _validate_baked_entity(entity_data: Dictionary) -> bool:
	for field in ["entity_type", "definition_uid", "location_id"]:
		if not entity_data.has(field) or not entity_data[field] is String:
			push_error("Baked Entity field '%s' must be a String." % field)
			return false
		var value: String = entity_data[field]
		if value.strip_edges().is_empty():
			push_error("Baked Entity field '%s' must not be empty." % field)
			return false
	if not entity_data.has("local_position") or not entity_data["local_position"] is Array:
		push_error("Baked Entity field 'local_position' must be an Array.")
		return false
	var position_values: Array = entity_data["local_position"]
	if (
		position_values.size() != 2
		or not _is_number(position_values[0])
		or not _is_number(position_values[1])
		or not is_finite(float(position_values[0]))
		or not is_finite(float(position_values[1]))
	):
		push_error("Baked Entity field 'local_position' requires two finite numbers.")
		return false
	if entity_data["entity_type"] == "actor":
		if not entity_data.has("initial_facing") or not entity_data["initial_facing"] is String:
			push_error("Baked Actor requires String field 'initial_facing'.")
			return false
		if not ["up", "down", "left", "right"].has(entity_data["initial_facing"]):
			push_error("Baked Actor has invalid initial_facing '%s'." % entity_data["initial_facing"])
			return false
	return true


static func _write_output(output_path: String, entities: Array[Dictionary]) -> bool:
	var output_directory := ProjectSettings.globalize_path(output_path.get_base_dir())
	var directory_error := DirAccess.make_dir_recursive_absolute(output_directory)
	if directory_error != OK:
		push_error(
			"Bake Initial World could not create output directory '%s': %s."
			% [output_path.get_base_dir(), error_string(directory_error)]
		)
		return false

	var temporary_path := "%s.tmp" % output_path
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_error(
			"Bake Initial World could not open temporary output '%s': %s."
			% [temporary_path, error_string(FileAccess.get_open_error())]
		)
		return false
	var output_data := {
		"schema_version": InitialEntityDataSchema.VERSION,
		"entities": entities,
	}
	file.store_string(JSON.stringify(output_data, "\t") + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		push_error(
			"Bake Initial World failed to write '%s': %s."
			% [temporary_path, error_string(write_error)]
		)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
		return false

	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary_path),
		ProjectSettings.globalize_path(output_path)
	)
	if rename_error != OK:
		push_error(
			"Bake Initial World could not replace '%s': %s."
			% [output_path, error_string(rename_error)]
		)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
		return false
	return true


static func _is_number(value: Variant) -> bool:
	return value is int or value is float
