@abstract
class_name EntityRepresentationFactory
extends RefCounted


@abstract func supports(entity: Entity) -> bool


@abstract func prepare(
	entity: Entity,
	target_location,
	target_cell: Vector2i,
	logical_movement: LogicalMovement = null
) -> Node
