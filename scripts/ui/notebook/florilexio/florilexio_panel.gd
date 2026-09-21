extends Control
class_name FlorilexioPanel

signal pagination_changed

@export var page_scenes: Array[PackedScene] = []

@onready var empty_label: Label = %FlorilexioEmptyLabel
@onready var left_page_slot: Control = %LeftPageSlot
@onready var right_page_slot: Control = %RightPageSlot

var _available_pages: Array[PackedScene] = []
var _current_spread := 0


func _ready() -> void:
	FlorilexioManager.knowledge_changed.connect(_on_knowledge_changed)
	_rebuild()


func prepare_to_open() -> void:
	_rebuild()


func on_selected() -> void:
	_show_current_spread()


func can_go_previous() -> bool:
	return _current_spread > 0


func can_go_next() -> bool:
	return _current_spread < _get_spread_count() - 1


func previous_spread() -> void:
	if not can_go_previous():
		return
	_current_spread -= 1
	_show_current_spread()


func next_spread() -> void:
	if not can_go_next():
		return
	_current_spread += 1
	_show_current_spread()


func _rebuild() -> void:
	_available_pages.clear()
	for page_scene in page_scenes:
		if page_scene == null:
			continue
		var page := page_scene.instantiate() as FlorilexioPage
		if page == null:
			continue
		var plant := ItemDatabase.get_plant(page.plant_id)
		if plant != null and FlorilexioManager.can_be_collected(page.plant_id, plant.collection_requirements):
			_available_pages.append(page_scene)
		# TODO: Comprobar se é así ou co mínimo coñecemento (un elemento como o nome): Para reunión!
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
	empty_label.visible = _available_pages.is_empty()
	pagination_changed.emit()


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


func _on_knowledge_changed(_plant_id: StringName) -> void:
	_rebuild()
