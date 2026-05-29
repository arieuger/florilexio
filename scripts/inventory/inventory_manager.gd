extends Node

signal inventory_changed
signal item_added(plant_id: StringName, amount: int, new_total: int)
signal item_removed(plant_id: StringName, amount: int, new_total: int)
signal bouquet_changed

const MARK_IS_INVASIVE := &"is_invasive"
const MARK_IS_MAGIC := &"is_magic"
const PLANT_MARKS := [MARK_IS_INVASIVE, MARK_IS_MAGIC]
const BOUQUET_PLANT_ID_KEY := &"plant_id"
const BOUQUET_MARKS_KEY := &"marks"
const INVASIVE_WARNING_TEXT := "[ ! ]"
const INVASIVE_WARNING_TOOLTIP := "Invasora!"
const MAGIC_WARNING_TEXT := "[ *_. ]"
const MAGIC_WARNING_TOOLTIP := "Máxica!"

var items: Dictionary = {}
var plant_display_names: Dictionary = {}
var plant_marks: Dictionary = {}

func _ready():
	# Testing
	# items = {
	# 	&"fiuncho": 3,
	# 	&"herba_luisa": 5,
	# 	&"silveira": 2,
	# 	&"dsd": 1,
	# 	&"sdf": 1,
	# 	&"gfd": 1,
	# 	&"bvc": 1,
	# 	&"bewd": 1,
	# 	&"werg": 1,
	# 	&"sfgd": 1,
	# 	&"sfgs": 1,
	# 	&"sffsfg": 1,
	# 	&"sdfgs": 1,
	# 	&"sdfsd": 1,
	# 	&"rrrr": 1,
	# 	&"gggg": 1,
	# 	&"hhhh": 1,
	# 	&"dfeer": 1,
	# }
	pass

var selected_bouquet: Array[Dictionary] = []


func add_item(plant_id: StringName, amount: int = 1, display_name: String = "", marks: Dictionary = {}) -> void:
	if amount <= 0:
		return

	if not display_name.is_empty():
		plant_display_names[plant_id] = display_name
	if marks.is_empty() and plant_marks.has(plant_id):
		plant_marks[plant_id] = get_plant_marks(plant_id)
	else:
		plant_marks[plant_id] = _normalize_plant_marks(marks)

	var new_total := get_amount(plant_id) + amount
	items[plant_id] = new_total
	item_added.emit(plant_id, amount, new_total)
	inventory_changed.emit()


func remove_item(plant_id: StringName, amount: int = 1) -> bool:
	if amount <= 0 or not has_item(plant_id, amount):
		return false

	var new_total := get_amount(plant_id) - amount
	if new_total <= 0:
		items.erase(plant_id)
	else:
		items[plant_id] = new_total

	item_removed.emit(plant_id, amount, new_total)
	inventory_changed.emit()
	return true


func discard_item(plant_id: StringName, amount: int = 1) -> bool:
	if amount <= 0 or not can_discard_item(plant_id, amount):
		return false

	var was_removed := remove_item(plant_id, amount)
	if was_removed and has_plant_mark(plant_id, MARK_IS_INVASIVE):
		GameState.add_discarded_invasive_plants(amount)

	return was_removed


func get_amount(plant_id: StringName) -> int:
	return int(items.get(plant_id, 0))


func has_item(plant_id: StringName, amount: int = 1) -> bool:
	if amount <= 0:
		return false

	return get_amount(plant_id) >= amount


func get_items() -> Dictionary:
	return items.duplicate()


func clear() -> void:
	if items.is_empty() and selected_bouquet.is_empty():
		return

	items.clear()
	plant_display_names.clear()
	plant_marks.clear()
	selected_bouquet.clear()
	inventory_changed.emit()
	bouquet_changed.emit()


func get_display_name(plant_id: StringName) -> String:
	if plant_display_names.has(plant_id):
		return tr(plant_display_names[plant_id])

	return tr(_format_plant_id(plant_id))


func get_description(plant_id: StringName) -> String:
	return ""


func get_plant_marks(plant_id: StringName) -> Dictionary:
	return _normalize_plant_marks(plant_marks.get(plant_id, {}))


func has_plant_mark(plant_id: StringName, mark: StringName) -> bool:
	return bool(get_plant_marks(plant_id).get(mark, false))


func should_show_invasive_warning(marks: Dictionary) -> bool:
	return GameState.acknowledged_invasive_plants and bool(marks.get(MARK_IS_INVASIVE, false))


func should_show_magic_warning(marks: Dictionary) -> bool:
	return GameState.acknowledged_magic_plants and bool(marks.get(MARK_IS_MAGIC, false))


func build_plant_marks(source: Object) -> Dictionary:
	var marks := {}
	for mark in PLANT_MARKS:
		marks[mark] = bool(source.get(mark))

	return marks


func add_to_bouquet(plant_id: StringName) -> bool:
	if not can_add_to_bouquet(plant_id):
		return false

	selected_bouquet.append(_make_bouquet_entry(plant_id))
	bouquet_changed.emit()
	SoundManager.play_simple_sound("Bouquet/Update")
	return true


func remove_from_bouquet(index: int) -> void:
	if index < 0 or index >= selected_bouquet.size():
		return

	selected_bouquet.remove_at(index)
	bouquet_changed.emit()
	SoundManager.play_simple_sound("Bouquet/Update")


func clear_bouquet() -> void:
	if selected_bouquet.is_empty():
		return

	selected_bouquet.clear()
	bouquet_changed.emit()


func get_bouquet_count() -> int:
	return selected_bouquet.size()


func get_bouquet_items() -> Array[StringName]:
	var bouquet_items: Array[StringName] = []
	for entry in selected_bouquet:
		bouquet_items.append(_get_bouquet_entry_plant_id(entry))

	return bouquet_items


func get_bouquet_entries() -> Array[Dictionary]:
	return selected_bouquet.duplicate(true)


func get_bouquet_item_marks(index: int) -> Dictionary:
	if index < 0 or index >= selected_bouquet.size():
		return _normalize_plant_marks({})

	return _normalize_plant_marks(selected_bouquet[index].get(BOUQUET_MARKS_KEY, {}))


func can_add_to_bouquet(plant_id: StringName) -> bool:
	var already_selected := _get_selected_bouquet_amount(plant_id)
	return get_amount(plant_id) > already_selected


func can_discard_item(plant_id: StringName, amount: int = 1) -> bool:
	if amount <= 0:
		return false

	var available_amount := get_amount(plant_id) - _get_selected_bouquet_amount(plant_id)
	return available_amount >= amount


func is_good_bouquet_size() -> bool:
	return selected_bouquet.size() == 7 or selected_bouquet.size() == 9


func _get_selected_bouquet_amount(plant_id: StringName) -> int:
	var selected_count := 0
	for entry in selected_bouquet:
		if _get_bouquet_entry_plant_id(entry) == plant_id:
			selected_count += 1

	return selected_count


func _make_bouquet_entry(plant_id: StringName) -> Dictionary:
	var entry := {}
	entry[BOUQUET_PLANT_ID_KEY] = plant_id
	entry[BOUQUET_MARKS_KEY] = get_plant_marks(plant_id)
	return entry


func _get_bouquet_entry_plant_id(entry: Dictionary) -> StringName:
	return StringName(entry.get(BOUQUET_PLANT_ID_KEY, &""))


func _normalize_plant_marks(raw_marks: Dictionary) -> Dictionary:
	var normalized_marks := {}
	for mark in PLANT_MARKS:
		normalized_marks[mark] = bool(raw_marks.get(mark, false))

	return normalized_marks


func _format_plant_id(plant_id: StringName) -> String:
	return String(plant_id).replace("_", " ").capitalize()
