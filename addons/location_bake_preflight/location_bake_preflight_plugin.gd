@tool
extends EditorPlugin


func _build() -> bool:
	var world_definition := WorldDefinitionRuntime.new()
	world_definition._ready()
	if not world_definition.definitions_valid:
		push_error("Editor Run stopped: Location Bake requires valid WorldDefinition data.")
		world_definition.free()
		return false

	var success := true
	for definition in world_definition.get_locations():
		if not LogicalLocationCompiler.bake_definition(definition):
			success = false
	if success:
		success = LogicalLocationCompiler.validate_baked_graph(
			world_definition.get_locations()
		)
	world_definition.free()
	if not success:
		push_error("Editor Run stopped because Location Bake Preflight failed.")
		return false

	get_editor_interface().get_resource_filesystem().scan_sources()
	return true
