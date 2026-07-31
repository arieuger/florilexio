class_name NarrativeIndex
extends RefCounted

const DIALOGUE_ROOT := "res://resources/dialogues"
const QUEST_ROOT := "res://resources/quests"

var conversations: Array[Dictionary] = []
var profiles: Array[Dictionary] = []
var quests: Array[Dictionary] = []
var catalogs: Array[Dictionary] = []
var objectives: Array[Dictionary] = []

var conversations_by_id: Dictionary = {}
var profiles_by_path: Dictionary = {}
var quests_by_id: Dictionary = {}
var objectives_by_quest: Dictionary = {}
var catalogs_by_id: Dictionary = {}


static func build(_include_world_scenes := false) -> NarrativeIndex:
	var index := NarrativeIndex.new()
	index._scan_directory(DIALOGUE_ROOT)
	index._scan_directory(QUEST_ROOT)
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


func get_summary() -> Dictionary:
	return {
		"conversations": conversations.size(),
		"profiles": profiles.size(),
		"quests": quests.size(),
		"objectives": objectives.size(),
		"catalogs": catalogs.size(),
	}


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


func _index_catalog(catalog: QuestCatalog, path: String) -> void:
	var record := {
		"id": catalog.catalog_id,
		"path": path,
		"resource": catalog,
	}

	catalogs.append(record)
	_add_record_by_id(catalogs_by_id, catalog.catalog_id, record)


func _add_record_by_id(index: Dictionary, id: StringName, record: Dictionary) -> void:
	if not index.has(id):
		index[id] = []

	var records: Array = index[id]
	records.append(record)
	index[id] = records