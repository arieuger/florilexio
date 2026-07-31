@tool
class_name DialogueProfile
extends Resource

@export var profile_id: StringName
@export var entries: Array[ConversationEntry] = []

func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if profile_id.is_empty():
		errors.append("profile_id is empty")

	if entries.is_empty():
		errors.append("profile has no entries")

	var known_conversation_ids := {}

	for index in range(entries.size()):
		var entry := entries[index]

		if entry == null:
			errors.append("entry at index %d is null" % index)
			continue

		for entry_error in entry.get_validation_errors():
			errors.append("entry %d: %s" % [index, entry_error])

		if entry.conversation == null:
			continue

		var conversation_id := (entry.conversation.conversation_id)

		if conversation_id.is_empty():
			continue

		if known_conversation_ids.has(conversation_id):
			errors.append("duplicated conversation_id '%s' in profile"% conversation_id)
		else:
			known_conversation_ids[conversation_id] = true

	return errors