@tool
class_name ConversationDefinition
extends Resource

@export var conversation_id: StringName
@export var dialogue_resource: DialogueResource
@export var start_title = "start"
@export var initial_speaker_id: StringName

## Time blocks charged once when this conversation finishes normally. Zero is free.
@export_range(0.0, 48.0, 0.1, "or_greater") var time_cost_blocks: float = 0.0


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if not is_finite(time_cost_blocks) or time_cost_blocks < 0.0:
		errors.append("time_cost_blocks must be finite and non-negative")

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
