class_name WorldTimeRuntime
extends Node

signal time_changed(previous_total_minutes: int, current_total_minutes: int)
signal minute_changed(previous_total_minutes: int, current_total_minutes: int, minutes_crossed: int)
signal hour_changed(previous_hour_index: int, current_hour_index: int, hours_crossed: int)
signal day_changed(previous_day_index: int, current_day_index: int, days_crossed: int)

const REAL_SECONDS_PER_GAME_MINUTE := 1.0

var _state: WorldTimeState
var _real_seconds_accumulator := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

	var world_state := get_node_or_null("/root/WorldState") as WorldStateRuntime
	if world_state == null:
		push_error("WorldState Autoload is required before WorldTime.")
		set_process(false)
		return

	_state = world_state.get_world_time_state()
	if _state == null:
		var initial_state := WorldTimeState.new(WorldCalendar.INITIAL_TOTAL_MINUTES)
		if world_state.register_world_time_state(initial_state):
			_state = initial_state

	if _state == null:
		push_error("WorldTime could not bind the authoritative WorldTimeState.")
		set_process(false)


func _process(delta: float) -> void:
	if _state == null:
		return

	_real_seconds_accumulator += delta
	var elapsed_game_minutes := floori(_real_seconds_accumulator / REAL_SECONDS_PER_GAME_MINUTE)
	if elapsed_game_minutes <= 0:
		return

	_real_seconds_accumulator -= elapsed_game_minutes * REAL_SECONDS_PER_GAME_MINUTE
	advance_minutes(elapsed_game_minutes)


func advance_minutes(minutes: int) -> bool:
	if _state == null:
		push_error("Cannot advance world time without WorldTimeState.")
		return false
	if minutes < 0:
		push_error("World time cannot move backwards by %d minutes." % minutes)
		return false
	if minutes == 0:
		return true

	var previous_total_minutes := _state.total_minutes
	var current_total_minutes := previous_total_minutes + minutes
	_state.total_minutes = current_total_minutes
	_emit_time_crossings(previous_total_minutes, current_total_minutes)
	return true


func advance_to(year: int, month: int, day: int, hour: int, minute: int) -> bool:
	var target_total_minutes := WorldCalendar.to_total_minutes(year, month, day, hour, minute)
	if target_total_minutes < 0:
		push_error(
			"Invalid Hearthvale date/time: year %d, month %d, day %d, %02d:%02d."
			% [year, month, day, hour, minute]
		)
		return false
	return advance_to_total_minutes(target_total_minutes)


func advance_to_total_minutes(target_total_minutes: int) -> bool:
	if _state == null:
		push_error("Cannot advance world time without WorldTimeState.")
		return false
	if target_total_minutes < _state.total_minutes:
		push_error(
			"World time cannot move backwards from %d to %d total minutes."
			% [_state.total_minutes, target_total_minutes]
		)
		return false
	return advance_minutes(target_total_minutes - _state.total_minutes)


func advance_to_next_day_at(hour: int, minute: int) -> bool:
	if _state == null:
		push_error("Cannot advance world time without WorldTimeState.")
		return false
	if hour < 0 or hour >= WorldCalendar.HOURS_PER_DAY:
		push_error("Next-day target hour must be between 0 and 23.")
		return false
	if minute < 0 or minute >= WorldCalendar.MINUTES_PER_HOUR:
		push_error("Next-day target minute must be between 0 and 59.")
		return false

	var next_day_index := WorldCalendar.get_day_index(_state.total_minutes) + 1
	var target_total_minutes := (
		next_day_index * WorldCalendar.MINUTES_PER_DAY
		+ hour * WorldCalendar.MINUTES_PER_HOUR
		+ minute
	)
	return advance_to_total_minutes(target_total_minutes)


func get_total_minutes() -> int:
	return _state.total_minutes if _state != null else 0


func get_year() -> int:
	return WorldCalendar.get_year(get_total_minutes())


func get_month() -> int:
	return WorldCalendar.get_month(get_total_minutes())


func get_day() -> int:
	return WorldCalendar.get_day(get_total_minutes())


func get_hour() -> int:
	return WorldCalendar.get_hour(get_total_minutes())


func get_minute() -> int:
	return WorldCalendar.get_minute(get_total_minutes())


func get_weekday() -> WorldCalendar.Weekday:
	return WorldCalendar.get_weekday(get_total_minutes())


func get_weekday_name() -> String:
	return WorldCalendar.get_weekday_name(get_total_minutes())


func get_season() -> WorldCalendar.Season:
	return WorldCalendar.get_season(get_total_minutes())


func get_season_name() -> String:
	return WorldCalendar.get_season_name(get_total_minutes())


func _emit_time_crossings(previous_total_minutes: int, current_total_minutes: int) -> void:
	var minutes_crossed := current_total_minutes - previous_total_minutes
	minute_changed.emit(previous_total_minutes, current_total_minutes, minutes_crossed)

	var previous_hour_index := previous_total_minutes / WorldCalendar.MINUTES_PER_HOUR
	var current_hour_index := current_total_minutes / WorldCalendar.MINUTES_PER_HOUR
	if current_hour_index > previous_hour_index:
		hour_changed.emit(
			previous_hour_index,
			current_hour_index,
			current_hour_index - previous_hour_index
		)

	var previous_day_index := WorldCalendar.get_day_index(previous_total_minutes)
	var current_day_index := WorldCalendar.get_day_index(current_total_minutes)
	if current_day_index > previous_day_index:
		day_changed.emit(
			previous_day_index,
			current_day_index,
			current_day_index - previous_day_index
		)

	time_changed.emit(previous_total_minutes, current_total_minutes)
