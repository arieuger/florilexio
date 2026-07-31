@tool
class_name NarrativeResourceFactory
extends RefCounted

static func normalize_id(raw_value: String) -> StringName:
	var normalized := raw_value.strip_edges().to_lower()

	normalized = normalized.replace(" ", "_")
	normalized = normalized.replace("-", "_")

	while normalized.contains("__"):
		normalized = normalized.replace("__", "_")

	return StringName(normalized.trim_prefix("_").trim_suffix("_"))


static func build_conversation_id(character: String, arc: String, purpose: String) -> StringName:
	var parts: PackedStringArray = []

	for value in [character, arc, purpose]:
		var normalized_part := normalize_id(value)

		if not normalized_part.is_empty():
			parts.append(str(normalized_part))

	return StringName("_".join(parts))


static func get_conversation_creation_errors(request: ConversationCreationRequest, index: NarrativeIndex) -> PackedStringArray:
	var errors := PackedStringArray()

	if request == null:
		errors.append("creation request is null")
		return errors

	var definition := ConversationDefinition.new()
	definition.conversation_id = request.conversation_id
	definition.dialogue_resource = request.dialogue_resource
	definition.start_title = request.start_title
	definition.initial_speaker_id = request.initial_speaker_id

	errors.append_array(definition.get_validation_errors())

	if index.has_conversation(request.conversation_id):
		errors.append("conversation_id '%s' already exists"% request.conversation_id)

	if request.target_profile == null:
		errors.append("target_profile is null")
	elif request.target_profile.resource_path.is_empty():
		errors.append("target_profile has not been saved")

	if request.save_path.is_empty():
		errors.append("save_path is empty")
	elif not request.save_path.begins_with("res://"):
		errors.append("save_path must be inside res://")
	elif request.save_path.get_extension().to_lower() != "tres":
		errors.append("save_path must use the .tres extension")
	elif ResourceLoader.exists(request.save_path):
		errors.append("a resource already exists at '%s'"% request.save_path)

	return errors


static func create_conversation(request: ConversationCreationRequest, index: NarrativeIndex) -> NarrativeCreationResult:
	var result := NarrativeCreationResult.new()
	var errors := get_conversation_creation_errors(request, index)

	if not errors.is_empty():
		result.error_message = "\n".join(errors)
		return result

	var definition := ConversationDefinition.new()
	definition.conversation_id = request.conversation_id
	definition.dialogue_resource = request.dialogue_resource
	definition.start_title = request.start_title
	definition.initial_speaker_id = request.initial_speaker_id

	var save_error := ResourceSaver.save(definition, request.save_path)

	if save_error != OK:
		result.error_message = "Could not save conversation definition at '%s': %s"% [request.save_path, error_string(save_error)]
		return result

	var entry := ConversationEntry.new()
	entry.conversation = definition
	entry.priority = request.priority
	entry.repeatable = request.repeatable
	entry.is_fallback = request.fallback

	request.target_profile.entries.append(entry)

	var profile_save_error := ResourceSaver.save(request.target_profile, request.target_profile.resource_path)

	if profile_save_error != OK:
		request.target_profile.entries.erase(entry)

		var absolute_path := ProjectSettings.globalize_path(request.save_path)
		DirAccess.remove_absolute(absolute_path)

		result.error_message = "Conversation definition was rolled back because profile '%s' could not be saved: %s"% [
			request.target_profile.resource_path,
			error_string(profile_save_error),
		]
		return result

	result.success = true
	result.resource_path = request.save_path
	result.conversation = definition
	result.entry = entry

	return result