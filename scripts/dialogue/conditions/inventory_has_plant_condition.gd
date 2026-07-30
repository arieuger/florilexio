class_name InventoryHasPlantCondition
extends ConversationCondition

@export var plant_id: StringName
@export_range(1, 999, 1) var amount := 1
@export var expected_has_item := true


func is_met(_context: ConversationContext) -> bool:
	if plant_id.is_empty() or amount <= 0:
		return false

	return (InventoryManager.has_item(plant_id, amount) == expected_has_item)


func get_debug_description() -> String:
	return "Inventory has plant '%s' x%d == %s" % [plant_id, amount, expected_has_item]