class_name UuidValidator
extends RefCounted


static func is_valid_v4(uuid: StringName) -> bool:
	var text := String(uuid)
	if text.length() != 36:
		return false
	if text[8] != "-" or text[13] != "-" or text[18] != "-" or text[23] != "-":
		return false
	if text[14].to_lower() != "4" or not "89ab".contains(text[19].to_lower()):
		return false

	for index in range(text.length()):
		if index == 8 or index == 13 or index == 18 or index == 23:
			continue
		if not "0123456789abcdef".contains(text[index].to_lower()):
			return false
	return true
