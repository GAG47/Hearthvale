class_name WorldCalendar
extends RefCounted

enum Weekday {
	MONDAY,
	TUESDAY,
	WEDNESDAY,
	THURSDAY,
	FRIDAY,
	SATURDAY,
	SUNDAY,
}

enum Season {
	SPRING,
	SUMMER,
	AUTUMN,
	WINTER,
}

const MONTHS_PER_YEAR := 12
const DAYS_PER_MONTH := 30
const DAYS_PER_WEEK := 7
const HOURS_PER_DAY := 24
const MINUTES_PER_HOUR := 60
const MONTHS_PER_SEASON := 3

const MINUTES_PER_DAY := HOURS_PER_DAY * MINUTES_PER_HOUR
const DAYS_PER_YEAR := MONTHS_PER_YEAR * DAYS_PER_MONTH
const MINUTES_PER_YEAR := DAYS_PER_YEAR * MINUTES_PER_DAY

const INITIAL_YEAR := 1
const INITIAL_MONTH := 1
const INITIAL_DAY := 1
const INITIAL_HOUR := 8
const INITIAL_MINUTE := 0
const INITIAL_TOTAL_MINUTES := (
	(INITIAL_YEAR - 1) * MINUTES_PER_YEAR
	+ (INITIAL_MONTH - 1) * DAYS_PER_MONTH * MINUTES_PER_DAY
	+ (INITIAL_DAY - 1) * MINUTES_PER_DAY
	+ INITIAL_HOUR * MINUTES_PER_HOUR
	+ INITIAL_MINUTE
)

const WEEKDAY_NAMES := [
	"Monday",
	"Tuesday",
	"Wednesday",
	"Thursday",
	"Friday",
	"Saturday",
	"Sunday",
]

const SEASON_NAMES := [
	"Spring",
	"Summer",
	"Autumn",
	"Winter",
]


static func is_valid_date_time(year: int, month: int, day: int, hour: int, minute: int) -> bool:
	return (
		year >= 1
		and month >= 1
		and month <= MONTHS_PER_YEAR
		and day >= 1
		and day <= DAYS_PER_MONTH
		and hour >= 0
		and hour < HOURS_PER_DAY
		and minute >= 0
		and minute < MINUTES_PER_HOUR
	)


static func to_total_minutes(year: int, month: int, day: int, hour: int, minute: int) -> int:
	if not is_valid_date_time(year, month, day, hour, minute):
		return -1

	var completed_years := year - 1
	var completed_months := month - 1
	var completed_days := day - 1
	return (
		completed_years * MINUTES_PER_YEAR
		+ completed_months * DAYS_PER_MONTH * MINUTES_PER_DAY
		+ completed_days * MINUTES_PER_DAY
		+ hour * MINUTES_PER_HOUR
		+ minute
	)


static func get_year(total_minutes: int) -> int:
	return total_minutes / MINUTES_PER_YEAR + 1


static func get_month(total_minutes: int) -> int:
	var day_of_year := get_day_index(total_minutes) % DAYS_PER_YEAR
	return day_of_year / DAYS_PER_MONTH + 1


static func get_day(total_minutes: int) -> int:
	var day_of_year := get_day_index(total_minutes) % DAYS_PER_YEAR
	return day_of_year % DAYS_PER_MONTH + 1


static func get_hour(total_minutes: int) -> int:
	return total_minutes / MINUTES_PER_HOUR % HOURS_PER_DAY


static func get_minute(total_minutes: int) -> int:
	return total_minutes % MINUTES_PER_HOUR


static func get_day_index(total_minutes: int) -> int:
	return total_minutes / MINUTES_PER_DAY


static func get_weekday(total_minutes: int) -> Weekday:
	return get_day_index(total_minutes) % DAYS_PER_WEEK as Weekday


static func get_weekday_name(total_minutes: int) -> String:
	return WEEKDAY_NAMES[get_weekday(total_minutes)]


static func get_season(total_minutes: int) -> Season:
	return (get_month(total_minutes) - 1) / MONTHS_PER_SEASON as Season


static func get_season_name(total_minutes: int) -> String:
	return SEASON_NAMES[get_season(total_minutes)]
