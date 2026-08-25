@tool
class_name ConversationEntry
extends Resource


@export var conversation: ConversationDefinition
@export var priority: int = 0
@export var repeatable := false
@export var is_fallback := false
@export var condition_group: ConditionGroup

func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if conversation == null:
		errors.append("conversation is null")

	if condition_group != null:
		for condition_error in condition_group.get_validation_errors():
			errors.append("condition_group: %s" % condition_error)

	return errors
