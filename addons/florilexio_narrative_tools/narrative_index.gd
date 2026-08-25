class_name NarrativeIndex
extends RefCounted

const DIALOGUE_ROOT := "res://resources/dialogues"
const QUEST_ROOT := "res://resources/quests"
const ITEM_CATALOG_PATH := "res://resources/items/item_catalog.tres"


var conversations: Array[Dictionary] = []
var profiles: Array[Dictionary] = []
var quests: Array[Dictionary] = []
var catalogs: Array[Dictionary] = []
var objectives: Array[Dictionary] = []
var items: Array[Dictionary] = []
var plants: Array[Dictionary] = []

var conversations_by_id: Dictionary = {}
var profiles_by_path: Dictionary = {}
var quests_by_id: Dictionary = {}
var objectives_by_quest: Dictionary = {}
var catalogs_by_id: Dictionary = {}
var items_by_id: Dictionary = {}
var plants_by_id: Dictionary = {}

var references: Array[Dictionary] = []


static func build() -> NarrativeIndex:
	var index := NarrativeIndex.new()
	index._scan_directory(DIALOGUE_ROOT)
	index._scan_directory(QUEST_ROOT)
	index._index_item_catalog(ITEM_CATALOG_PATH)
	return index


func _scan_directory(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)

	if directory == null:
		return

	directory.list_dir_begin()
	var entry_name := directory.get_next()

	while not entry_name.is_empty():
		if not entry_name.begins_with("."):
			var entry_path := directory_path.path_join(entry_name)

			if directory.current_is_dir():
				_scan_directory(entry_path)
			elif _is_supported_resource_path(entry_path):
				_index_resource(entry_path)

		entry_name = directory.get_next()

	directory.list_dir_end()

func has_conversation(conversation_id: StringName) -> bool:
	return not conversation_id.is_empty() and conversations_by_id.has(conversation_id)


func has_quest(quest_id: StringName) -> bool:
	return not quest_id.is_empty() and quests_by_id.has(quest_id)

func has_item(item_id: StringName) -> bool:
	return not item_id.is_empty() and items_by_id.has(item_id)

func has_plant(plant_id: StringName) -> bool:
	return not plant_id.is_empty() and plants_by_id.has(plant_id)


func has_objective(quest_id: StringName, objective_id: StringName) -> bool:
	if quest_id.is_empty() or objective_id.is_empty():
		return false

	if not objectives_by_quest.has(quest_id):
		return false

	var quest_objectives: Dictionary = objectives_by_quest[quest_id]
	return quest_objectives.has(objective_id)


func get_conversation_records(conversation_id: StringName) -> Array:
	return conversations_by_id.get(conversation_id, []).duplicate()


func get_quest_records(quest_id: StringName) -> Array:
	return quests_by_id.get(quest_id, []).duplicate()


func get_catalog_records(catalog_id: StringName) -> Array:
	return catalogs_by_id.get(catalog_id, []).duplicate()


func get_item_records(item_id: StringName) -> Array:
	return items_by_id.get(item_id, []).duplicate()


func get_plant_records(plant_id: StringName) -> Array:
	return plants_by_id.get(plant_id, []).duplicate()


func get_objective_records(quest_id: StringName, objective_id: StringName) -> Array:
	if not objectives_by_quest.has(quest_id):
		return []

	var quest_objectives: Dictionary = objectives_by_quest[quest_id]
	return quest_objectives.get(objective_id, []).duplicate()


func get_quest_objective_records(quest_id: StringName) -> Array:
	var result: Array[Dictionary] = []

	if not objectives_by_quest.has(quest_id):
		return result

	var quest_objectives: Dictionary = objectives_by_quest[quest_id]

	for raw_records in quest_objectives.values():
		for record in raw_records:
			result.append(record)

	return result


func get_summary() -> Dictionary:
	return {
		"conversations": conversations.size(),
		"profiles": profiles.size(),
		"quests": quests.size(),
		"objectives": objectives.size(),
		"catalogs": catalogs.size(),
		"items": items.size(),
		"plants": plants.size(),
		"references": references.size(),
	}


func get_references_to(
	target_kind: StringName,
	target_id: StringName,
	target_parent_id: StringName = &"") -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for reference: Dictionary in references:
		if reference.get("target_kind", &"") != target_kind:
			continue

		if reference.get("target_id", &"") != target_id:
			continue

		if (not target_parent_id.is_empty() and reference.get("target_parent_id", &"") != target_parent_id):
			continue

		result.append(reference)

	return result


func _is_supported_resource_path(path: String) -> bool:
	var extension := path.get_extension().to_lower()
	return extension == "tres" or extension == "res"


func _index_resource(path: String) -> void:
	var resource := ResourceLoader.load(path)

	if resource == null:
		return

	if resource is ConversationDefinition:
		_index_conversation(resource, path)
	elif resource is DialogueProfile:
		_index_profile(resource, path)
	elif resource is QuestDefinition:
		_index_quest(resource, path)
	elif resource is QuestCatalog:
		_index_catalog(resource, path)


func _index_conversation(
	conversation: ConversationDefinition,
	path: String
) -> void:
	var record := {
		"id": conversation.conversation_id,
		"path": path,
		"resource": conversation,
	}

	conversations.append(record)
	_add_record_by_id(conversations_by_id, conversation.conversation_id, record)


func _index_profile(profile: DialogueProfile, path: String) -> void:
	var record := {
		"id": profile.profile_id,
		"path": path,
		"resource": profile,
	}

	profiles.append(record)
	profiles_by_path[path] = record
	for entry in profile.entries:
		if entry == null:
			continue

		var source_id := &""

		if entry.conversation != null:
			source_id = entry.conversation.conversation_id
			_add_reference(
				&"conversation",
				entry.conversation.conversation_id,
				&"dialogue_profile",
				profile.profile_id,
				path,
				"Entrada do perfil de diálogo"
			)

		if entry.condition_group != null:
			_index_condition(entry.condition_group, source_id, path)


func _index_condition(condition: ConversationCondition, source_id: StringName, path: String) -> void:
	if condition == null:
		return

	if condition is ConditionGroup:
		var group := condition as ConditionGroup
		for child in group.conditions:
			_index_condition(child, source_id, path)

		return

	if condition is QuestStatusCondition:
		_add_reference(&"quest", condition.quest_id, &"conversation_condition", source_id, path, "Estado de misión")

	elif condition is QuestObjectiveCompletedCondition:
		_add_reference(&"objective", condition.objective_id, &"conversation_condition", source_id, path, "Objetivo completado", condition.quest_id)

	elif condition is ConversationFinishedCondition:
		_add_reference(&"conversation", condition.conversation_id, &"conversation_condition", source_id, path, "Conversación finalizada")

	elif condition is InventoryHasCondition:
		var reference_type := (&"plant"
			if condition.target_type == QuestObjectiveDefinition.TargetType.PLANT_SPECIES
			else &"item"
		)
		_add_reference(reference_type, condition.target_id, &"conversation_condition", source_id, path, "Elemento en inventario")


func _index_quest(quest: QuestDefinition, path: String) -> void:
	var quest_record := {
		"id": quest.quest_id,
		"path": path,
		"resource": quest,
	}

	quests.append(quest_record)
	_add_record_by_id(quests_by_id, quest.quest_id, quest_record)

	if not objectives_by_quest.has(quest.quest_id):
		objectives_by_quest[quest.quest_id] = {}

	var quest_objectives: Dictionary = (
		objectives_by_quest[quest.quest_id]
	)

	for objective in quest.objectives:
		if objective == null:
			continue

		var objective_record := {
			"id": objective.objective_id,
			"quest_id": quest.quest_id,
			"path": path,
			"resource": objective,
			"quest": quest,
		}

		objectives.append(objective_record)
		_add_record_by_id(quest_objectives, objective.objective_id, objective_record)

		match objective.target_type:
			QuestObjectiveDefinition.TargetType.CONVERSATION:
				_add_reference(
					&"conversation",
					objective.target_id,
					&"quest_objective",
					objective.objective_id,
					path,
					"Obxectivo da quest '%s'" % quest.quest_id
				)

			QuestObjectiveDefinition.TargetType.PLANT_SPECIES:
				_add_reference(
					&"plant",
					objective.target_id,
					&"quest_objective",
					objective.objective_id,
					path,
					"Obxectivo da quest '%s'" % quest.quest_id
				)

			QuestObjectiveDefinition.TargetType.ITEM_ID:
				_add_reference(
					&"item",
					objective.target_id,
					&"quest_objective",
					objective.objective_id,
					path,
					"Obxectivo da quest '%s'" % quest.quest_id
				)


func _index_catalog(catalog: QuestCatalog, path: String) -> void:
	var record := {
		"id": catalog.catalog_id,
		"path": path,
		"resource": catalog,
	}

	catalogs.append(record)
	_add_record_by_id(catalogs_by_id, catalog.catalog_id, record)


func _index_item_catalog(catalog_path: String) -> void:
	var catalog := ResourceLoader.load(catalog_path) as ItemCatalog

	if catalog == null:
		return

	for item in catalog.items:
		if item == null:
			continue

		var record := {
			"id": item.id,
			"path": item.resource_path,
			"resource": item,
			"catalog_path": catalog_path,
		}

		items.append(record)
		_add_record_by_id(items_by_id, item.id, record)

		if item is PlantData:
			plants.append(record)
			_add_record_by_id(plants_by_id, item.id, record)


func _add_record_by_id(index: Dictionary, id: StringName, record: Dictionary) -> void:
	if not index.has(id):
		index[id] = []

	var records: Array = index[id]
	records.append(record)
	index[id] = records


func _add_reference(
	target_kind: StringName,
	target_id: StringName,
	source_kind: StringName,
	source_id: StringName,
	source_path: String,
	description: String,
	target_parent_id: StringName = &"") -> void:
	if target_id.is_empty():
		return

	references.append({
		"target_kind": target_kind,
		"target_id": target_id,
		"target_parent_id": target_parent_id,
		"source_kind": source_kind,
		"source_id": source_id,
		"source_path": source_path,
		"description": description,
	})
