class_name LocationSceneBuilder
extends RefCounted

const WORLD_TILE_SET: TileSet = preload("res://data/world_tileset.tres")

func prepare_scene(
	location: LocationRuntime,
	representation_registry: EntityRepresentationRegistry,
	moving_entity: Entity = null,
	moving_position: Vector2 = Vector2.ZERO
) -> Dictionary:
	if location == null or not location.is_valid() or representation_registry == null:
		push_error("LocationSceneBuilder requires a valid Location and Representation Registry.")
		return {}
	var scene := GridScene.new()
	scene.name = "Location_%s" % String(location.instance_id).substr(0, 8)
	scene.configure(location)
	if not _build_ground(scene, location):
		scene.free()
		return {}
	if not _build_decorations(scene, location):
		scene.free()
		return {}
	if not _build_structures(scene, location):
		scene.free()
		return {}
	_build_anchors(scene, location)

	var representation_root := Node2D.new()
	representation_root.name = "EntityRepresentationRoot"
	scene.add_child(representation_root)
	var target_entities := location.get_entities()
	if moving_entity != null and not target_entities.has(moving_entity):
		target_entities.append(moving_entity)
	var representations: Dictionary[StringName, Node] = {}
	for entity in target_entities:
		var factory := representation_registry.get_factory(entity)
		if factory == null:
			scene.free()
			return {}
		var target_position := moving_position if entity == moving_entity else entity.local_position
		var representation := factory.prepare(entity, scene, target_position)
		if representation == null:
			scene.free()
			return {}
		representation_root.add_child(representation)
		representations[entity.instance_id] = representation
	return {"scene": scene, "representations": representations}


func _build_ground(scene: GridScene, location: LocationRuntime) -> bool:
	var layer := TileMapLayer.new()
	layer.name = "GroundLayer"
	layer.z_index = -10
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.collision_enabled = false
	layer.tile_set = WORLD_TILE_SET
	scene.add_child(layer)
	var current_ground := location.get_current_ground()
	for cell in current_ground:
		var ground := current_ground[cell]
		if ground == null or not _set_tile_from_presentation(layer, cell, ground.presentation):
			push_error("Could not build Ground cell %s for Location '%s'." % [cell, location.instance_id])
			return false
	return true


func _build_decorations(scene: GridScene, location: LocationRuntime) -> bool:
	var root := Node2D.new()
	root.name = "DecorationLayer"
	scene.add_child(root)
	var tile_layer: TileMapLayer
	for placement in location.get_current_decorations():
		var definition := (
			location.definition_registry.get_definition(placement.definition_id)
			as DecorationDefinition
		)
		if definition == null:
			return false
		match StringName(definition.presentation.get("kind", "")):
			&"label":
				var label := Label.new()
				label.name = "Decoration_%s" % String(placement.placement_id).substr(0, 8)
				label.position = GridSpace.cell_to_local_position(placement.cell, placement.local_offset)
				label.z_index = 2
				label.text = String(definition.presentation.get("text", ""))
				label.add_theme_font_size_override(
					"font_size", int(definition.presentation.get("font_size", 16))
				)
				label.add_theme_color_override(
					"font_color", Color.from_string(
						String(definition.presentation.get("font_color", "#ffffff")),
						Color.WHITE
					)
				)
				root.add_child(label)
			&"tile":
				if tile_layer == null:
					tile_layer = TileMapLayer.new()
					tile_layer.name = "TileDecorations"
					tile_layer.collision_enabled = false
					tile_layer.tile_set = WORLD_TILE_SET
					root.add_child(tile_layer)
				if not _set_tile_from_presentation(tile_layer, placement.cell, definition.presentation):
					return false
			_:
				push_error("DecorationDefinition '%s' has unsupported presentation." % definition.definition_id)
				return false
	return true


func _build_structures(scene: GridScene, location: LocationRuntime) -> bool:
	var layer := TileMapLayer.new()
	layer.name = "StructureLayer"
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.tile_set = WORLD_TILE_SET
	scene.add_child(layer)
	for placement in location.get_current_structures():
		var definition := (
			location.definition_registry.get_definition(placement.definition_id)
			as StructureDefinition
		)
		if definition == null:
			return false
		var presentation_tiles: Variant = definition.presentation.get("tiles", null)
		if not presentation_tiles is Array:
			push_error("StructureDefinition '%s' requires presentation tiles." % definition.definition_id)
			return false
		for raw_tile in presentation_tiles:
			if not raw_tile is Dictionary:
				return false
			var tile: Dictionary = raw_tile
			var local_cell := _vector2i(tile.get("offset", []))
			var world_cell := placement.origin_cell + StructurePlacement.transform_cell(
				local_cell, placement.orientation
			)
			if not _set_tile_from_presentation(layer, world_cell, tile):
				return false
	return true


func _build_anchors(scene: GridScene, location: LocationRuntime) -> void:
	var entry_root := Node2D.new()
	entry_root.name = "EntryPoints"
	scene.add_child(entry_root)
	for anchor in location.get_current_anchors():
		if anchor is LocationEntryAnchor:
			var entry_anchor := anchor as LocationEntryAnchor
			var entry := LocationEntry.new()
			entry.name = String(entry_anchor.entry_id)
			entry.entry_id = entry_anchor.entry_id
			entry.facing = entry_anchor.facing
			entry.position = entry_anchor.get_local_position()
			entry_root.add_child(entry)
		elif anchor is LocationExitAnchor:
			var exit_anchor := anchor as LocationExitAnchor
			var location_exit := LocationExit.new()
			location_exit.name = "Exit_%s" % exit_anchor.edge_key
			location_exit.edge_key = exit_anchor.edge_key
			location_exit.cell_rect = exit_anchor.cell_rect
			scene.add_child(location_exit)


func _set_tile_from_presentation(
	layer: TileMapLayer,
	cell: Vector2i,
	presentation: Dictionary
) -> bool:
	var atlas_coords := _vector2i(presentation.get("atlas_coords", []))
	layer.set_cell(
		cell,
		int(presentation.get("source_id", -1)),
		atlas_coords,
		int(presentation.get("alternative_tile", 0))
	)
	return layer.get_cell_source_id(cell) >= 0


static func _vector2i(raw_value: Variant) -> Vector2i:
	if not raw_value is Array or raw_value.size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(int(raw_value[0]), int(raw_value[1]))
