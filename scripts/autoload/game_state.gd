extends Node

signal consumed_time_added(total_consumed_time: int)
signal reached_night()
signal discarded_invasive_plants_changed(total_discarded_invasive_plants: int)

const START_HOUR := 10
const END_HOUR := 22
const BLOCK_MINUTES := 15
const TOTAL_BLOCKS := ((END_HOUR - START_HOUR) * 60) / BLOCK_MINUTES
const NIGHT_START_BLOCK := 41

var discovered_plants: Dictionary = {}
var collected_plants: Dictionary = {}

var old_woman_already_spoke: bool = false
var tutorial_already_launched: bool = false

var acknowledged_invasive_plants: bool = false
var acknowledged_on_danger_plants: bool = false
var acknowledged_poisonous_plants: bool = false # De momento nada
var acknowledged_mortal_plants: bool = false
var acknowledged_magic_plants: bool = false
var acknowledged_not_all_aromatics: bool = false

var discarded_invasive_plants_count: int = 0

var _consumed_time: int = 0 # Bloques de 15 minutos: en 12 horas, 48 bloques
var _pending_consumed_time: float = 0.0

# tóxicas, invasoras, p. de extición, máxicas (s. xoán, básicas e outras), outras

var consumed_time: int:
	get:
		return _consumed_time

func get_current_time_minutes() -> int:
	var clamped_blocks = clampi(_consumed_time, 0, TOTAL_BLOCKS)
	return (START_HOUR * 60) + (clamped_blocks * BLOCK_MINUTES)

func get_current_time_text() -> String:
	var current_minutes := get_current_time_minutes()
	var hour := int(current_minutes / 60)
	var minute := current_minutes % 60
	return "%02d:%02d" % [hour, minute]

func add_consumed_time(time: float) -> void:
	if time <= 0.0:
		return

	_pending_consumed_time += time
	var completed_blocks := floori(_pending_consumed_time)
	if completed_blocks <= 0:
		return

	var previous_consumed_time := _consumed_time
	_pending_consumed_time -= completed_blocks
	_consumed_time += completed_blocks

	consumed_time_added.emit(_consumed_time)
	print("Consumed time: " + str(_consumed_time) + " blocks")
	if previous_consumed_time < NIGHT_START_BLOCK and _consumed_time >= NIGHT_START_BLOCK:
		reached_night.emit()

func discover_plant(plant_id: String) -> void:
	# TODO: De momento non se usa. Para fase 2
	if not discovered_plants.has(plant_id):
		discovered_plants[plant_id] = true

func collect_plant(plant_collection_id: StringName) -> void:
	if plant_collection_id == &"":
		return

	collected_plants[plant_collection_id] = true


func add_discarded_invasive_plants(amount: int = 1) -> void:
	if amount <= 0:
		return

	discarded_invasive_plants_count += amount
	discarded_invasive_plants_changed.emit(discarded_invasive_plants_count)


func is_plant_collected(plant_collection_id: StringName) -> bool:
	return collected_plants.has(plant_collection_id)
