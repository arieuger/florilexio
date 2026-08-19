@tool
extends TextureRect
class_name FlorilexioVisualReferenceSection

@export var fragment_id: StringName = &"":
	set(value):
		fragment_id = value
		_render.call_deferred()

@export var locked_texture: Texture2D:
	set(value):
		locked_texture = value
		_render.call_deferred()

var _plant_id: StringName = &""
var _reveal_all := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_render()
	_configure_from_page.call_deferred()


func configure(plant_id: StringName, reveal_all: bool = false) -> void:
	_plant_id = plant_id
	_reveal_all = reveal_all
	_render()


func _configure_from_page() -> void:
	var ancestor := get_parent()
	while ancestor:
		if ancestor is FlorilexioPage:
			configure(
				ancestor.plant_id,
				Engine.is_editor_hint() and ancestor.preview_all_knowledge
			)
			return
		ancestor = ancestor.get_parent()


func _render() -> void:
	if not is_node_ready():
		return

	var plant_data := ItemDatabase.get_plant(_plant_id)
	var fragment: PlantKnowledgeFragment
	if plant_data:
		fragment = plant_data.get_knowledge_fragment(fragment_id)

	var is_valid_reference := (
		fragment != null
		and fragment.knowledge_type == PlantKnowledgeType.Type.VISUAL_REFERENCE
		and fragment.illustration != null
	)
	var is_revealed := _reveal_all
	if not Engine.is_editor_hint():
		is_revealed = FlorilexioManager.has_knowledge(_plant_id, fragment_id)

	if is_valid_reference and is_revealed:
		texture = fragment.illustration
		visible = true
		return

	texture = locked_texture
	visible = locked_texture != null
