@tool
class_name NarrativeDocumentationGenerator
extends RefCounted

const OUTPUT_DIRECTORY := "res://docs/Documentacion"


func generate(index: NarrativeIndex, issues: Array[NarrativeValidationIssue]) -> NarrativeDocumentationResult:
	var result := NarrativeDocumentationResult.new()
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	if directory_error != OK:
		result.error_message = "Could not create documentation directory: %s" % error_string(directory_error)
		return result

	var prefix := _get_date_prefix()
	var documents := {
		"%s-conversations.md" % prefix: _build_conversations(index),
		"%s-quests.md" % prefix: _build_quests(index),
		"%s-narrative-validation.md" % prefix: _build_validation(index, issues),
	}
	var filenames: Array[String] = []
	for filename in documents:
		filenames.append(filename)
	filenames.sort()

	for filename in filenames:
		var path := OUTPUT_DIRECTORY.path_join(filename)
		var write_error := _write_document(path, documents[filename])
		if write_error != OK:
			result.error_message = "Could not write '%s': %s" % [path, error_string(write_error)]
			return result
		result.generated_paths.append(path)

	result.success = true
	return result


func _build_conversations(index: NarrativeIndex) -> String:
	var lines := PackedStringArray([
		"# Conversations", "", "> Generated file. Do not edit manually.", "",
		"| Conversation ID | Profile | Dialogue | Start title | Speaker | Priority | Repeatable | Fallback |",
		"|---|---|---|---|---|---:|---|---|",
	])
	var records := index.conversations.duplicate()
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["id"]) < str(b["id"]))

	for record in records:
		var conversation := record["resource"] as ConversationDefinition
		var references := _get_profile_references(index, conversation)
		if references.is_empty():
			lines.append(_conversation_row(conversation, "—", 0, false, false))
		else:
			for reference in references:
				lines.append(_conversation_row(conversation, str(reference["profile_id"]), int(reference["priority"]), bool(reference["repeatable"]), bool(reference["fallback"])))

	lines.append("")
	return "\n".join(lines)


func _conversation_row(conversation: ConversationDefinition, profile_id: String, priority: int, repeatable: bool, fallback: bool) -> String:
	var dialogue_path := ""
	if conversation.dialogue_resource != null:
		dialogue_path = _relative_path(conversation.dialogue_resource.resource_path)
	return "| %s | %s | %s | %s | %s | %d | %s | %s |" % [
		_escape(conversation.conversation_id), _escape(profile_id), _escape(dialogue_path),
		_escape(conversation.start_title), _escape(conversation.initial_speaker_id), priority,
		_yes_no(repeatable), _yes_no(fallback),
	]


func _get_profile_references(index: NarrativeIndex, conversation: ConversationDefinition) -> Array[Dictionary]:
	var references: Array[Dictionary] = []
	for profile_record in index.profiles:
		var profile := profile_record["resource"] as DialogueProfile
		for entry in profile.entries:
			if entry == null or entry.conversation != conversation:
				continue
			references.append({
				"profile_id": profile.profile_id,
				"priority": entry.priority,
				"repeatable": entry.repeatable,
				"fallback": entry.is_fallback,
			})
	return references


func _build_quests(index: NarrativeIndex) -> String:
	var lines := PackedStringArray([
		"# Quests", "", "> Generated file. Do not edit manually.", "",
		"| Quest ID | Description | Catalog | Objectives | Resource |", "|---|---|---|---:|---|",
	])
	var records := index.quests.duplicate()
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["id"]) < str(b["id"]))

	for record in records:
		var quest := record["resource"] as QuestDefinition
		lines.append("| %s | %s | %s | %d | %s |" % [
			_escape(quest.quest_id), _escape(quest.description), _escape(_get_quest_catalogs(index, quest)), quest.objectives.size(),
			_escape(_relative_path(str(record["path"]))),
		])

	for record in records:
		var quest := record["resource"] as QuestDefinition
		lines.append_array(["", "## %s" % quest.quest_id, "", "| Objective ID | Event | Target type | Target ID | Required |", "|---|---|---|---|---:|"])
		for objective in quest.objectives:
			if objective == null:
				continue
			lines.append("| %s | %s | %s | %s | %d |" % [
				_escape(objective.objective_id), QuestObjectiveDefinition.EventType.keys()[objective.event_type],
				QuestObjectiveDefinition.TargetType.keys()[objective.target_type], _escape(objective.target_id),
				objective.required_amount,
			])

	lines.append("")
	return "\n".join(lines)


func _get_quest_catalogs(index: NarrativeIndex, quest: QuestDefinition) -> String:
	var catalog_ids := PackedStringArray()
	for catalog_record in index.catalogs:
		var catalog := catalog_record["resource"] as QuestCatalog
		if quest in catalog.quests:
			catalog_ids.append(str(catalog.catalog_id))
	catalog_ids.sort()
	return ", ".join(catalog_ids) if not catalog_ids.is_empty() else "—"


func _build_validation(index: NarrativeIndex, issues: Array[NarrativeValidationIssue]) -> String:
	var error_count := 0
	var warning_count := 0
	var info_count := 0
	for issue in issues:
		match issue.severity:
			NarrativeValidationIssue.Severity.ERROR: error_count += 1
			NarrativeValidationIssue.Severity.WARNING: warning_count += 1
			NarrativeValidationIssue.Severity.INFO: info_count += 1

	var summary := index.get_summary()
	var lines := PackedStringArray([
		"# Narrative validation", "", "> Generated file. Do not edit manually.", "",
		"- Conversations: %d" % summary["conversations"], "- Profiles: %d" % summary["profiles"],
		"- Quests: %d" % summary["quests"], "- Objectives: %d" % summary["objectives"],
		"- Errors: %d" % error_count, "- Warnings: %d" % warning_count, "- Info: %d" % info_count,
		"", "| Severity | Code | Related ID | Resource | Message |", "|---|---|---|---|---|",
	])
	for issue in issues:
		lines.append("| %s | %s | %s | %s | %s |" % [
			issue.get_severity_name(), _escape(issue.code), _escape(issue.related_id),
			_escape(_relative_path(issue.resource_path)), _escape(issue.message),
		])
	lines.append("")
	return "\n".join(lines)


func _write_document(path: String, contents: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(contents)
	return OK


func _get_date_prefix() -> String:
	var date := Time.get_date_dict_from_system()
	return "%02d%02d%02d" % [int(date["year"]) % 100, date["month"], date["day"]]


func _relative_path(path: String) -> String:
	return path.trim_prefix("res://")


func _escape(value: Variant) -> String:
	return str(value).replace("|", "\\|").replace("\n", "<br>")


func _yes_no(value: bool) -> String:
	return "yes" if value else "no"
