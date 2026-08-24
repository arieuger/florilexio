@tool
class_name InventoryHasItemCondition
extends ConversationCondition

@export var item_id: StringName
@export_range(1, 999, 1) var amount := 1
@export var expected_has_item := true


func is_met(_context: ConversationContext) -> bool:
	if item_id.is_empty() or amount <= 0:
		return false

	return InventoryManager.has_item(item_id, amount) == expected_has_item


func get_debug_description() -> String:
	return "Inventory has item '%s' x%d == %s" % [item_id, amount, expected_has_item]
