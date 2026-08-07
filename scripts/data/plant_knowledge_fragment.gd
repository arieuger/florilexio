@tool
extends Resource
class_name PlantKnowledgeFragment

@export var id: StringName
@export var knowledge_type: PlantKnowledgeType.Type
@export_multiline var text: String
