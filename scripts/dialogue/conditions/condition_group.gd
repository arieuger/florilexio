@tool
class_name ConditionGroup
extends ConversationCondition

enum Mode {ALL, ANY}

@export var mode := Mode.ALL
@export var conditions: Array[ConversationCondition] = []


func is_met(context: ConversationContext) -> bool:
	if conditions.is_empty():
		return false

	match mode:
		Mode.ALL:
			for condition in conditions:
				if condition == null:
					return false
				if not condition.is_met(context):
					return false
			return true

		Mode.ANY:
			for condition in conditions:
				if condition != null and condition.is_met(context):
					return true
			return false

	return false


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if conditions.is_empty():
		errors.append("condition group is empty")
		return errors

	for index in range(conditions.size()):
		var condition := conditions[index]

		if condition == null:
			errors.append("condition %d is null" % index)
			continue

		for condition_error in condition.get_validation_errors():
			errors.append("condition %d: %s" % [index, condition_error])

	return errors


func get_debug_description() -> String:
	return "%s condition group was not met" % (Mode.keys()[mode])