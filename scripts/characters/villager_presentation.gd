class_name VillagerPresentation
extends CharacterPresentation


func _draw() -> void:
	draw_circle(Vector2(0.0, 7.0), 11.0, Color(0.08, 0.07, 0.07, 0.30))
	draw_circle(Vector2.ZERO, 11.0, Color("#6f4d78"))
	draw_circle(Vector2.ZERO, 8.0, Color("#a878a8"))

	var facing_vector := get_facing_vector()
	var side := facing_vector.orthogonal()
	draw_colored_polygon(
		PackedVector2Array([
			facing_vector * 13.0,
			facing_vector * 4.0 + side * 5.0,
			facing_vector * 4.0 - side * 5.0,
		]),
		Color("#f3ddb2")
	)
