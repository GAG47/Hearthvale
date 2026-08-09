class_name InteractionTargetSelector
extends RefCounted

const INTERACTION_RANGE := 60.0
const INTERACTION_HALF_WIDTH := 24.0


static func select_target(actor: PlayerCharacter) -> WorldObject:
	var facing := actor.get_facing_vector()
	var nearest: WorldObject
	var nearest_distance_squared := INF

	for node in actor.get_tree().get_nodes_in_group(&"world_objects"):
		var candidate := node as WorldObject
		if candidate == null or candidate.location == null:
			continue
		if candidate.location != actor.current_location:
			continue
		if candidate.get_available_actions(actor).is_empty():
			continue

		var bounds := candidate.get_world_bounds()
		var closest_point := Vector2(
			clampf(actor.global_position.x, bounds.position.x, bounds.end.x),
			clampf(actor.global_position.y, bounds.position.y, bounds.end.y)
		)
		var offset := closest_point - actor.global_position
		var forward_distance := offset.dot(facing)
		var lateral_distance := absf(offset.dot(facing.orthogonal()))
		var distance_squared := offset.length_squared()

		if forward_distance < 0.0:
			continue
		if lateral_distance > INTERACTION_HALF_WIDTH:
			continue
		if distance_squared > INTERACTION_RANGE * INTERACTION_RANGE:
			continue
		if distance_squared < nearest_distance_squared:
			nearest = candidate
			nearest_distance_squared = distance_squared

	return nearest
