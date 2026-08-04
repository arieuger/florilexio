@tool
class_name QuestCreationRequest
extends RefCounted

var quest_id: StringName
var description: String
var objectives: Array[QuestObjectiveDefinition] = []
var target_catalog: QuestCatalog
var save_path: String
