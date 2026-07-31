@tool
extends EditorPlugin

const NarrativeToolsDock := preload("res://addons/florilexio_narrative_tools/narrative_tools_dock.gd")

var dock: Control

func _enter_tree() -> void:
	dock = NarrativeToolsDock.new()
	dock.name = "Narrative"
	dock.resource_open_requested.connect(_open_resource)
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, dock)
	dock.resource_created.connect(_on_resource_created)
	dock.documentation_generated.connect(_on_documentation_generated)

func _exit_tree() -> void:
	if dock == null:
		return

	remove_control_from_docks(dock)
	dock.queue_free()
	dock = null

func _open_resource(resource_path: String) -> void:
	var resource := ResourceLoader.load(resource_path)

	if resource == null:
		push_warning("Narrative tools could not open resource: %s"% resource_path)
		return

	get_editor_interface().edit_resource(resource)


func _on_resource_created(resource_path: String) -> void:
	get_editor_interface().get_resource_filesystem().scan()
	_open_resource(resource_path)


func _on_documentation_generated(_paths: PackedStringArray) -> void:
	get_editor_interface().get_resource_filesystem().scan()
