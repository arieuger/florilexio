@tool
extends VBoxContainer

signal resource_open_requested(resource_path: String)
signal resource_created(resource_path: String)

const ConversationCreatorPanel := preload("res://addons/florilexio_narrative_tools/conversation_creator_panel.gd")
const QuestCreatorPanel := preload("res://addons/florilexio_narrative_tools/quest_creator_panel.gd")

var conversation_scroll: ScrollContainer
var conversation_panel: Control
var summary_label: Label
var issues_tree: Tree

var quest_scroll: ScrollContainer
var quest_panel: Control

func _ready() -> void:
	var title := Label.new()
	title.text = "Florilexio - Ferramentas narrativas"
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)

	var create_conversation_button := Button.new()
	create_conversation_button.text = "Crear conversa"
	create_conversation_button.pressed.connect(
		_toggle_conversation_panel
	)
	add_child(create_conversation_button)

	var create_quest_button := Button.new()
	create_quest_button.text = "Crear quest"
	create_quest_button.pressed.connect(
		_toggle_quest_panel
	)
	add_child(create_quest_button)

	conversation_scroll = ScrollContainer.new()
	conversation_scroll.visible = false
	conversation_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	conversation_scroll.custom_minimum_size.y = 420
	conversation_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(conversation_scroll)

	conversation_panel = ConversationCreatorPanel.new()
	conversation_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conversation_panel.conversation_created.connect(_on_conversation_created)
	conversation_scroll.add_child(conversation_panel)

	quest_scroll = ScrollContainer.new()
	quest_scroll.visible = false
	quest_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	quest_scroll.custom_minimum_size.y = 420
	quest_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(quest_scroll)

	quest_panel = QuestCreatorPanel.new()
	quest_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_panel.quest_created.connect(_on_quest_created)
	quest_scroll.add_child(quest_panel)

	var validate_button := Button.new()
	validate_button.text = "Validar proxecto"
	validate_button.pressed.connect(_validate_project)
	add_child(validate_button)

	summary_label = Label.new()
	summary_label.text = "Non se lanzaou a validación."
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(summary_label)

	issues_tree = Tree.new()
	issues_tree.columns = 2
	issues_tree.hide_root = true
	issues_tree.column_titles_visible = true
	issues_tree.set_column_title(0, "Severidade")
	issues_tree.set_column_title(1, "Problema")
	issues_tree.set_column_expand(0, false)
	issues_tree.set_column_custom_minimum_width(0, 75)
	issues_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	issues_tree.item_activated.connect(_on_issue_activated)
	add_child(issues_tree)


func _validate_project() -> void:
	var index := NarrativeIndex.build()
	var issues := NarrativeValidator.new().validate_project(index)

	var error_count := 0
	var warning_count := 0
	var info_count := 0

	for issue in issues:
		match issue.severity:
			NarrativeValidationIssue.Severity.ERROR:
				error_count += 1
			NarrativeValidationIssue.Severity.WARNING:
				warning_count += 1
			NarrativeValidationIssue.Severity.INFO:
				info_count += 1

	var index_summary := index.get_summary()

	summary_label.text = (
		"%d conversacións · %d perfís · %d quests\n"
		+ "%d erros · %d warnings · %d info"
	) % [
		index_summary["conversations"],
		index_summary["profiles"],
		index_summary["quests"],
		error_count,
		warning_count,
		info_count,
	]

	_populate_issues(issues)


func _populate_issues(
	issues: Array[NarrativeValidationIssue]
) -> void:
	issues_tree.clear()
	var root := issues_tree.create_item()

	if issues.is_empty():
		var success_item := issues_tree.create_item(root)
		success_item.set_text(0, "OK")
		success_item.set_text(1, "Sen problemas de validación.")
		success_item.set_custom_color(0, Color.LIGHT_GREEN)
		return

	for issue in issues:
		var item := issues_tree.create_item(root)
		item.set_text(0, issue.get_severity_name())
		item.set_text(1, issue.message)
		item.set_tooltip_text(1, issue.resource_path)
		item.set_metadata(0, issue.resource_path)

		match issue.severity:
			NarrativeValidationIssue.Severity.ERROR:
				item.set_custom_color(0, Color.INDIAN_RED)
			NarrativeValidationIssue.Severity.WARNING:
				item.set_custom_color(0, Color.GOLD)
			NarrativeValidationIssue.Severity.INFO:
				item.set_custom_color(0, Color.LIGHT_BLUE)


func _on_issue_activated() -> void:
	var selected_item := issues_tree.get_selected()

	if selected_item == null:
		return

	var resource_path := str(selected_item.get_metadata(0))

	if resource_path.is_empty():
		return

	resource_open_requested.emit(resource_path)


func _toggle_conversation_panel() -> void:
	var should_open := not conversation_scroll.visible

	conversation_scroll.visible = should_open
	quest_scroll.visible = false

	if should_open:
		conversation_panel.refresh_profiles()


func _on_conversation_created(resource_path: String) -> void:
	resource_created.emit(resource_path)
	_validate_project()


func _toggle_quest_panel() -> void:
	var should_open := not quest_scroll.visible

	quest_scroll.visible = should_open
	conversation_scroll.visible = false

	if should_open:
		quest_panel.refresh_catalogs()


func _on_quest_created(resource_path: String) -> void:
	resource_created.emit(resource_path)
	_validate_project()