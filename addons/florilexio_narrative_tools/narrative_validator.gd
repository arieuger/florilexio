class_name NarrativeValidator
extends RefCounted


func validate_project(existing_index: NarrativeIndex = null) -> Array[NarrativeValidationIssue]:
	var index := existing_index

	if index == null:
		index = NarrativeIndex.build()

	var issues: Array[NarrativeValidationIssue] = []

	_validate_local_resources(index, issues)
	_validate_duplicate_ids(index, issues)
	_validate_dialogue_profiles(index, issues)
	_validate_condition_references(index, issues)
	_validate_quest_objective_references(index, issues)

	return issues


func _validate_local_resources(index: NarrativeIndex, issues: Array[NarrativeValidationIssue]) -> void:
	for record in index.conversations:
		var definition := record["resource"] as ConversationDefinition
		_append_resource_errors(definition.get_validation_errors(), &"invalid_conversation", "Conversation", record, issues)

	for record in index.profiles:
		var profile := record["resource"] as DialogueProfile
		_append_resource_errors(profile.get_validation_errors(), &"invalid_dialogue_profile", "Dialogue profile", record, issues)

	for record in index.quests:
		var quest := record["resource"] as QuestDefinition
		_append_resource_errors(quest.get_validation_errors(), &"invalid_quest", "Quest", record, issues)

	for record in index.catalogs:
		var catalog := record["resource"] as QuestCatalog
		_append_resource_errors(catalog.get_validation_errors(), &"invalid_quest_catalog", "Quest catalog", record, issues)


func _validate_dialogue_profiles(index: NarrativeIndex, issues: Array[NarrativeValidationIssue]) -> void:
	for record in index.profiles:
		var profile := record["resource"] as DialogueProfile
		var path := str(record.get("path", ""))
		var fallback_count := 0
		var priorities: Dictionary = {}

		for entry in profile.entries:
			if entry == null:
				continue

			if entry.is_fallback:
				fallback_count += 1
				continue

			if not priorities.has(entry.priority):
				priorities[entry.priority] = 0

			priorities[entry.priority] += 1

		if fallback_count == 0:
			issues.append(NarrativeValidationIssue.new(
					NarrativeValidationIssue.Severity.WARNING,
					&"dialogue_profile_without_fallback",
					"Dialogue profile '%s' has no fallback entry."% profile.profile_id,
					path,
					profile.profile_id
				)
			)

		elif fallback_count > 1:
			issues.append(NarrativeValidationIssue.new(
					NarrativeValidationIssue.Severity.WARNING,
					&"dialogue_profile_multiple_fallbacks",
					"Dialogue profile '%s' has %d fallback entries."% [profile.profile_id, fallback_count],
					path,
					profile.profile_id
				)
			)

		for priority in priorities:
			var entry_count: int = priorities[priority]
			if entry_count <= 1:
				continue

			issues.append(NarrativeValidationIssue.new(
					NarrativeValidationIssue.Severity.WARNING,
					&"dialogue_profile_shared_priority",
					"Dialogue profile '%s' has %d non-fallback entries with priority %d."
					% [
						profile.profile_id,
						entry_count,
						priority,
					],
					path,
					profile.profile_id
				)
			)


func _validate_condition_references(index: NarrativeIndex, issues: Array[NarrativeValidationIssue]) -> void:
	for profile_record in index.profiles:
		var profile := profile_record["resource"] as DialogueProfile
		var path := str(profile_record.get("path", ""))

		for entry_index in range(profile.entries.size()):
			var entry := profile.entries[entry_index]

			if entry == null:
				continue

			for condition_index in range(entry.conditions.size()):
				var condition := entry.conditions[condition_index]

				if condition == null:
					continue

				_validate_condition_reference(condition, entry_index, condition_index, path, index, issues)


func _validate_condition_reference(
	condition: ConversationCondition,
	entry_index: int,
	condition_index: int,
	path: String,
	index: NarrativeIndex,
	issues: Array[NarrativeValidationIssue]
) -> void:
	if condition is QuestStatusCondition:
		var quest_condition := condition as QuestStatusCondition

		if not quest_condition.quest_id.is_empty() \
				and not index.has_quest(quest_condition.quest_id):
			_append_missing_reference_issue(
				&"condition_missing_quest",
				"Entry %d condition %d refers to unknown quest '%s'."% [entry_index, condition_index, quest_condition.quest_id],
				path,
				quest_condition.quest_id,
				issues
			)

	elif condition is QuestObjectiveCompletedCondition:
		var objective_condition := (
			condition as QuestObjectiveCompletedCondition
		)

		if not objective_condition.quest_id.is_empty() \
				and not index.has_quest(objective_condition.quest_id):
			_append_missing_reference_issue(
				&"condition_missing_quest",
					"Entry %d condition %d refers to unknown quest '%s'."% [entry_index, condition_index, objective_condition.quest_id],
				path,
				objective_condition.quest_id,
				issues
			)

		elif not objective_condition.objective_id.is_empty() \
				and not index.has_objective(objective_condition.quest_id, objective_condition.objective_id):
			_append_missing_reference_issue(
				&"condition_missing_quest_objective",
					"Entry %d condition %d refers to unknown objective '%s' in quest '%s'."% [
					entry_index,
					condition_index,
					objective_condition.objective_id,
					objective_condition.quest_id,
				],
				path,
				objective_condition.objective_id,
				issues
			)

	elif condition is ConversationFinishedCondition:
		var conversation_condition := condition as ConversationFinishedCondition

		if not conversation_condition.conversation_id.is_empty() \
				and not index.has_conversation(
					conversation_condition.conversation_id
				):
			_append_missing_reference_issue(
				&"condition_missing_conversation",
				"Entry %d condition %d refers to unknown conversation '%s'."% [entry_index, condition_index, conversation_condition.conversation_id,],
				path,
				conversation_condition.conversation_id,
				issues
			)


	elif condition is InventoryHasPlantCondition:
		var inventory_condition := condition as InventoryHasPlantCondition

		if not inventory_condition.plant_id.is_empty() \
				and not index.has_plant(inventory_condition.plant_id):
			_append_missing_reference_issue(
				&"condition_missing_plant",
				"Entry %d condition %d refers to unknown plant '%s'."% [entry_index, condition_index, inventory_condition.plant_id,],
				path,
				inventory_condition.plant_id,
				issues
			)

func _validate_quest_objective_references(index: NarrativeIndex, issues: Array[NarrativeValidationIssue]) -> void:
	for record in index.objectives:
		var objective := record["resource"] as QuestObjectiveDefinition

		if objective == null or objective.target_id.is_empty():
			continue

		match objective.target_type:
			QuestObjectiveDefinition.TargetType.CONVERSATION:
				if index.has_conversation(objective.target_id):
					continue

				_append_objective_reference_issue(
					record,
					&"objective_missing_conversation",
					"conversation",
					objective.target_id,
					issues
				)

			QuestObjectiveDefinition.TargetType.PLANT_SPECIES:
				if index.has_plant(objective.target_id):
					continue

				_append_objective_reference_issue(
					record,
					&"objective_missing_plant",
					"plant",
					objective.target_id,
					issues
				)


func _append_objective_reference_issue(
	record: Dictionary,
	code: StringName,
	target_label: String,
	target_id: StringName,
	issues: Array[NarrativeValidationIssue]
) -> void:
	var objective := record["resource"] as QuestObjectiveDefinition
	var quest_id := StringName(record.get("quest_id", &""))
	var path := str(record.get("path", ""))

	issues.append(NarrativeValidationIssue.new(NarrativeValidationIssue.Severity.ERROR, code,
		"Objective '%s' in quest '%s' refers to unknown %s '%s'."% [
			objective.objective_id,
			quest_id,
			target_label,
			target_id,
		],
		path,
		target_id)
	)


func _append_missing_reference_issue(
	code: StringName,
	message: String,
	path: String,
	related_id: StringName,
	issues: Array[NarrativeValidationIssue]
) -> void:
	issues.append(NarrativeValidationIssue.new(NarrativeValidationIssue.Severity.ERROR, code, message, path, related_id))


func _append_resource_errors(
	errors: PackedStringArray,
	code: StringName,
	resource_label: String,
	record: Dictionary,
	issues: Array[NarrativeValidationIssue]
) -> void:
	var related_id := StringName(record.get("id", &""))
	var path := str(record.get("path", ""))

	for error_message in errors:
		issues.append(NarrativeValidationIssue.new(NarrativeValidationIssue.Severity.ERROR, code, "%s is invalid: %s"% [resource_label, error_message], path, related_id))


func _validate_duplicate_ids(index: NarrativeIndex, issues: Array[NarrativeValidationIssue]) -> void:
	_append_duplicate_issues(index.conversations_by_id, &"duplicate_conversation_id", "conversation_id", issues)
	_append_duplicate_issues(index.quests_by_id, &"duplicate_quest_id", "quest_id", issues)
	_append_duplicate_issues(index.catalogs_by_id, &"duplicate_catalog_id", "catalog_id", issues)


func _append_duplicate_issues(records_by_id: Dictionary, code: StringName, id_label: String, issues: Array[NarrativeValidationIssue]) -> void:
	for raw_id in records_by_id.keys():
		var id := StringName(raw_id)

		if id.is_empty(): # validación local: non fai falta re-comprobar aquí
			continue

		var records: Array = records_by_id[raw_id]
		if records.size() <= 1:
			continue

		var paths: Array[String] = []

		for record in records:
			paths.append(str(record.get("path", "")))

		paths.sort()

		issues.append(NarrativeValidationIssue.new(NarrativeValidationIssue.Severity.ERROR,
				code,
				"Duplicate %s '%s' found in: %s"% [id_label, id, ", ".join(paths),],
				paths[0],
				id
			))