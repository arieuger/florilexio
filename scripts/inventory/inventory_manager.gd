extends Node

signal inventory_changed
signal item_added(plant_id: StringName, amount: int, new_total: int)
signal item_removed(plant_id: StringName, amount: int, new_total: int)
signal bouquet_changed

var items: Dictionary = {}
var plant_display_names: Dictionary = {}

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

var selected_bouquet: Array[StringName] = []


func add_item(plant_id: StringName, amount: int = 1, display_name: String = "") -> void:
	if amount <= 0:
		return

	if not display_name.is_empty():
		plant_display_names[plant_id] = display_name

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
	selected_bouquet.clear()
	inventory_changed.emit()
	bouquet_changed.emit()


func get_display_name(plant_id: StringName) -> String:
	if plant_display_names.has(plant_id):
		return plant_display_names[plant_id]

	return _format_plant_id(plant_id)


func get_description(plant_id: StringName) -> String:
	return ""


func add_to_bouquet(plant_id: StringName) -> bool:
	if not can_add_to_bouquet(plant_id):
		return false

	selected_bouquet.append(plant_id)
	bouquet_changed.emit()
	return true


func remove_from_bouquet(index: int) -> void:
	if index < 0 or index >= selected_bouquet.size():
		return

	selected_bouquet.remove_at(index)
	bouquet_changed.emit()


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
	var already_selected := _get_selected_bouquet_amount(plant_id)
	return get_amount(plant_id) > already_selected


func is_good_bouquet_size() -> bool:
	return selected_bouquet.size() == 7 or selected_bouquet.size() == 9


func _get_selected_bouquet_amount(plant_id: StringName) -> int:
	var selected_count := 0
	for selected_plant_id in selected_bouquet:
		if selected_plant_id == plant_id:
			selected_count += 1

	return selected_count


func _format_plant_id(plant_id: StringName) -> String:
	return String(plant_id).replace("_", " ").capitalize()
