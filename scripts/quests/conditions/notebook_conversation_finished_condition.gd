@tool
class_name NotebookConversationFinishedCondition
extends NotebookRevealCondition

@export var conversation_id: StringName

func is_met(_quest_id: StringName) -> bool:
	if conversation_id.is_empty():
		return false

	return ConversationHistory.has_finished(conversation_id)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if conversation_id.is_empty():
		errors.append("conversation_id is empty")

	return errors