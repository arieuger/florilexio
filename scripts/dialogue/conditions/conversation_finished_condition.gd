@tool
class_name ConversationFinishedCondition
extends ConversationCondition

@export var conversation_id: StringName
@export var expected_finished := true

func is_met(_context: ConversationContext) -> bool:
	if conversation_id.is_empty():
		return false

	return ConversationHistory.has_finished(conversation_id) == expected_finished

func get_debug_description() -> String:
	return "Conversation '%s' finished == %s"% [conversation_id, expected_finished]
