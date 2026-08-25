extends Control
class_name MissionsPanel

const OBJECTIVE_FONT_SIZE := 5
const OBJECTIVE_COLOR := Color(0.25, 0.28, 0.25, 0.72)
const OBJECTIVE_INDENT := 2
const MISSION_FONT_SIZE := 5

@export var mission_font: Font
@export var objective_font: Font

@onready var missions_scroll: ScrollContainer = %MissionsScroll
@onready var left_missions_list: VBoxContainer = %LeftMissionsList
@onready var right_missions_list: VBoxContainer = %RightMissionsList
@onready var empty_label: Label = %EmptyLabel


func _ready() -> void:
	if mission_font:
		empty_label.add_theme_font_override("font", mission_font)
	QuestManager.quest_started.connect(_on_quest_changed)
	QuestManager.quest_updated.connect(_on_quest_changed)
	QuestManager.quest_completed.connect(_on_quest_changed)
	QuestManager.quest_failed.connect(_on_quest_changed)
	QuestManager.state_reloaded.connect(refresh)
	refresh()


func prepare_to_open() -> void:
	refresh()
	missions_scroll.set_deferred("scroll_vertical", 0)


func on_selected() -> void:
	# TODO: aquí pode ir son
	pass


func refresh() -> void:
	_clear_container(left_missions_list)
	_clear_container(right_missions_list)
	var active_ids: Array[StringName] = []
	var completed_ids: Array[StringName] = []
	for quest_id in QuestManager.get_registered_quest_ids():
		var definition := QuestManager.get_quest_definition(quest_id)
		if definition == null or not definition.show_in_notebook:
			continue
		match QuestManager.get_quest_status(quest_id):
			QuestState.Status.ACTIVE: active_ids.append(quest_id)
			QuestState.Status.COMPLETED: completed_ids.append(quest_id)
	active_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	completed_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) > str(b))
	var has_missions := not active_ids.is_empty() or not completed_ids.is_empty()
	missions_scroll.visible = has_missions
	empty_label.visible = not has_missions
	for quest_id in active_ids:
		_add_quest_entry(left_missions_list, quest_id)
	for quest_id in completed_ids:
		_add_quest_entry(right_missions_list, quest_id)


func _clear_container(container: VBoxContainer) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _add_quest_entry(container: VBoxContainer, quest_id: StringName) -> void:
	var definition := QuestManager.get_quest_definition(quest_id)
	if definition == null:
		return
	var quest_completed := QuestManager.is_completed(quest_id)
	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", 1)
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(entry)
	if not definition.description.strip_edges().is_empty():
		entry.add_child(_create_text_label(definition.description, quest_completed, true))
	if quest_completed:
		return

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", OBJECTIVE_INDENT)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.add_child(margin)
	var objectives_list := VBoxContainer.new()
	objectives_list.add_theme_constant_override("separation", 0)
	objectives_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(objectives_list)

	var notebook_items := _build_notebook_items(definition)
	var first_pending: Dictionary = {}
	for item in notebook_items:
		if not _is_item_completed(quest_id, item):
			first_pending = item
			break
	for item in notebook_items:
		var completed := _is_item_completed(quest_id, item)
		if completed or item == first_pending:
			_add_notebook_item(objectives_list, quest_id, item, completed)


func _create_text_label(text: String, completed: bool, is_mission: bool) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = "[s]%s[/s]" % text if completed else text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.fit_content = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_mission and mission_font:
		label.add_theme_font_override("normal_font", mission_font)
	elif not is_mission and objective_font:
		label.add_theme_font_override("normal_font", objective_font)
	label.add_theme_font_size_override("normal_font_size", MISSION_FONT_SIZE if is_mission else OBJECTIVE_FONT_SIZE)
	if is_mission:
		label.add_theme_constant_override("line_separation", -1)
	else:
		label.add_theme_color_override("default_color", OBJECTIVE_COLOR)
	return label


func _build_notebook_items(definition: QuestDefinition) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var groups_by_id := {}
	var emitted_groups := {}
	for group in definition.objective_groups:
		if group != null:
			for objective_id in group.objective_ids:
				groups_by_id[objective_id] = group
	for objective in definition.objectives:
		if objective == null:
			continue
		var group := groups_by_id.get(objective.objective_id) as QuestObjectiveGroupDefinition
		if group != null:
			var group_id := group.get_instance_id()
			if emitted_groups.has(group_id):
				continue
			emitted_groups[group_id] = true
			if group.show_in_notebook:
				items.append({
					"description": group.description,
					"objective_ids": group.objective_ids,
					"completion_mode": group.completion_mode,
					"objective": null,
				})
		elif objective.show_in_notebook:
			items.append({
				"description": objective.description,
				"objective_ids": [objective.objective_id],
				"completion_mode": QuestObjectiveGroupDefinition.CompletionMode.ALL,
				"objective": objective,
			})
	return items


func _is_item_completed(quest_id: StringName, item: Dictionary) -> bool:
	var objective_ids: Array = item["objective_ids"]
	if objective_ids.is_empty():
		return false
	var completion_mode := int(item.get(
		"completion_mode",
		QuestObjectiveGroupDefinition.CompletionMode.ALL
	))
	if completion_mode == QuestObjectiveGroupDefinition.CompletionMode.ANY:
		for objective_id in objective_ids:
			if QuestManager.is_objective_completed(quest_id, StringName(objective_id)):
				return true
		return false
	for objective_id in objective_ids:
		if not QuestManager.is_objective_completed(quest_id, StringName(objective_id)):
			return false
	return true


func _add_notebook_item(container: VBoxContainer, quest_id: StringName, item: Dictionary, completed: bool) -> void:
	var text := str(item["description"]).strip_edges()
	if text.is_empty():
		return
	var objective := item["objective"] as QuestObjectiveDefinition
	if objective != null and not completed:
		var progress := QuestManager.get_objective_progress(quest_id, objective.objective_id)
		if progress > 0:
			text += "  (%d)" % progress
	container.add_child(_create_text_label(text, completed, false))


func _on_quest_changed(_quest_id: StringName) -> void:
	refresh()
