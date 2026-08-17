@tool
class_name QuestDefinition
extends Resource

enum QuestType { MAIN, SIDE }

@export var quest_id: StringName
@export var objectives: Array[QuestObjectiveDefinition] = []
@export var objective_groups: Array[QuestObjectiveGroupDefinition] = []
@export var quest_type: QuestType = QuestType.MAIN
@export var show_in_notebook := true
@export_multiline var description: String

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

	var grouped_objective_ids := {}

	for group_index in range(objective_groups.size()):
		var objective_group := objective_groups[group_index]

		if objective_group == null:
			errors.append("objective group at index %d is null" % group_index)
			continue

		for group_error in objective_group.get_validation_errors():
			errors.append(
				"objective group %d: %s" % [group_index, group_error]
			)

		for objective_id in objective_group.objective_ids:
			if objective_id.is_empty():
				continue

			if not known_objective_ids.has(objective_id):
				errors.append(
					"objective group %d references unknown objective_id '%s'"
					% [group_index, objective_id]
				)
				continue

			if grouped_objective_ids.has(objective_id):
				errors.append(
					"objective_id '%s' belongs to multiple objective groups"
					% objective_id
				)
			else:
				grouped_objective_ids[objective_id] = true

	return errors