@tool
class_name FurnitureDefinition
extends Resource

const SUPPORTED_BEHAVIORS: Array[String] = ["sleepable", "openable", "inspectable"]

@export var display_name := ""
@export var visual: Texture2D
@export var behaviors: Dictionary = {}
@export var occupied_cells := Vector2i.ONE
@export var blocks_movement := true


func get_validation_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if display_name.strip_edges().is_empty():
		warnings.append("FurnitureDefinition display_name must not be empty.")
	if visual == null:
		warnings.append("FurnitureDefinition visual must reference a Texture2D.")
	if occupied_cells.x <= 0 or occupied_cells.y <= 0:
		warnings.append("FurnitureDefinition occupied_cells must contain positive values.")
	for raw_behavior_id: Variant in behaviors.keys():
		if not raw_behavior_id is String:
			warnings.append("FurnitureDefinition behavior IDs must be Strings.")
			continue
		var behavior_id: String = raw_behavior_id
		if not SUPPORTED_BEHAVIORS.has(behavior_id):
			warnings.append("FurnitureDefinition behavior '%s' is unsupported." % behavior_id)
			continue
		var raw_config: Variant = behaviors[behavior_id]
		if not raw_config is Dictionary:
			warnings.append("FurnitureDefinition behavior '%s' config must be a Dictionary." % behavior_id)
			continue
		var config: Dictionary = raw_config
		match behavior_id:
			"openable":
				if not config.has("open_visual") or not config["open_visual"] is Texture2D:
					warnings.append("FurnitureDefinition openable.open_visual must reference a Texture2D.")
			"inspectable":
				if (
					not config.has("text")
					or not config["text"] is String
					or (config["text"] as String).strip_edges().is_empty()
				):
					warnings.append("FurnitureDefinition inspectable.text must be a non-empty String.")
	return warnings
