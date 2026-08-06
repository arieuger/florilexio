extends Control

signal close_requested

var OBJECTIVE_FONT_SIZE := 3
const OBJECTIVE_COLOR := Color(0.25, 0.28, 0.25, 0.72)
const OBJECTIVE_INDENT := 3
const MISSION_FONT_SIZE := 4

@export var notebook_font: Font

@onready var missions_scroll: ScrollContainer = %MissionsScroll
@onready var left_missions_list: VBoxContainer = %LeftMissionsList
@onready var right_missions_list: VBoxContainer = %RightMissionsList
@onready var empty_label: Label = %EmptyLabel
@onready var close_button: TextureButton = %CloseButton

var _tmp_font_size_test : Array[int]= [3, 4, 5, 6, 7, 8, 9, 10]


func _ready() -> void:
	if notebook_font:
		empty_label.add_theme_font_override("font", notebook_font)

	close_button.pressed.connect(_on_close_button_pressed)

	QuestManager.quest_started.connect(_on_quest_changed)
	QuestManager.quest_updated.connect(_on_quest_changed)
	QuestManager.quest_completed.connect(_on_quest_changed)
	QuestManager.quest_failed.connect(_on_quest_changed)
	QuestManager.state_reloaded.connect(_on_state_reloaded)

	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_requested.emit()


func prepare_to_open() -> void:
	refresh()
	missions_scroll.set_deferred("scroll_vertical", 0)


func refresh() -> void:
	_clear_missions()

	var active_quest_ids: Array[StringName] = []
	var completed_quest_ids: Array[StringName] = []

	for quest_id in QuestManager.get_registered_quest_ids():
		match QuestManager.get_quest_status(quest_id):
			QuestState.Status.ACTIVE:
				active_quest_ids.append(quest_id)
			QuestState.Status.COMPLETED:
				completed_quest_ids.append(quest_id)

	active_quest_ids.sort()
	completed_quest_ids.sort()

	var visible_quest_ids := active_quest_ids + completed_quest_ids
	var has_visible_missions := not visible_quest_ids.is_empty()

	missions_scroll.visible = has_visible_missions
	empty_label.visible = not has_visible_missions

	var left_page_count := ceili(visible_quest_ids.size() / 2.0)

	for i in range(_tmp_font_size_test.size()):
		var test_size := _tmp_font_size_test[i]
		OBJECTIVE_FONT_SIZE = test_size


		for index in range(visible_quest_ids.size()):
			var target_container := (left_missions_list
				if index < left_page_count
				else right_missions_list
			)

			_add_quest_entry(target_container, visible_quest_ids[index])


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

	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", 2)
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container_.add_child(entry)

	if not definition.description.strip_edges().is_empty():
		var description_label := Label.new()
		description_label.text = definition.description
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if notebook_font:
			description_label.add_theme_font_override("font", notebook_font)
		
		description_label.add_theme_font_size_override("font_size", MISSION_FONT_SIZE)
		entry.add_child(description_label)

	var objectives_margin := MarginContainer.new()
	objectives_margin.add_theme_constant_override(
		"margin_left",
		OBJECTIVE_INDENT
	)
	objectives_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.add_child(objectives_margin)

	var objectives_list := VBoxContainer.new()
	objectives_list.add_theme_constant_override("separation", 1)
	objectives_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objectives_margin.add_child(objectives_list)

	for objective in definition.objectives:
		_add_objective(
			objectives_list,
			quest_id,
			objective
		)


func _add_objective(container: VBoxContainer, quest_id: StringName, objective: QuestObjectiveDefinition) -> void:
	if objective == null:
		return

	var description := objective.description.strip_edges()
	if description.is_empty():
		return

	var current_progress := QuestManager.get_objective_progress(
		quest_id,
		objective.objective_id
	)
	var is_completed := QuestManager.is_objective_completed(
		quest_id,
		objective.objective_id
	)

	var objective_text := description

	if is_completed:
		objective_text += "  ✓"
	elif current_progress > 0:
		objective_text += "  (%d)" % current_progress

	var objective_label := Label.new()
	objective_label.text = objective_text
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if notebook_font:
		objective_label.add_theme_font_override("font", notebook_font)
	
	objective_label.add_theme_font_size_override("font_size", OBJECTIVE_FONT_SIZE)
	objective_label.add_theme_color_override("font_color", OBJECTIVE_COLOR)
	container.add_child(objective_label)


func _on_close_button_pressed() -> void:
	close_requested.emit()


func _on_quest_changed(_quest_id: StringName) -> void:
	refresh()


func _on_state_reloaded() -> void:
	refresh()
