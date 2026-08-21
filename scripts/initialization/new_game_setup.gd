@tool
class_name NewGameSetup
extends Resource

@export var initial_total_minutes := GameCalendar.INITIAL_TOTAL_MINUTES
@export var location_specs: Array[NewGameLocationSpec] = []
@export var entity_specs: Array[NewGameEntitySpec] = []
@export var controlled_actor_spec: NewGameActorSpec


func validate() -> bool:
	var valid := true
	if initial_total_minutes < 0:
		push_error("NewGameSetup initial_total_minutes cannot be negative.")
		valid = false

	var locations_by_id: Dictionary[StringName, NewGameLocationSpec] = {}
	for spec in location_specs:
		if spec == null or not spec.validate():
			valid = false
			continue
		if locations_by_id.has(spec.instance_id):
			push_error("NewGameSetup contains duplicate Location instance_id '%s'." % spec.instance_id)
			valid = false
			continue
		locations_by_id[spec.instance_id] = spec

	var entities_by_id: Dictionary[StringName, NewGameEntitySpec] = {}
	for spec in entity_specs:
		if spec == null or not spec.validate():
			valid = false
			continue
		if entities_by_id.has(spec.instance_id):
			push_error("NewGameSetup contains duplicate Entity instance_id '%s'." % spec.instance_id)
			valid = false
			continue
		entities_by_id[spec.instance_id] = spec
		if not location_specs.has(spec.initial_location):
			push_error("Entity '%s' references a Location outside this NewGameSetup." % spec.instance_id)
			valid = false

	if controlled_actor_spec == null:
		push_error("NewGameSetup requires a controlled Actor spec.")
		valid = false
	elif not entity_specs.has(controlled_actor_spec):
		push_error("NewGameSetup controlled_actor_spec must belong to entity_specs.")
		valid = false

	if not _validate_location_connections(locations_by_id):
		valid = false
	if not _validate_initial_placement():
		valid = false
	return valid


func _validate_location_connections(
	locations_by_id: Dictionary[StringName, NewGameLocationSpec]
) -> bool:
	var valid := true
	for source_spec in location_specs:
		if source_spec == null or source_spec.definition == null:
			continue
		for edge in source_spec.definition.outgoing_edges:
			if edge == null:
				continue
			var target_spec := locations_by_id.get(edge.target_location_id) as NewGameLocationSpec
			if target_spec == null:
				push_error(
					"Location '%s' edge '%s' targets unknown Location '%s'."
					% [source_spec.instance_id, edge.edge_key, edge.target_location_id]
				)
				valid = false
				continue
			if not target_spec.definition.has_entry(edge.target_entry_id):
				push_error(
					"Location '%s' edge '%s' targets missing Entry '%s'."
					% [source_spec.instance_id, edge.edge_key, edge.target_entry_id]
				)
				valid = false
	return valid


func _validate_initial_placement() -> bool:
	var valid := true
	var blocking_cells: Dictionary[StringName, Dictionary] = {}
	var actor_cells: Dictionary[StringName, Dictionary] = {}
	for spec in entity_specs:
		if spec == null or spec.initial_location == null or spec.initial_location.definition == null:
			continue
		var location_id := spec.initial_location.instance_id
		if not blocking_cells.has(location_id):
			blocking_cells[location_id] = {}
		if not actor_cells.has(location_id):
			actor_cells[location_id] = {}
		for local_footprint_cell in spec.get_initial_footprint_cells():
			var cell := spec.local_cell + local_footprint_cell
			if not spec.initial_location.definition.is_cell_in_grid(cell):
				push_error("Entity '%s' footprint Cell %s is outside its initial Location." % [spec.instance_id, cell])
				valid = false
				continue
			if spec.blocks_initial_movement():
				if blocking_cells[location_id].has(cell):
					push_error("Blocking Entities overlap at initial Cell %s in Location '%s'." % [cell, location_id])
					valid = false
				blocking_cells[location_id][cell] = spec.instance_id

	for spec in entity_specs:
		if not spec is NewGameActorSpec or spec.initial_location == null:
			continue
		var location_id := spec.initial_location.instance_id
		if not spec.initial_location.definition.is_cell_terrain_walkable(spec.local_cell):
			push_error("Actor '%s' starts on a non-walkable Cell %s." % [spec.instance_id, spec.local_cell])
			valid = false
		if blocking_cells.get(location_id, {}).has(spec.local_cell):
			push_error("Actor '%s' starts inside blocking Entity Cell %s." % [spec.instance_id, spec.local_cell])
			valid = false
		if actor_cells.get(location_id, {}).has(spec.local_cell):
			push_error("Actors overlap at initial Cell %s in Location '%s'." % [spec.local_cell, location_id])
			valid = false
		actor_cells[location_id][spec.local_cell] = spec.instance_id
	return valid
