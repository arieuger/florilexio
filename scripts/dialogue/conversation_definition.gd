@tool
class_name ConversationDefinition
extends Resource

@export var conversation_id: StringName
@export var dialogue_resource: DialogueResource
@export var start_title = "start"
@export var initial_speaker_id: StringName

func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if conversation_id.is_empty():
		errors.append("conversation_id is empty")

	if dialogue_resource == null:
		errors.append("dialogue_resource is null")

	if start_title.is_empty():
		errors.append("start_title is empty")
	elif dialogue_resource != null and not dialogue_resource.get_titles().has(start_title):
		errors.append("start_title '%s' does not exist in dialogue_resource"% start_title)

	if initial_speaker_id.is_empty():
		errors.append("initial_speaker_id is empty")

	return errors