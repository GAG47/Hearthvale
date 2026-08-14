extends SceneTree

const BAKE_TOOL := preload("res://tools/bake_initial_world.gd")
const PLAYER_PATH := "res://data/actors/player.tres"
const MARTHA_PATH := "res://data/actors/martha.tres"
const BED_PATH := "res://data/furniture/simple_bed.tres"
const CHEST_PATH := "res://data/furniture/wooden_chest.tres"
const SIGN_PATH := "res://data/furniture/sign.tres"
const PLAYER_UID := "uid://3dfe1o8emqpj"
const MARTHA_UID := "uid://dscpwfh6l65fh"
const BED_UID := "uid://cau5iorciyxt8"
const CHEST_UID := "uid://d1t0crg266u0f"
const SIGN_UID := "uid://d0hdcbqvh7bfb"
const UID_RENAME_BEFORE := "user://v9_2_uid_before.tres"
const UID_RENAME_AFTER := "user://v9_2_uid_after.tres"
const SCHEMA_BAKE_PATH := "user://v9_2_schema_bake.json"
const WRONG_SCHEMA_PATH := "user://v9_2_wrong_schema.json"

var _checks := 0
var _failures := 0


class TrackingActorPlacement:
	extends ActorPlacement

	var refresh_count := 0


	func _refresh_preview() -> void:
		refresh_count += 1
		super._refresh_preview()


class TrackingFurniturePlacement:
	extends FurniturePlacement

	var refresh_count := 0


	func _refresh_preview() -> void:
		refresh_count += 1
		super._refresh_preview()


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var player := load(PLAYER_PATH) as ActorDefinition
	var martha := load(MARTHA_PATH) as ActorDefinition
	var bed := load(BED_PATH) as FurnitureDefinition
	var chest := load(CHEST_PATH) as FurnitureDefinition
	var sign := load(SIGN_PATH) as FurnitureDefinition
	_test_actor_resources(player, martha)
	_test_furniture_resources(bed, chest, sign)
	_test_resource_uid_loading()
	_test_placements_and_previews(martha, bed, chest)
	_test_resource_change_notifications()
	_test_definition_validation_consistency()
	_test_bakers_and_factories(martha, chest)
	_test_schema_version()
	_test_resource_uid_rename()
	_test_removed_json_chain()
	_finish()


func _test_actor_resources(player: ActorDefinition, martha: ActorDefinition) -> void:
	_expect(player != null and martha != null, "ActorDefinition .tres files must load as ActorDefinition.")
	if player == null or martha == null:
		return
	_expect(player is Resource and martha is Resource, "ActorDefinition must extend Resource.")
	_expect(player.display_name == "玩家" and martha.display_name == "Martha", "Actor names must migrate unchanged.")
	_expect(_get_resource_uid(player) == PLAYER_UID, "Player must use its stable ResourceUID.")
	_expect(_get_resource_uid(martha) == MARTHA_UID, "Martha must use its stable ResourceUID.")
	_expect(player.get_validation_warnings().is_empty(), "Player Resource must be valid.")
	_expect(martha.get_validation_warnings().is_empty(), "Martha Resource must be valid.")
	for direction in ActorDefinition.VISUAL_DIRECTIONS:
		_expect(player.get_visual(direction) is Texture2D, "Player visual_%s must be Texture2D." % direction)
		_expect(martha.get_visual(direction) is Texture2D, "Martha visual_%s must be Texture2D." % direction)
	_expect(not _object_has_property(player, &"definition_id"), "Static Definition must not keep custom definition_id.")


func _test_furniture_resources(
	bed: FurnitureDefinition,
	chest: FurnitureDefinition,
	sign: FurnitureDefinition
) -> void:
	_expect(bed != null and chest != null and sign != null, "Furniture .tres files must load as FurnitureDefinition.")
	if bed == null or chest == null or sign == null:
		return
	for definition in [bed, chest, sign]:
		_expect(definition is Resource, "FurnitureDefinition must extend Resource.")
		_expect(definition.visual is Texture2D, "Furniture visual must be Texture2D.")
		_expect(definition.get_validation_warnings().is_empty(), "Furniture Resource must validate.")
		_expect(not _object_has_property(definition, &"definition_id"), "Furniture must not keep definition_id.")
	_expect(_get_resource_uid(bed) == BED_UID, "Bed ResourceUID must remain stable.")
	_expect(_get_resource_uid(chest) == CHEST_UID, "Chest ResourceUID must remain stable.")
	_expect(_get_resource_uid(sign) == SIGN_UID, "Sign ResourceUID must remain stable.")
	_expect(bed.display_name == "床" and bed.occupied_cells == Vector2i(1, 2), "Bed data must migrate unchanged.")
	_expect(bed.behaviors.has("sleepable"), "Bed sleepable behavior must migrate.")
	_expect(chest.display_name == "储物箱" and chest.behaviors.has("openable"), "Chest data must migrate.")
	var openable_config: Dictionary = chest.behaviors["openable"]
	_expect(openable_config["open_visual"] is Texture2D, "Chest open visual must be a Texture2D Resource.")
	_expect(sign.display_name == "告示牌" and sign.behaviors.has("inspectable"), "Sign data must migrate.")
	_expect(sign.behaviors["inspectable"]["text"] == "今日麦酒三铜币。", "Sign text must migrate unchanged.")


func _test_resource_uid_loading() -> void:
	for pair in [
		[PLAYER_UID, ActorDefinition],
		[MARTHA_UID, ActorDefinition],
		[BED_UID, FurnitureDefinition],
		[CHEST_UID, FurnitureDefinition],
		[SIGN_UID, FurnitureDefinition],
	]:
		var uid: String = pair[0]
		var expected_script: GDScript = pair[1]
		var loaded_resource := ResourceLoader.load(uid)
		_expect(loaded_resource != null, "ResourceUID '%s' must resolve." % uid)
		_expect(loaded_resource.get_script() == expected_script, "ResourceUID '%s' must resolve the correct Definition type." % uid)


func _test_placements_and_previews(
	martha: ActorDefinition,
	bed: FurnitureDefinition,
	chest: FurnitureDefinition
) -> void:
	var actor_placement := ActorPlacement.new()
	_expect(not actor_placement._get_configuration_warnings().is_empty(), "ActorPlacement without Definition must warn.")
	actor_placement.definition = martha
	actor_placement.initial_facing = ActorState.Facing.DOWN
	_expect(actor_placement.definition == martha, "ActorPlacement must directly reference ActorDefinition.")
	_expect(actor_placement.get_preview_texture() == martha.visual_down, "Actor Preview must use initial facing visual.")
	actor_placement.initial_facing = ActorState.Facing.LEFT
	_expect(actor_placement.get_preview_texture() == martha.visual_left, "Actor Preview must refresh after facing changes.")
	_expect(actor_placement._get_configuration_warnings().is_empty(), "Valid ActorPlacement must have no warnings.")
	var invalid_actor_definition := ActorDefinition.new()
	invalid_actor_definition.display_name = "Invalid Actor"
	actor_placement.definition = invalid_actor_definition
	_expect(not actor_placement._get_configuration_warnings().is_empty(), "Missing facing visual must warn.")

	var furniture_placement := FurniturePlacement.new()
	_expect(not furniture_placement._get_configuration_warnings().is_empty(), "FurniturePlacement without Definition must warn.")
	furniture_placement.position = Vector2(656.0, 128.0)
	furniture_placement.definition = bed
	_expect(furniture_placement.definition == bed, "FurniturePlacement must directly reference FurnitureDefinition.")
	_expect(furniture_placement.get_preview_texture() == bed.visual, "Furniture Preview must use Definition visual.")
	var preview_rects := furniture_placement.get_preview_cell_rects()
	_expect(preview_rects.size() == 2, "Bed Preview must show both occupied cells.")
	var preview_world_cells: Array[Vector2i] = []
	for rect in preview_rects:
		preview_world_cells.append(Vector2i((rect.position + furniture_placement.position) / GridScene.CELL_SIZE))
	var preview_furniture := Furniture.new(
		bed,
		FurnitureState.new(
			&"88888888-8888-4888-8888-888888888888",
			&"tavern",
			furniture_placement.position
		)
	)
	_expect(preview_world_cells == preview_furniture.get_occupied_grid_cells(), "Preview occupied cells must match runtime rules.")
	furniture_placement.definition = chest
	_expect(furniture_placement.get_preview_cell_rects().size() == 1, "Preview must refresh after Definition changes.")
	_expect(furniture_placement._get_configuration_warnings().is_empty(), "Valid FurniturePlacement must have no warnings.")
	var invalid_furniture_definition := FurnitureDefinition.new()
	invalid_furniture_definition.display_name = "Invalid Furniture"
	invalid_furniture_definition.occupied_cells = Vector2i.ZERO
	furniture_placement.definition = invalid_furniture_definition
	_expect(furniture_placement._get_configuration_warnings().size() >= 2, "Missing visual and invalid occupied_cells must warn.")

	actor_placement.free()
	furniture_placement.free()


func _test_resource_change_notifications() -> void:
	var player_up := load("res://assets/actors/player_up.svg") as Texture2D
	var player_down := load("res://assets/actors/player_down.svg") as Texture2D
	var player_left := load("res://assets/actors/player_left.svg") as Texture2D
	var player_right := load("res://assets/actors/player_right.svg") as Texture2D
	var martha_up := load("res://assets/actors/martha_up.svg") as Texture2D
	var martha_down := load("res://assets/actors/martha_down.svg") as Texture2D
	var martha_left := load("res://assets/actors/martha_left.svg") as Texture2D
	var martha_right := load("res://assets/actors/martha_right.svg") as Texture2D
	var actor_definition := ActorDefinition.new()
	actor_definition.display_name = "Preview Actor"
	actor_definition.visual_up = player_up
	actor_definition.visual_down = player_down
	actor_definition.visual_left = player_left
	actor_definition.visual_right = player_right
	var actor_placement := TrackingActorPlacement.new()
	actor_placement.initial_facing = ActorState.Facing.DOWN
	actor_placement.definition = actor_definition
	var actor_changed_events := [0]
	actor_definition.changed.connect(func(): actor_changed_events[0] += 1)
	var actor_refresh_start := actor_placement.refresh_count
	actor_definition.display_name = "Updated Preview Actor"
	actor_definition.visual_up = martha_up
	actor_definition.visual_down = martha_down
	actor_definition.visual_left = martha_left
	actor_definition.visual_right = martha_right
	_expect(actor_changed_events[0] == 5, "Every ActorDefinition export must emit changed when assigned.")
	_expect(
		actor_placement.refresh_count == actor_refresh_start + 5,
		"Bound ActorPlacement must refresh for every ActorDefinition change."
	)
	_expect(
		actor_placement.get_preview_texture() == martha_down,
		"Actor Preview must immediately use a changed facing visual."
	)
	actor_definition.visual_down = null
	_expect(actor_changed_events[0] == 6, "Clearing an Actor visual must emit changed.")
	_expect(actor_placement.get_preview_texture() == null, "Actor Preview must clear an invalid changed visual.")
	_expect(
		not actor_placement._get_configuration_warnings().is_empty(),
		"Actor warnings must update after a bound visual becomes invalid."
	)

	var sign_texture := load("res://assets/furniture/sign.svg") as Texture2D
	var chest_texture := load("res://assets/furniture/chest_closed.svg") as Texture2D
	var furniture_definition := FurnitureDefinition.new()
	furniture_definition.display_name = "Preview Furniture"
	furniture_definition.visual = sign_texture
	furniture_definition.behaviors = {"inspectable": {"text": "Preview"}}
	furniture_definition.occupied_cells = Vector2i.ONE
	furniture_definition.blocks_movement = true
	var furniture_placement := TrackingFurniturePlacement.new()
	furniture_placement.position = Vector2(64.0, 64.0)
	furniture_placement.definition = furniture_definition
	var furniture_changed_events := [0]
	furniture_definition.changed.connect(func(): furniture_changed_events[0] += 1)
	var furniture_refresh_start := furniture_placement.refresh_count
	furniture_definition.display_name = "Updated Preview Furniture"
	furniture_definition.visual = chest_texture
	furniture_definition.behaviors = {"unsupported": {}}
	furniture_definition.occupied_cells = Vector2i(1, 2)
	furniture_definition.blocks_movement = false
	_expect(
		furniture_changed_events[0] == 5,
		"Every FurnitureDefinition export must emit changed when assigned."
	)
	_expect(
		furniture_placement.refresh_count == furniture_refresh_start + 5,
		"Bound FurniturePlacement must refresh for every Definition change."
	)
	_expect(
		furniture_placement.get_preview_texture() == chest_texture,
		"Furniture Preview must immediately use a changed visual."
	)
	_expect(
		furniture_placement.get_preview_cell_rects().size() == 2,
		"Furniture occupied-cell Preview must immediately reflect a changed size."
	)
	_expect(
		not furniture_placement._get_configuration_warnings().is_empty(),
		"Furniture warnings must update after a bound behavior becomes invalid."
	)
	actor_placement.free()
	furniture_placement.free()


func _test_definition_validation_consistency() -> void:
	var actor_definition := ActorDefinition.new()
	actor_definition.display_name = "Invalid Actor"
	actor_definition.visual_down = load("res://assets/actors/player_down.svg") as Texture2D
	actor_definition.visual_left = load("res://assets/actors/player_left.svg") as Texture2D
	actor_definition.visual_right = load("res://assets/actors/player_right.svg") as Texture2D
	var actor_placement := ActorPlacement.new()
	actor_placement.definition = actor_definition
	actor_placement.initial_facing = ActorState.Facing.DOWN
	var actor_definition_warnings := actor_definition.get_validation_warnings()
	var actor_placement_warnings := actor_placement._get_configuration_warnings()
	_expect(
		_contains_all_warnings(actor_placement_warnings, actor_definition_warnings),
		"ActorPlacement warnings must include the complete ActorDefinition validation."
	)
	_expect(
		ActorBaker.new().bake(actor_placement, &"tavern").is_empty(),
		"Actor Editor and Baking validation must both reject the same invalid Definition."
	)

	var furniture_definition := FurnitureDefinition.new()
	furniture_definition.display_name = "Invalid Furniture"
	furniture_definition.visual = load("res://assets/furniture/sign.svg") as Texture2D
	furniture_definition.behaviors = {"unsupported": {}}
	furniture_definition.occupied_cells = Vector2i.ONE
	var furniture_placement := FurniturePlacement.new()
	furniture_placement.definition = furniture_definition
	var furniture_definition_warnings := furniture_definition.get_validation_warnings()
	var furniture_placement_warnings := furniture_placement._get_configuration_warnings()
	_expect(
		_contains_all_warnings(furniture_placement_warnings, furniture_definition_warnings),
		"FurniturePlacement warnings must include complete FurnitureDefinition validation."
	)
	_expect(
		FurnitureBaker.new().bake(furniture_placement, &"tavern").is_empty(),
		"Furniture Editor and Baking validation must both reject the same invalid Definition."
	)
	actor_placement.free()
	furniture_placement.free()


func _test_bakers_and_factories(
	martha: ActorDefinition,
	chest: FurnitureDefinition
) -> void:
	var actor_placement := ActorPlacement.new()
	actor_placement.definition = martha
	actor_placement.position = Vector2(400.0, 200.0)
	actor_placement.initial_facing = ActorState.Facing.LEFT
	var actor_data := ActorBaker.new().bake(actor_placement, &"town_street")
	_expect(actor_data["definition_uid"] == MARTHA_UID, "ActorBaker must output definition_uid.")
	_expect(not actor_data.has("definition_path"), "ActorBaker must not output Definition path.")
	var actor := ActorEntityFactory.new().create(actor_data) as Actor
	_expect(actor != null and actor.definition == martha, "ActorEntityFactory must load ActorDefinition by UID.")
	if actor != null:
		_expect(UuidValidator.is_valid_v4(actor.entity_id), "Actor Factory must still generate entity UUID.")

	var furniture_placement := FurniturePlacement.new()
	furniture_placement.definition = chest
	furniture_placement.position = Vector2(464.0, 208.0)
	var furniture_data := FurnitureBaker.new().bake(furniture_placement, &"tavern")
	_expect(furniture_data["definition_uid"] == CHEST_UID, "FurnitureBaker must output definition_uid.")
	_expect(not furniture_data.has("definition_path"), "FurnitureBaker must not output Definition path.")
	var furniture := FurnitureEntityFactory.new().create(furniture_data) as Furniture
	_expect(furniture != null and furniture.definition == chest, "FurnitureEntityFactory must load Definition by UID.")
	if furniture != null:
		_expect(UuidValidator.is_valid_v4(furniture.entity_id), "Furniture Factory must still generate entity UUID.")
		_expect(furniture.get_openable_state() is OpenableState, "Furniture BehaviorState initialization must remain.")
	actor_placement.free()
	furniture_placement.free()


func _test_schema_version() -> void:
	_expect(InitialEntityDataSchema.VERSION == 2, "Initial Entity Data current Schema Version must be 2.")
	var current_root := _read_json_dictionary("res://data/world/initial_entities.json")
	_expect(current_root.get("schema_version") == 2, "Committed Initial Entity Data must use Schema Version 2.")
	_expect(
		InitialEntityDataLoader.load_from_file("res://data/world/initial_entities.json") is Array,
		"InitialEntityDataLoader must accept current Version 2 data."
	)

	var wrong_schema_file := FileAccess.open(WRONG_SCHEMA_PATH, FileAccess.WRITE)
	_expect(wrong_schema_file != null, "Wrong-schema test data must be writable.")
	if wrong_schema_file != null:
		wrong_schema_file.store_string(JSON.stringify({"schema_version": 1, "entities": []}))
		wrong_schema_file.close()
		_expect(
			InitialEntityDataLoader.load_from_file(WRONG_SCHEMA_PATH) == null,
			"InitialEntityDataLoader must reject non-Version 2 data."
		)

	var world_definition := root.get_node_or_null("WorldDefinition") as WorldDefinitionRuntime
	_expect(world_definition != null, "Schema Baking test requires WorldDefinition.")
	if world_definition != null:
		_expect(
			BAKE_TOOL.bake_initial_world(world_definition, SCHEMA_BAKE_PATH),
			"Baking must produce Schema Version 2 data."
		)
		var baked_root := _read_json_dictionary(SCHEMA_BAKE_PATH)
		_expect(baked_root.get("schema_version") == 2, "Baking output must declare Schema Version 2.")
		_expect(
			InitialEntityDataLoader.load_from_file(SCHEMA_BAKE_PATH) is Array,
			"Loader must accept Version 2 output produced by Baking."
		)
	var loader_source := FileAccess.get_file_as_string(
		"res://scripts/entities/initial_entity_data_loader.gd"
	)
	var baker_source := FileAccess.get_file_as_string("res://tools/bake_initial_world.gd")
	_expect(
		loader_source.contains("InitialEntityDataSchema.VERSION")
		and baker_source.contains("InitialEntityDataSchema.VERSION"),
		"Loader and Baking Writer must share InitialEntityDataSchema.VERSION."
	)
	for path in [WRONG_SCHEMA_PATH, SCHEMA_BAKE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_resource_uid_rename() -> void:
	var temporary_definition := FurnitureDefinition.new()
	temporary_definition.display_name = "UID Rename Test"
	temporary_definition.visual = load("res://assets/furniture/sign.svg") as Texture2D
	temporary_definition.occupied_cells = Vector2i.ONE
	var save_error := ResourceSaver.save(temporary_definition, UID_RENAME_BEFORE)
	_expect(save_error == OK, "Temporary Resource must save before rename test.")
	if save_error != OK:
		return
	var temporary_uid := ResourceUID.create_id()
	ResourceUID.add_id(temporary_uid, UID_RENAME_BEFORE)
	var uid_text := ResourceUID.id_to_text(temporary_uid)
	_expect(ResourceLoader.load(uid_text) is FurnitureDefinition, "ResourceUID must load before rename.")
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(UID_RENAME_BEFORE),
		ProjectSettings.globalize_path(UID_RENAME_AFTER)
	)
	_expect(rename_error == OK, "Temporary Definition must move for ResourceUID test.")
	if rename_error == OK:
		ResourceUID.set_id(temporary_uid, UID_RENAME_AFTER)
		var moved_resource := ResourceLoader.load(
			uid_text,
			"",
			ResourceLoader.CACHE_MODE_IGNORE
		)
		_expect(moved_resource is FurnitureDefinition, "The same ResourceUID must resolve after path rename.")
		_expect(ResourceUID.get_id_path(temporary_uid) == UID_RENAME_AFTER, "ResourceUID mapping must follow renamed path.")
	ResourceUID.remove_id(temporary_uid)
	if FileAccess.file_exists(UID_RENAME_BEFORE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(UID_RENAME_BEFORE))
	if FileAccess.file_exists(UID_RENAME_AFTER):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(UID_RENAME_AFTER))


func _test_removed_json_chain() -> void:
	for path in [
		"res://data/actors/player.json",
		"res://data/actors/martha.json",
		"res://data/furniture/simple_bed.json",
		"res://data/furniture/wooden_chest.json",
		"res://data/furniture/sign.json",
		"res://scripts/actors/actor_definition_loader.gd",
		"res://scripts/furniture/furniture_definition_loader.gd",
	]:
		_expect(not FileAccess.file_exists(path), "Obsolete JSON chain file '%s' must be removed." % path)
	var actor_placement_source := FileAccess.get_file_as_string("res://scripts/placements/actor_placement.gd")
	var furniture_placement_source := FileAccess.get_file_as_string("res://scripts/placements/furniture_placement.gd")
	_expect(not actor_placement_source.contains("definition_path"), "ActorPlacement must not store path String.")
	_expect(not furniture_placement_source.contains("definition_path"), "FurniturePlacement must not store path String.")
	var initial_source := FileAccess.get_file_as_string("res://data/world/initial_entities.json")
	_expect(initial_source.contains("definition_uid"), "Initial Entity Data must contain definition_uid.")
	_expect(not initial_source.contains("definition_path"), "Initial Entity Data must not contain definition_path.")


func _get_resource_uid(resource: Resource) -> String:
	return ResourceUID.id_to_text(ResourceLoader.get_resource_uid(resource.resource_path))


func _object_has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if property["name"] == property_name:
			return true
	return false


func _contains_all_warnings(
	placement_warnings: PackedStringArray,
	definition_warnings: PackedStringArray
) -> bool:
	for warning in definition_warnings:
		if not placement_warnings.has(warning):
			return false
	return true


func _read_json_dictionary(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("Test failure: %s" % message)


func _finish() -> void:
	if _failures == 0:
		print("V9.2 Static Definition Resource + Entity Authoring: %d checks passed." % _checks)
		quit(0)
		return
	push_error(
		"V9.2 Static Definition Resource + Entity Authoring: %d of %d checks failed."
		% [_failures, _checks]
	)
	quit(1)
