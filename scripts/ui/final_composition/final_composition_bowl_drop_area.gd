extends Control

signal plant_dropped(plant_id: StringName)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return _is_valid_drag_data(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _is_valid_drag_data(data):
		return

	plant_dropped.emit(data.get("plant_id", &""))


func _is_valid_drag_data(data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	if data.get("type", "") != FinalCompositionItemRow.DRAG_DATA_TYPE:
		return false

	var plant_id: StringName = data.get("plant_id", &"")
	return InventoryManager.can_add_to_bouquet(plant_id)
