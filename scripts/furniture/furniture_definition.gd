@tool
class_name FurnitureDefinition
extends Resource

const SUPPORTED_BEHAVIORS: Array[String] = ["sleepable", "openable", "inspectable"]

@export var display_name := "":
	set(value):
		display_name = value
		emit_changed()

@export var visual: Texture2D:
	set(value):
		visual = value
		emit_changed()

@export var behaviors: Dictionary = {}:
	set(value):
		behaviors = value
		emit_changed()

@export var occupied_cells := Vector2i.ONE:
	set(value):
		occupied_cells = value
		emit_changed()

@export var blocks_movement := true:
	set(value):
		blocks_movement = value
		emit_changed()

@export var use_slots: Array[UseSlotDefinition] = []:
	set(value):
		_disconnect_use_slots()
		use_slots = value.duplicate()
		_connect_use_slots()
		emit_changed()


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
	var supported_actions := get_configured_action_ids()
	for slot in use_slots:
		if slot == null:
			warnings.append("FurnitureDefinition use_slots must not contain null.")
			continue
		warnings.append_array(slot.get_validation_warnings())
		for action_id in slot.supported_actions:
			if not supported_actions.has(action_id):
				warnings.append(
					"FurnitureDefinition Use Slot action '%s' is not provided by its behaviors."
					% action_id
				)
	return warnings


func get_configured_action_ids() -> Array[StringName]:
	var action_ids: Array[StringName] = []
	if behaviors.has("sleepable"):
		action_ids.append(&"sleep")
	if behaviors.has("openable"):
		action_ids.append(&"open")
		action_ids.append(&"close")
	if behaviors.has("inspectable"):
		action_ids.append(&"inspect")
	return action_ids


func _connect_use_slots() -> void:
	for slot in use_slots:
		if slot != null and not slot.changed.is_connected(_on_use_slot_changed):
			slot.changed.connect(_on_use_slot_changed)


func _disconnect_use_slots() -> void:
	for slot in use_slots:
		if slot != null and slot.changed.is_connected(_on_use_slot_changed):
			slot.changed.disconnect(_on_use_slot_changed)


func _on_use_slot_changed() -> void:
	emit_changed()
