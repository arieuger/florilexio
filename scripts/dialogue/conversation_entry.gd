@tool
class_name ConversationEntry
extends Resource


@export var conversation: ConversationDefinition
@export var priority: int = 0
@export var repeatable := false
@export var is_fallback := false
@export var conditions: Array[ConversationCondition] = []

func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if conversation == null:
		errors.append("conversation is null")

	for index in range(conditions.size()):
		if conditions[index] == null:
			errors.append("condition at index %d is null" % index)
			continue

		for condition_error in conditions[index].get_validation_errors():
			errors.append(
				"condition at index %d: %s" % [index, condition_error]
			)

	return errors
