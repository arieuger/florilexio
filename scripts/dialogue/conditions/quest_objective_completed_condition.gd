class_name QuestObjectiveCompletedCondition
extends ConversationCondition

@export var quest_id: StringName
@export var objective_id: StringName
@export var expected_completed := true


func is_met(_context: ConversationContext) -> bool:
	if quest_id.is_empty() or objective_id.is_empty():
		return false

	return (
		QuestManager.is_objective_completed(quest_id, objective_id) == expected_completed
	)


func get_debug_description() -> String:
	return "Quest '%s' objective '%s' completed == %s" % [quest_id, objective_id, expected_completed]