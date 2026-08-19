extends Control
class_name FlorilexioPanel

@export var page_scenes: Array[PackedScene] = []

@onready var empty_label: Label = %FlorilexioEmptyLabel
@onready var left_page_slot: Control = %LeftPageSlot
@onready var right_page_slot: Control = %RightPageSlot
@onready var previous_spread_button: TextureButton = %PreviousSpreadButton
@onready var next_spread_button: TextureButton = %NextSpreadButton

var _available_pages: Array[PackedScene] = []
var _current_spread := 0


func _ready() -> void:
	previous_spread_button.pressed.connect(_on_previous_spread_pressed)
	next_spread_button.pressed.connect(_on_next_spread_pressed)
	FlorilexioManager.knowledge_changed.connect(_on_knowledge_changed)
	_rebuild()


func prepare_to_open() -> void:
	_rebuild()


func on_selected() -> void:
	_show_current_spread()


func _rebuild() -> void:
	_available_pages.clear()
	for page_scene in page_scenes:
		if page_scene == null:
			continue
		var page := page_scene.instantiate() as FlorilexioPage
		if page == null:
			continue
		if FlorilexioManager.has_any_knowledge(page.plant_id):
			_available_pages.append(page_scene)
		page.free()
	_current_spread = clampi(_current_spread, 0, maxi(_get_spread_count() - 1, 0))
	_show_current_spread()


func _show_current_spread() -> void:
	if not is_node_ready():
		return
	_clear_page_slot(left_page_slot)
	_clear_page_slot(right_page_slot)
	var first_page_index := _current_spread * 2
	_show_page_in_slot(left_page_slot, first_page_index)
	_show_page_in_slot(right_page_slot, first_page_index + 1)
	var spread_count := _get_spread_count()
	empty_label.visible = _available_pages.is_empty()
	previous_spread_button.visible = spread_count > 1
	next_spread_button.visible = spread_count > 1
	previous_spread_button.disabled = _current_spread <= 0
	next_spread_button.disabled = _current_spread >= spread_count - 1


func _show_page_in_slot(slot: Control, page_index: int) -> void:
	if page_index < 0 or page_index >= _available_pages.size():
		return
	var page := _available_pages[page_index].instantiate() as FlorilexioPage
	if page == null:
		return
	slot.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _clear_page_slot(slot: Control) -> void:
	for child in slot.get_children():
		slot.remove_child(child)
		child.queue_free()


func _get_spread_count() -> int:
	return ceili(float(_available_pages.size()) / 2.0)


func _on_previous_spread_pressed() -> void:
	_current_spread = maxi(_current_spread - 1, 0)
	_show_current_spread()


func _on_next_spread_pressed() -> void:
	_current_spread = mini(_current_spread + 1, maxi(_get_spread_count() - 1, 0))
	_show_current_spread()


func _on_knowledge_changed(_plant_id: StringName) -> void:
	_rebuild()
