class_name ConversationResolver
extends RefCounted

static func resolve(profile: DialogueProfile, context: ConversationContext) -> ConversationDefinition:
	if profile == null:
		push_warning("ConversationResolver: dialogue profile is null")
		return null
	
	var regular_candidates: Array[ConversationEntry] = []
	var fallback_candidates: Array[ConversationEntry] = []

	for entry in profile.entries:
		var rejection_reason := _get_rejection_reason(entry, context)

		if not rejection_reason.is_empty():
			continue

		if entry.is_fallback:
			fallback_candidates.append(entry)
		else:
			regular_candidates.append(entry)

	var candidates := regular_candidates
	if candidates.is_empty():
		candidates = fallback_candidates

	if candidates.is_empty():
		return null

	return _select_highest_priority(profile, candidates).conversation


static func _get_rejection_reason(entry: ConversationEntry, context: ConversationContext) -> String:
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