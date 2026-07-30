class_name ConversationResolver
extends RefCounted

static func resolve(profile: DialogueProfile, context: ConversationContext) -> ConversationDefinition:
	if profile == null:
		push_warning("ConversationResolver: dialogue profile is null")
		return null
	
	var regular_candidates: Array[ConversationEntry] = []
	var fallback_candidates: Array[ConversationEntry] = []
	var rejection_messages: Array[String] = []

	for index in range(profile.entries.size()):
		var entry := profile.entries[index]
		var rejection_reason := _get_rejection_reason(entry, context)

		if not rejection_reason.is_empty():
			rejection_messages.append("entry %d (%s): %s"% [index, _get_entry_label(entry), rejection_reason])
			continue

		if entry.is_fallback:
			fallback_candidates.append(entry)
		else:
			regular_candidates.append(entry)

	var candidates := regular_candidates
	if candidates.is_empty():
		candidates = fallback_candidates

	if candidates.is_empty():
		var details := "profile has no entries"

		if not rejection_messages.is_empty():
			details = "\n- " + "\n- ".join(rejection_messages)

		push_warning("ConversationResolver: profile '%s' has no eligible conversation. %s"% [profile.profile_id, details])
		return null

	return _select_highest_priority(profile, candidates).conversation


static func resolve_by_id(profile: DialogueProfile, conversation_id: StringName, 
	context: ConversationContext, require_available := true
) -> ConversationDefinition:
	if profile == null:
		push_warning("ConversationResolver: dialogue profile is null.")
		return null

	if conversation_id.is_empty():
		push_warning("ConversationResolver: conversation_id is empty.")
		return null

	var matches: Array[ConversationEntry] = []

	for entry in profile.entries:
		if entry == null or entry.conversation == null:
			continue

		if entry.conversation.conversation_id == conversation_id:
			matches.append(entry)

	if matches.is_empty():
		push_warning("ConversationResolver: profile '%s' has no conversation '%s'."% [profile.profile_id, conversation_id])
		return null

	if matches.size() > 1:
		push_warning("ConversationResolver: profile '%s' contains conversation '%s' more than once. "
			+ "The first entry will be used."% [profile.profile_id, conversation_id]
		)

	var selected := matches[0]
	var rejection_reason := (
		_get_rejection_reason(selected, context)
		if require_available
		else _get_configuration_error(selected)
	)

	if not rejection_reason.is_empty():
		push_warning("ConversationResolver: conversation '%s' cannot be resolved: %s."% [conversation_id, rejection_reason])
		return null

	return selected.conversation


static func _get_rejection_reason(entry: ConversationEntry, context: ConversationContext) -> String:
	var configuration_error := _get_configuration_error(entry)
	if not configuration_error.is_empty():
		return configuration_error

	var conversation := entry.conversation

	if not entry.repeatable and ConversationHistory.has_finished(conversation.conversation_id):
		return "non-repeatable conversation already finished"

	for condition in entry.conditions:
		if condition == null:
			return "condition is null"

		if not condition.is_met(context):
			return condition.get_debug_description()

	return ""


static func _select_highest_priority(profile: DialogueProfile, candidates: Array[ConversationEntry]) -> ConversationEntry:
	var selected := candidates[0]

	for index in range(1, candidates.size()):
		var candidate := candidates[index]

		if candidate.priority > selected.priority:
			selected = candidate
		elif candidate.priority == selected.priority:
			push_warning("ConversationResolver: profile '%s' has equally eligible conversations '%s' and '%s' with priority %d. "
				+ "The first entry will be used."
				% [
					profile.profile_id,
					selected.conversation.conversation_id,
					candidate.conversation.conversation_id,
					selected.priority,
				]
			)

	return selected

static func _get_configuration_error(entry: ConversationEntry) -> String:
	if entry == null:
		return "entry is null"

	if entry.conversation == null:
		return "conversation is null"

	var conversation := entry.conversation

	if conversation.conversation_id.is_empty():
		return "conversation_id is empty"

	if conversation.dialogue_resource == null:
		return "dialogue_resource is null"

	if conversation.start_title.is_empty():
		return "start_title is empty"

	return ""


static func _get_entry_label(entry: ConversationEntry) -> String:
	if entry == null:
		return "<null entry>"

	if entry.conversation == null:
		return "<null conversation>"

	if entry.conversation.conversation_id.is_empty():
		return "<empty conversation_id>"

	return str(entry.conversation.conversation_id)