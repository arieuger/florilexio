@tool
class_name InventoryHasCondition
extends ConversationCondition

@export var target_type: QuestObjectiveDefinition.TargetType = (
	QuestObjectiveDefinition.TargetType.ITEM_ID
)
@export var target_id: StringName
@export_range(1, 999, 1) var amount := 1
@export var expected_has := true


func is_met(_context: ConversationContext) -> bool:
	if target_id.is_empty() or amount <= 0:
		return false

	if target_type not in [
		QuestObjectiveDefinition.TargetType.ITEM_ID,
		QuestObjectiveDefinition.TargetType.PLANT_SPECIES,
	]:
		return false

	return InventoryManager.has_item(target_id, amount) == expected_has


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if target_type not in [
		QuestObjectiveDefinition.TargetType.ITEM_ID,
		QuestObjectiveDefinition.TargetType.PLANT_SPECIES,
	]:
		errors.append("target_type must be ITEM_ID or PLANT_SPECIES")

	if target_id.is_empty():
		errors.append("target_id is empty")

	if amount <= 0:
		errors.append("amount must be at least 1")

	return errors


func get_debug_description() -> String:
	return "Inventory has %s '%s' x%d == %s" % [
		QuestObjectiveDefinition.TargetType.keys()[target_type],
		target_id,
		amount,
		expected_has,
	]
