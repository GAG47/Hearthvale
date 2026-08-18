class_name LocationSceneBuilder
extends RefCounted

const WORLD_TILE_SET: TileSet = preload("res://data/world_tileset.tres")

func prepare_scene(
	location: LocationRuntime,
	representation_registry: EntityRepresentationRegistry,
	moving_entity: Entity = null,
	moving_cell: Vector2i = Vector2i.ZERO
) -> Dictionary:
	if location == null or not location.is_valid() or representation_registry == null:
		push_error("LocationSceneBuilder requires a valid Location and Representation Registry.")
		return {}
	var scene := GridScene.new()
	scene.name = "Location_%s" % String(location.instance_id).substr(0, 8)
	scene.configure(location)
	if not _build_ground_layer(scene, location):
		scene.free()
		return {}
	if not _build_decoration_layer(scene, location):
		scene.free()
		return {}
	if not _build_structure_layer(scene, location):
		scene.free()
		return {}
	_build_entries_and_exits(scene, location)

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
		var target_cell := moving_cell if entity == moving_entity else entity.current_cell
		var representation := factory.prepare(entity, scene, target_cell)
		if representation == null:
			scene.free()
			return {}
		representation_root.add_child(representation)
		representations[entity.instance_id] = representation
	return {"scene": scene, "representations": representations}


func _build_ground_layer(scene: GridScene, location: LocationRuntime) -> bool:
	var layer := TileMapLayer.new()
	layer.name = "GroundLayer"
	layer.z_index = -10
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.collision_enabled = false
	layer.tile_set = WORLD_TILE_SET
	scene.add_child(layer)
	var current_layer := location.get_current_ground_layer()
	for cell in current_layer:
		var tile := current_layer[cell]
		if tile == null or not _set_tile(layer, cell, tile.source_id, tile.atlas_coords, tile.alternative_tile):
			push_error("Could not build Ground cell %s for Location '%s'." % [cell, location.instance_id])
			return false
	return true


func _build_decoration_layer(scene: GridScene, location: LocationRuntime) -> bool:
	var layer := TileMapLayer.new()
	layer.name = "DecorationLayer"
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.collision_enabled = false
	layer.tile_set = WORLD_TILE_SET
	scene.add_child(layer)
	var current_layer := location.get_current_decoration_layer()
	for cell in current_layer:
		var tile := current_layer[cell]
		if tile == null or not _set_tile(layer, cell, tile.source_id, tile.atlas_coords, tile.alternative_tile):
			push_error(
				"Could not build Decoration cell %s for Location '%s'."
				% [cell, location.instance_id]
			)
			return false
	return true


func _build_structure_layer(scene: GridScene, location: LocationRuntime) -> bool:
	var layer := TileMapLayer.new()
	layer.name = "StructureLayer"
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.tile_set = WORLD_TILE_SET
	scene.add_child(layer)
	var current_layer := location.get_current_structure_layer()
	for cell in current_layer:
		var tile := current_layer[cell]
		if tile == null or not _set_tile(layer, cell, tile.source_id, tile.atlas_coords, tile.alternative_tile):
			push_error(
				"Could not build Structure cell %s for Location '%s'."
				% [cell, location.instance_id]
			)
			return false
	return true


func _build_entries_and_exits(scene: GridScene, location: LocationRuntime) -> void:
	var entry_root := Node2D.new()
	entry_root.name = "EntryPoints"
	scene.add_child(entry_root)
	for entry in location.get_current_entries():
		for arrival_index in range(entry.arrival_cells.size()):
			var marker := Marker2D.new()
			marker.name = (
				String(entry.entry_id)
				if arrival_index == 0
				else "%s_%d" % [entry.entry_id, arrival_index]
			)
			marker.position = entry.get_center_position(arrival_index)
			entry_root.add_child(marker)
	for location_exit in location.get_current_exits():
		var exit_area := LocationExitArea.new()
		exit_area.name = "Exit_%s" % location_exit.edge_key
		exit_area.configure(location_exit)
		scene.add_child(exit_area)


func _set_tile(
	layer: TileMapLayer,
	cell: Vector2i,
	source_id: int,
	atlas_coords: Vector2i,
	alternative_tile: int
) -> bool:
	layer.set_cell(cell, source_id, atlas_coords, alternative_tile)
	return layer.get_cell_source_id(cell) >= 0
