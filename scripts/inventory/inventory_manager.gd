extends Node

signal inventory_changed
signal item_added(plant_id: StringName, amount: int, new_total: int)
signal item_removed(plant_id: StringName, amount: int, new_total: int)
signal bouquet_changed

var items: Dictionary = {}

func _ready():
	# Testing
	items = {
		&"fiuncho": 3,
		&"herba_luisa": 5,
		&"silveira": 2
	}

# TODO: Esto debería cargarse como recurso
var plant_definitions := {
	&"fiuncho": {
		"display_name": "Fiúncho",
		"description": "Unha das herbas tradicionais de San Xoán."
	},
	&"herba_luisa": {
		"display_name": "Herba luísa",
		"description": "Cheira a limón e úsase en infusións."
	},
	&"silveira": {
		"display_name": "Silveira",
		"description": "Unha planta brava que pode formar parte do ramo."
	}
}

var selected_bouquet: Array[StringName] = []


func add_item(plant_id: StringName, amount: int = 1) -> void:
	if amount <= 0:
		return

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
	selected_bouquet.clear()
	inventory_changed.emit()
	bouquet_changed.emit()


func get_display_name(plant_id: StringName) -> String:
	var definition: Dictionary = plant_definitions.get(plant_id, {})
	return definition.get("display_name", _format_plant_id(plant_id))


func get_description(plant_id: StringName) -> String:
	var definition: Dictionary = plant_definitions.get(plant_id, {})
	return definition.get("description", "")


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
