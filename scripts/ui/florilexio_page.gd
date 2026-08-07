@tool
extends Control
class_name FlorilexioPage

@export var plant_id: StringName = &"":
	set(value):
		plant_id = value
		_refresh_sections.call_deferred()

@export var preview_all_knowledge := true:
	set(value):
		preview_all_knowledge = value
		_refresh_sections.call_deferred()


func _ready() -> void:
	if not Engine.is_editor_hint():
		FlorilexioManager.knowledge_changed.connect(_on_knowledge_changed)
	_refresh_sections.call_deferred()


func _refresh_sections() -> void:
	if not is_node_ready():
		return

	var reveal_all := Engine.is_editor_hint() and preview_all_knowledge
	for child in find_children("*", "", true, false):
		if child is FlorilexioKnowledgeSection:
			child.configure(plant_id, reveal_all)


func _on_knowledge_changed(changed_plant_id: StringName) -> void:
	if changed_plant_id == plant_id:
		_refresh_sections()
