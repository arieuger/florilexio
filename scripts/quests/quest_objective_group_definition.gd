@tool
class_name QuestObjectiveGroupDefinition
extends Resource

@export_multiline var description: String
@export var objective_ids: Array[StringName] = []

func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if description.strip_edges().is_empty():
		errors.append("description is empty")

	if objective_ids.is_empty():
		errors.append("objective_ids is empty")

	var known_objective_ids := {}

	for objective_id in objective_ids:
		if objective_id.is_empty():
			errors.append("objective_id is empty")
			continue

		if known_objective_ids.has(objective_id):
			errors.append("duplicated objective_id '%s'" % objective_id)
		else:
			known_objective_ids[objective_id] = true

	return errors