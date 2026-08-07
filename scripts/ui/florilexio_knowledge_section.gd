@tool
extends RichTextLabel
class_name FlorilexioKnowledgeSection

enum Presentation {
	MAIN_TEXT,
	TITLE,
	SUBTITLE,
	MARGINAL_NOTE,
}

@export var knowledge_type: PlantKnowledgeType.Type = PlantKnowledgeType.Type.DESCRIPTION:
	set(value):
		knowledge_type = value
		_render.call_deferred()

@export var fragment_ids: Array[StringName] = []:
	set(value):
		fragment_ids = value
		_render.call_deferred()

@export var presentation := Presentation.MAIN_TEXT:
	set(value):
		presentation = value
		_render.call_deferred()

@export_multiline var fragment_separator := "\n\n":
	set(value):
		fragment_separator = value
		_render.call_deferred()

@export_multiline var locked_text := "":
	set(value):
		locked_text = value
		_render.call_deferred()

var _plant_id: StringName = &""
var _reveal_all := false


func _ready() -> void:
	bbcode_enabled = true
	fit_content = false
	scroll_active = false
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
	if plant_data == null:
		_show_locked_state()
		return

	var revealed_texts: PackedStringArray = []
	for fragment_id in fragment_ids:
		var fragment: PlantKnowledgeFragment = plant_data.get_knowledge_fragment(fragment_id)
		if fragment == null or fragment.knowledge_type != knowledge_type:
			continue
		var is_revealed := _reveal_all
		if not Engine.is_editor_hint():
			is_revealed = FlorilexioManager.has_knowledge(_plant_id, fragment_id)
		if not is_revealed:
			continue
		revealed_texts.append(fragment.text)

	if revealed_texts.is_empty():
		_show_locked_state()
		return

	visible = true
	text = _format_text(fragment_separator.join(revealed_texts))


func _show_locked_state() -> void:
	text = locked_text
	visible = not locked_text.is_empty()


func _format_text(value: String) -> String:
	match presentation:
		Presentation.TITLE:
			return "[center][b]%s[/b][/center]" % value
		Presentation.SUBTITLE:
			return "[center][i]%s[/i][/center]" % value
		_:
			return value
