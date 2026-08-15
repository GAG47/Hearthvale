extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world_definition := root.get_node_or_null("WorldDefinition") as WorldDefinitionRuntime
	if world_definition == null or not world_definition.definitions_valid:
		push_error("Location Bake requires a valid WorldDefinition Autoload.")
		quit(1)
		return
	var force := OS.get_cmdline_user_args().has("--force")
	var success := true
	for definition in world_definition.get_locations():
		if not LogicalLocationCompiler.bake_definition(definition, force):
			success = false
	if success and not LogicalLocationCompiler.validate_baked_graph(world_definition.get_locations()):
		success = false
	if success:
		print("Location Bake preflight completed successfully.")
		quit(0)
		return
	push_error("Location Bake preflight failed; runtime data was not accepted.")
	quit(1)
