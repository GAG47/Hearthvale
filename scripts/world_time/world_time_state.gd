class_name WorldTimeState
extends RefCounted

# The single authoritative calendar fact for the current world runtime.
var total_minutes: int


func _init(p_total_minutes := 0) -> void:
	total_minutes = maxi(p_total_minutes, 0)
