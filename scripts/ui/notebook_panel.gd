extends Control

signal close_requested

enum Section {
	MISSIONS,
	FLORILEXIO,
}

const OBJECTIVE_FONT_SIZE := 5
const OBJECTIVE_COLOR := Color(0.25, 0.28, 0.25, 0.72)
const OBJECTIVE_INDENT := 2
const OBJECTIVES_SEPARATION := 0
const MISSION_FONT_SIZE := 5
const MISSION_OBJECTIVES_SEPARATION := 1
const LINE_SPACING := -1

@export var mission_font: Font
@export var objective_font: Font
@export var florilexio_page_scenes: Array[PackedScene] = []

@onready var missions_scroll: ScrollContainer = %MissionsScroll
@onready var left_missions_list: VBoxContainer = %LeftMissionsList
@onready var right_missions_list: VBoxContainer = %RightMissionsList
@onready var empty_label: Label = %EmptyLabel
@onready var close_button: TextureButton = %CloseButton
@onready var missions_tab_button: TextureButton = %MissionsTabButton
@onready var florilexio_tab_button: TextureButton = %FlorilexioTabButton
@onready var florilexio_content: Control = %FlorilexioContent
@onready var florilexio_empty_label: Label = %FlorilexioEmptyLabel
@onready var left_page_slot: Control = %LeftPageSlot
@onready var right_page_slot: Control = %RightPageSlot
@onready var previous_spread_button: TextureButton = %PreviousSpreadButton
@onready var next_spread_button: TextureButton = %NextSpreadButton

var _active_section := Section.MISSIONS
var _has_visible_missions := false
var _available_florilexio_pages: Array[PackedScene] = []
var _current_florilexio_spread := 0


func _ready() -> void:
	if mission_font:
		empty_label.add_theme_font_override("font", mission_font)

	close_button.pressed.connect(_on_close_button_pressed)
	missions_tab_button.pressed.connect(_on_missions_tab_pressed)
	florilexio_tab_button.pressed.connect(_on_florilexio_tab_pressed)
	previous_spread_button.pressed.connect(_on_previous_spread_pressed)
	next_spread_button.pressed.connect(_on_next_spread_pressed)

	QuestManager.quest_started.connect(_on_quest_changed)
	QuestManager.quest_updated.connect(_on_quest_changed)
	QuestManager.quest_completed.connect(_on_quest_changed)
	QuestManager.quest_failed.connect(_on_quest_changed)
	QuestManager.state_reloaded.connect(_on_state_reloaded)
	FlorilexioManager.knowledge_changed.connect(_on_knowledge_changed)

	refresh()
	_rebuild_florilexio()
	_apply_section_visibility()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_requested.emit()


func prepare_to_open() -> void:
	refresh()
	_rebuild_florilexio()
	if _active_section == Section.MISSIONS:
		missions_scroll.set_deferred("scroll_vertical", 0)
	_apply_section_visibility()


func refresh() -> void:
	_clear_missions()

	var active_quest_ids: Array[StringName] = []
	var completed_quest_ids: Array[StringName] = []

	for quest_id in QuestManager.get_registered_quest_ids():
		var definition := QuestManager.get_quest_definition(quest_id)

		if definition == null or not definition.show_in_notebook:
			continue

		match QuestManager.get_quest_status(quest_id):
			QuestState.Status.ACTIVE:
				active_quest_ids.append(quest_id)
			QuestState.Status.COMPLETED:
				completed_quest_ids.append(quest_id)

	active_quest_ids.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return str(a) < str(b)
	)

	completed_quest_ids.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return str(a) > str(b)
	)

	_has_visible_missions = not active_quest_ids.is_empty() or not completed_quest_ids.is_empty()

	for quest_id in active_quest_ids:
		_add_quest_entry(left_missions_list, quest_id)

	for quest_id in completed_quest_ids:
		_add_quest_entry(right_missions_list, quest_id)

	_apply_section_visibility()


func _set_section(section: Section) -> void:
	_active_section = section
	_apply_section_visibility()
	if section == Section.FLORILEXIO:
		_show_current_florilexio_spread()


func _apply_section_visibility() -> void:
	if not is_node_ready():
		return

	var showing_missions := _active_section == Section.MISSIONS
	missions_scroll.visible = showing_missions and _has_visible_missions
	empty_label.visible = showing_missions and not _has_visible_missions
	florilexio_content.visible = not showing_missions
	missions_tab_button.button_pressed = showing_missions
	florilexio_tab_button.button_pressed = not showing_missions


func _rebuild_florilexio() -> void:
	_available_florilexio_pages.clear()

	for page_scene in florilexio_page_scenes:
		if page_scene == null:
			continue
		var page := page_scene.instantiate() as FlorilexioPage
		if page == null:
			continue
		if FlorilexioManager.has_any_knowledge(page.plant_id):
			_available_florilexio_pages.append(page_scene)
		page.free()

	_current_florilexio_spread = clampi(
		_current_florilexio_spread,
		0,
		maxi(_get_florilexio_spread_count() - 1, 0)
	)
	_show_current_florilexio_spread()


func _show_current_florilexio_spread() -> void:
	if not is_node_ready():
		return

	_clear_page_slot(left_page_slot)
	_clear_page_slot(right_page_slot)

	var first_page_index := _current_florilexio_spread * 2
	_show_page_in_slot(left_page_slot, first_page_index)
	_show_page_in_slot(right_page_slot, first_page_index + 1)

	var spread_count := _get_florilexio_spread_count()
	florilexio_empty_label.visible = _available_florilexio_pages.is_empty()
	previous_spread_button.visible = spread_count > 1
	next_spread_button.visible = spread_count > 1
	previous_spread_button.disabled = _current_florilexio_spread <= 0
	next_spread_button.disabled = _current_florilexio_spread >= spread_count - 1


func _show_page_in_slot(slot: Control, page_index: int) -> void:
	if page_index < 0 or page_index >= _available_florilexio_pages.size():
		return

	var page := _available_florilexio_pages[page_index].instantiate() as FlorilexioPage
	if page == null:
		return

	slot.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _clear_page_slot(slot: Control) -> void:
	for child in slot.get_children():
		slot.remove_child(child)
		child.queue_free()


func _get_florilexio_spread_count() -> int:
	return ceili(float(_available_florilexio_pages.size()) / 2.0)


func _on_missions_tab_pressed() -> void:
	_set_section(Section.MISSIONS)


func _on_florilexio_tab_pressed() -> void:
	_set_section(Section.FLORILEXIO)


func _on_previous_spread_pressed() -> void:
	_current_florilexio_spread = maxi(_current_florilexio_spread - 1, 0)
	_show_current_florilexio_spread()


func _on_next_spread_pressed() -> void:
	_current_florilexio_spread = mini(
		_current_florilexio_spread + 1,
		maxi(_get_florilexio_spread_count() - 1, 0)
	)
	_show_current_florilexio_spread()



func _clear_missions() -> void:
	_clear_container(left_missions_list)
	_clear_container(right_missions_list)


func _clear_container(container: VBoxContainer) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _add_quest_entry(container_: VBoxContainer, quest_id: StringName) -> void:
	var definition := QuestManager.get_quest_definition(quest_id)
	if definition == null:
		return
	var is_quest_completed := QuestManager.is_completed(quest_id)

	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", MISSION_OBJECTIVES_SEPARATION)
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container_.add_child(entry)

	if not definition.description.strip_edges().is_empty():
		var description_label := RichTextLabel.new()
		description_label.bbcode_enabled = true
		description_label.text = _format_completed_text(
			definition.description,
			is_quest_completed
		)
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.fit_content = true
		description_label.scroll_active = false
		description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if mission_font:
			description_label.add_theme_font_override(
				"normal_font",
				mission_font
			)

		description_label.add_theme_font_size_override(
			"normal_font_size",
			MISSION_FONT_SIZE
		)
		description_label.add_theme_constant_override(
			"line_separation",
			LINE_SPACING
		)
		entry.add_child(description_label)

	if is_quest_completed:
		return

	var objectives_margin := MarginContainer.new()
	objectives_margin.add_theme_constant_override(
		"margin_left",
		OBJECTIVE_INDENT
	)
	objectives_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.add_child(objectives_margin)

	var objectives_list := VBoxContainer.new()
	objectives_list.add_theme_constant_override("separation", OBJECTIVES_SEPARATION)
	objectives_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objectives_margin.add_child(objectives_list)

	var notebook_items := _build_notebook_items(definition)
	var first_pending_item: Dictionary = {}

	for item in notebook_items:
		if not _is_notebook_item_completed(quest_id, item):
			first_pending_item = item
			break

	for item in notebook_items:
		var is_completed := _is_notebook_item_completed(quest_id, item)

		if not is_completed and item != first_pending_item:
			continue

		_add_notebook_item(objectives_list, quest_id, item, is_completed)


func _format_completed_text(text: String, is_completed: bool) -> String:
	return "[s]%s[/s]" % text if is_completed else text


func _on_close_button_pressed() -> void:
	close_requested.emit()


func _on_quest_changed(_quest_id: StringName) -> void:
	refresh()


func _on_state_reloaded() -> void:
	refresh()


func _on_knowledge_changed(_plant_id: StringName) -> void:
	_rebuild_florilexio()



func _build_notebook_items(definition: QuestDefinition) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var groups_by_objective_id := {}
	var emitted_groups := {}

	for objective_group in definition.objective_groups:
		if objective_group == null:
			continue

		for objective_id in objective_group.objective_ids:
			groups_by_objective_id[objective_id] = objective_group

	for objective in definition.objectives:
		if objective == null:
			continue

		var objective_group := groups_by_objective_id.get(
			objective.objective_id
		) as QuestObjectiveGroupDefinition

		if objective_group != null:
			var group_instance_id := objective_group.get_instance_id()

			if emitted_groups.has(group_instance_id):
				continue

			emitted_groups[group_instance_id] = true
			items.append({
				"description": objective_group.description,
				"objective_ids": objective_group.objective_ids,
				"objective": null,
			})
			continue

		if not objective.show_in_notebook:
			continue

		items.append({
			"description": objective.description,
			"objective_ids": [objective.objective_id],
			"objective": objective,
		})

	return items


func _is_notebook_item_completed(quest_id: StringName, item: Dictionary) -> bool:
	var objective_ids: Array = item["objective_ids"]

	if objective_ids.is_empty():
		return false

	for objective_id in objective_ids:
		if not QuestManager.is_objective_completed(quest_id, StringName(objective_id)):
			return false

	return true


func _add_notebook_item(container: VBoxContainer, quest_id: StringName, item: Dictionary, is_completed: bool) -> void:
	var description := str(item["description"]).strip_edges()
	if description.is_empty():
		return

	var item_text := description
	var objective := item["objective"] as QuestObjectiveDefinition

	# Contador só para obxectivos tradicionais
	if objective != null and not is_completed:
		var current_progress := QuestManager.get_objective_progress(quest_id, objective.objective_id)

		if current_progress > 0:
			item_text += "  (%d)" % current_progress

	var objective_label := RichTextLabel.new()
	objective_label.bbcode_enabled = true
	objective_label.text = _format_completed_text(item_text, is_completed)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.fit_content = true
	objective_label.scroll_active = false
	objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if objective_font:
		objective_label.add_theme_font_override("normal_font", objective_font)

	objective_label.add_theme_font_size_override("normal_font_size", OBJECTIVE_FONT_SIZE)
	objective_label.add_theme_color_override("default_color", OBJECTIVE_COLOR)

	container.add_child(objective_label)