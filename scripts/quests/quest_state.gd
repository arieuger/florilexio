class_name QuestState
extends RefCounted

enum Status {
	INACTIVE,
	ACTIVE,
	COMPLETED,
	FAILED,
}

var quest_id: StringName
var status: Status = Status.INACTIVE
var objective_progress: Dictionary[StringName, int] = {}


static func create(definition: QuestDefinition) -> QuestState:
	var state := QuestState.new()

	if definition == null:
		return state

	state.quest_id = definition.quest_id

	for objective in definition.objectives:
		if objective == null or objective.objective_id.is_empty():
			continue

		if not state.objective_progress.has(objective.objective_id):
			state.objective_progress[objective.objective_id] = 0

	return state


func get_current_amount(objective_id: StringName) -> int:
	return objective_progress.get(objective_id, 0)