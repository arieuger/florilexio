@tool
class_name NarrativeResourceFactory
extends RefCounted

static func normalize_id(raw_value: String) -> StringName:
	var normalized := raw_value.strip_edges().to_lower()

	var replacements := {
		"á": "a",
		"é": "e",
		"í": "i",
		"ó": "o",
		"ú": "u",
		"ü": "u",
		"ñ": "n",
		"ç": "c",
	}

	for source_character in replacements:
		normalized = normalized.replace(source_character, replacements[source_character])

	var invalid_characters := RegEx.new()
	invalid_characters.compile("[^a-z0-9_]+")
	normalized = invalid_characters.sub(normalized, "_", true)

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


	for condition_index in range(request.conditions.size()):
		var condition := request.conditions[condition_index]

		if condition == null:
			errors.append("condition %d is null" % condition_index)
			continue

		if condition is QuestStatusCondition:
			var quest_condition := condition as QuestStatusCondition

			if quest_condition.quest_id.is_empty():
				errors.append("condition %d has no quest selected"% condition_index)
			elif not index.has_quest(quest_condition.quest_id):
				errors.append("condition %d refers to unknown quest '%s'"% [
						condition_index,
						quest_condition.quest_id,
					]
				)

		elif condition is QuestObjectiveCompletedCondition:
			var objective_condition := condition as QuestObjectiveCompletedCondition

			if objective_condition.quest_id.is_empty():
				errors.append("condition %d has no quest selected"% condition_index)
			elif objective_condition.objective_id.is_empty():
				errors.append("condition %d has no objective selected"% condition_index)
			elif not index.has_objective(objective_condition.quest_id, objective_condition.objective_id):
				errors.append("condition %d refers to unknown objective '%s' in quest '%s'" % [
						condition_index,
						objective_condition.objective_id,
						objective_condition.quest_id,
					]
				)

		elif condition is ConversationFinishedCondition:
			var conversation_condition := condition as ConversationFinishedCondition

			if conversation_condition.conversation_id.is_empty():
				errors.append("condition %d has no conversation selected"% condition_index)
			elif not index.has_conversation(conversation_condition.conversation_id):
				errors.append("condition %d refers to unknown conversation '%s'"% [
						condition_index,
						conversation_condition.conversation_id,
					]
				)

		elif condition is InventoryHasPlantCondition:
			var inventory_condition := condition as InventoryHasPlantCondition

			if inventory_condition.plant_id.is_empty():
				errors.append("condition %d has no plant selected" % condition_index
				)
			elif not index.has_plant(inventory_condition.plant_id):
				errors.append("condition %d refers to unknown plant '%s'" % [
						condition_index,
						inventory_condition.plant_id,
					]
				)

			if inventory_condition.amount <= 0:
				errors.append("condition %d must require at least one plant" % condition_index)


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

	var save_error := ResourceSaver.save(definition, request.save_path, ResourceSaver.FLAG_CHANGE_PATH)

	if save_error != OK:
		result.error_message = "Could not save conversation definition at '%s': %s"% [request.save_path, error_string(save_error)]
		return result

	var saved_definition := ResourceLoader.load(request.save_path, "", ResourceLoader.CACHE_MODE_REPLACE) as ConversationDefinition
	if saved_definition == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(request.save_path))
		result.error_message = "Conversation definition was saved but could not be loaded back from '%s'." % request.save_path
		return result

	var entry := ConversationEntry.new()
	entry.conversation = saved_definition
	entry.priority = request.priority
	entry.repeatable = request.repeatable
	entry.is_fallback = request.fallback
	entry.conditions = request.conditions.duplicate()

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



#################################
## QUESTS ##
#################################
static func get_quest_creation_errors(request: QuestCreationRequest, index: NarrativeIndex) -> PackedStringArray:
	var errors := PackedStringArray()

	if request == null:
		errors.append("creation request is null")
		return errors

	var definition := QuestDefinition.new()
	definition.quest_id = request.quest_id
	definition.description = request.description
	definition.objectives = request.objectives.duplicate()
	definition.objective_groups = request.objective_groups.duplicate()
	definition.quest_type = request.quest_type
	definition.show_in_notebook = request.show_in_notebook

	errors.append_array(definition.get_validation_errors())

	if index.has_quest(request.quest_id):
		errors.append("quest_id '%s' already exists" % request.quest_id)

	if request.target_catalog == null:
		errors.append("target_catalog is null")
	elif request.target_catalog.resource_path.is_empty():
		errors.append("target_catalog has not been saved")
	else:
		for existing_quest in request.target_catalog.quests:
			if existing_quest == null:
				continue

			if existing_quest.quest_id == request.quest_id:
				errors.append("catalog '%s' already contains quest_id '%s'" % [request.target_catalog.catalog_id, request.quest_id,])
				break

	for objective in request.objectives:
		if objective == null or objective.target_id.is_empty():
			continue

		match objective.target_type:
			QuestObjectiveDefinition.TargetType.CONVERSATION:
				if not index.has_conversation(objective.target_id):
					errors.append("objective '%s' refers to unknown conversation '%s'" % [objective.objective_id, objective.target_id])
			QuestObjectiveDefinition.TargetType.PLANT_SPECIES:
				if not index.has_plant(objective.target_id):
					errors.append("objective '%s' refers to unknown plant '%s'" % [objective.objective_id, objective.target_id])

	if request.save_path.is_empty():
		errors.append("save_path is empty")
	elif not request.save_path.begins_with("res://"):
		errors.append("save_path must be inside res://")
	elif request.save_path.get_extension().to_lower() != "tres":
		errors.append("save_path must use the .tres extension")
	elif ResourceLoader.exists(request.save_path):
		errors.append("a resource already exists at '%s'" % request.save_path)

	return errors


static func create_quest(request: QuestCreationRequest, index: NarrativeIndex) -> QuestCreationResult:
	var result := QuestCreationResult.new()
	var errors := get_quest_creation_errors(request, index)

	if not errors.is_empty():
		result.error_message = "\n".join(errors)
		return result

	var definition := QuestDefinition.new()
	definition.quest_id = request.quest_id
	definition.description = request.description
	definition.objectives = request.objectives.duplicate()
	definition.objective_groups = request.objective_groups.duplicate()
	definition.quest_type = request.quest_type
	definition.show_in_notebook = request.show_in_notebook

	var save_error := ResourceSaver.save(
		definition,
		request.save_path,
		ResourceSaver.FLAG_CHANGE_PATH
	)

	if save_error != OK:
		result.error_message = ("Could not save quest definition at '%s': %s" % [request.save_path, error_string(save_error)])
		return result

	var saved_definition := ResourceLoader.load(request.save_path, "", ResourceLoader.CACHE_MODE_REPLACE) as QuestDefinition

	if saved_definition == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(request.save_path))
		result.error_message = ("Quest definition was saved but could not be loaded back from '%s'.") % request.save_path
		return result

	request.target_catalog.quests.append(saved_definition)

	var catalog_save_error := ResourceSaver.save(request.target_catalog, request.target_catalog.resource_path)

	if catalog_save_error != OK:
		request.target_catalog.quests.erase(saved_definition)

		DirAccess.remove_absolute(ProjectSettings.globalize_path(request.save_path))

		result.error_message = "Quest definition was rolled back because catalog '%s' could not be saved: %s" % [
			request.target_catalog.resource_path,
			error_string(catalog_save_error),
		]
		return result

	result.success = true
	result.resource_path = request.save_path
	result.quest = saved_definition

	return result
