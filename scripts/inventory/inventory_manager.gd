extends Node

signal inventory_changed
signal item_added(item_id: StringName, amount: int, new_total: int)
signal item_removed(item_id: StringName, amount: int, new_total: int)
signal bouquet_changed

const INVASIVE_WARNING_TEXT := "[ ! ]"
const INVASIVE_WARNING_TOOLTIP := "Invasora!"
const MAGIC_WARNING_TEXT := "[ *_. ]"
const MAGIC_WARNING_TOOLTIP := "Máxica!"
const MORTAL_WARNING_TEXT := "[ R.I.P ]"
const MORTAL_WARNING_TOOLTIP := "Mortal!"

enum AdditionMode {ACQUIRE, RESTORE}

var items: Dictionary = {}

var selected_bouquet: Array[StringName] = []


func add_item(
	item_id: StringName,
	amount: int = 1,
	mode: AdditionMode = AdditionMode.ACQUIRE,
	collection_id: StringName = &"") -> void:
	if amount <= 0:
		return

	var item := ItemDatabase.get_item(item_id)
	if item == null:
		push_warning("InventoryManager: Unknown item_id '%s'." % item_id)
		return

	var new_total := get_amount(item_id) + amount
	items[item_id] = new_total
	item_added.emit(item_id, amount, new_total)
	inventory_changed.emit()

	if mode == AdditionMode.ACQUIRE:
		GameplayEvents.report_item_acquired(item_id, collection_id, amount)


func remove_item(item_id: StringName, amount: int = 1) -> bool:
	if amount <= 0 or not has_item(item_id, amount):
		return false

	var new_total := get_amount(item_id) - amount
	if new_total <= 0:
		items.erase(item_id)
	else:
		items[item_id] = new_total

	item_removed.emit(item_id, amount, new_total)
	inventory_changed.emit()
	return true


func discard_item(item_id: StringName, amount: int = 1) -> bool:
	if amount <= 0 or not can_discard_item(item_id, amount):
		return false

	var was_removed := remove_item(item_id, amount)
	var plant_data := ItemDatabase.get_plant(item_id)

	if was_removed and plant_data and plant_data.is_invasive:
		GameState.add_discarded_invasive_plants(amount)

	return was_removed


func get_amount(item_id: StringName) -> int:
	return int(items.get(item_id, 0))


func has_item(item_id: StringName, amount: int = 1) -> bool:
	if amount <= 0:
		return false

	return get_amount(item_id) >= amount


func get_items() -> Dictionary:
	return items.duplicate()


func clear() -> void:
	if items.is_empty() and selected_bouquet.is_empty():
		return

	items.clear()
	selected_bouquet.clear()
	inventory_changed.emit()
	bouquet_changed.emit()


## Development-only reset used by the in-game debug panel.
func debug_reset() -> void:
	if not OS.is_debug_build():
		return

	items.clear()
	selected_bouquet.clear()
	inventory_changed.emit()
	bouquet_changed.emit()


func get_display_name(item_id: StringName) -> String:
	var item_data := ItemDatabase.get_item(item_id)
	if not item_data:
		push_warning("InventoryManager: unknown item id '%s'." % item_id)
		return ""

	return tr(item_data.display_name)


func should_show_invasive_warning(plant_data: PlantData) -> bool:
	return plant_data != null and GameState.acknowledged_invasive_plants and plant_data.is_invasive


func should_show_magic_warning(plant_data: PlantData) -> bool:
	return plant_data != null and GameState.acknowledged_magic_plants and plant_data.is_magic


func should_show_mortal_warning(plant_data: PlantData) -> bool:
	return plant_data != null and GameState.acknowledged_mortal_plants and plant_data.is_mortal


func add_to_bouquet(plant_id: StringName) -> bool:
	if not can_add_to_bouquet(plant_id):
		return false

	selected_bouquet.append(plant_id)
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
	return selected_bouquet.duplicate()


func can_add_to_bouquet(plant_id: StringName) -> bool:
	if not ItemDatabase.get_plant(plant_id):
		return false

	var already_selected := _get_selected_bouquet_amount(plant_id)
	return get_amount(plant_id) > already_selected


func can_discard_item(item_id: StringName, amount: int = 1) -> bool:
	if amount <= 0:
		return false

	var available_amount := get_amount(item_id) - _get_selected_bouquet_amount(item_id)
	return available_amount >= amount


func is_good_bouquet_size() -> bool:
	return selected_bouquet.size() == 7 or selected_bouquet.size() == 9


func _get_selected_bouquet_amount(plant_id: StringName) -> int:
	return selected_bouquet.count(plant_id)
