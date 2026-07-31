@tool
class_name QuestDefinition
extends Resource

@export var quest_id: StringName
@export var objectives: Array[QuestObjectiveDefinition] = []

func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if quest_id.is_empty():
		errors.append("quest_id is empty")

	if objectives.is_empty():
		errors.append("quest has no objectives")

	var known_objective_ids := {}

	for index in range(objectives.size()):
		var objective := objectives[index]

		if objective == null:
			errors.append("objective at index %d is null" % index)
			continue

		if not objective.objective_id.is_empty():
			if known_objective_ids.has(objective.objective_id):
				errors.append("duplicated objective_id '%s'"% objective.objective_id)
			else:
				known_objective_ids[objective.objective_id] = true

		for objective_error in objective.get_validation_errors():
			errors.append("objective %d ('%s'): %s"% [index, objective.objective_id, objective_error])

	return errors