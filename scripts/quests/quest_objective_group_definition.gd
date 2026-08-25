@tool
class_name QuestObjectiveGroupDefinition
extends Resource

enum CompletionMode { ALL, ANY }

@export_multiline var description: String
@export var objective_ids: Array[StringName] = []
@export var completion_mode: CompletionMode = CompletionMode.ALL
@export var show_in_notebook := true

func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if show_in_notebook and description.strip_edges().is_empty():
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
