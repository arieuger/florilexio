@tool
class_name QuestCreationRequest
extends RefCounted

var quest_id: StringName
var description: String
var objectives: Array[QuestObjectiveDefinition] = []
var objective_groups: Array[QuestObjectiveGroupDefinition] = []
var quest_type: QuestDefinition.QuestType = QuestDefinition.QuestType.MAIN
var show_in_notebook := true
var target_catalog: QuestCatalog
var save_path: String
