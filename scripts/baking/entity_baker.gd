@abstract
class_name EntityBaker
extends RefCounted


@abstract func supports(placement: EntityPlacement) -> bool


@abstract func bake(
	placement: EntityPlacement,
	location_id: StringName,
	location_local_position: Vector2
) -> Dictionary
