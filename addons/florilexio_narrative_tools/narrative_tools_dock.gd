@tool
extends VBoxContainer

signal resource_open_requested(resource_path: String)
signal resource_created(resource_path: String)
signal documentation_generated(paths: PackedStringArray)

const ConversationCreatorPanel := preload("res://addons/florilexio_narrative_tools/conversation_creator_panel.gd")
const QuestCreatorPanel := preload("res://addons/florilexio_narrative_tools/quest_creator_panel.gd")
const NarrativeUsedByPanel := preload("res://addons/florilexio_narrative_tools/narrative_used_by_panel.gd")
const NarrativeCommandGeneratorPanel := preload(
	"res://addons/florilexio_narrative_tools/narrative_command_generator_panel.gd"
)

var conversation_scroll: ScrollContainer
var conversation_panel: Control
var summary_label: Label
var issues_tree: Tree

var quest_scroll: ScrollContainer
var quest_panel: Control

var used_by_scroll: ScrollContainer
var used_by_panel: Control

var command_generator_scroll: ScrollContainer
var command_generator_panel: Control

func _ready() -> void:
	var title := Label.new()
	title.text = "Florilexio - Ferramentas narrativas"
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)

	var create_conversation_button := Button.new()
	create_conversation_button.text = "Crear conversa"
	create_conversation_button.pressed.connect(_toggle_conversation_panel)
	add_child(create_conversation_button)

	var create_quest_button := Button.new()
	create_quest_button.text = "Crear quest"
	create_quest_button.pressed.connect(
		_toggle_quest_panel
	)
	add_child(create_quest_button)

	var used_by_button := Button.new()
	used_by_button.text = "Usado por"
	used_by_button.pressed.connect(_toggle_used_by_panel)
	add_child(used_by_button)

	var command_generator_button := Button.new()
	command_generator_button.text = "Xerar comando .dialogue"
	command_generator_button.pressed.connect(_toggle_command_generator_panel)
	add_child(command_generator_button)

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
	quest_scroll.custom_minimum_size.y = 560
	quest_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(quest_scroll)

	quest_panel = QuestCreatorPanel.new()
	quest_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_panel.quest_created.connect(_on_quest_created)
	quest_scroll.add_child(quest_panel)

	used_by_scroll = ScrollContainer.new()
	used_by_scroll.visible = false
	used_by_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	used_by_scroll.custom_minimum_size.y = 420
	used_by_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(used_by_scroll)

	used_by_panel = NarrativeUsedByPanel.new()
	used_by_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	used_by_panel.resource_open_requested.connect(_on_used_by_resource_open_requested)
	used_by_scroll.add_child(used_by_panel)

	command_generator_scroll = ScrollContainer.new()
	command_generator_scroll.visible = false
	command_generator_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	command_generator_scroll.custom_minimum_size.y = 420
	command_generator_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(command_generator_scroll)

	command_generator_panel = NarrativeCommandGeneratorPanel.new()
	command_generator_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	command_generator_scroll.add_child(command_generator_panel)

	var validate_button := Button.new()
	validate_button.text = "Validar proxecto"
	validate_button.pressed.connect(_validate_project)
	add_child(validate_button)

	var documentation_button := Button.new()
	documentation_button.text = "Xerar documentación"
	documentation_button.pressed.connect(_generate_documentation)
	add_child(documentation_button)

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
	used_by_scroll.visible = false
	command_generator_scroll.visible = false

	if should_open:
		conversation_panel.refresh_profiles()


func _on_conversation_created(resource_path: String) -> void:
	resource_created.emit(resource_path)
	_validate_project()


func _toggle_quest_panel() -> void:
	var should_open := not quest_scroll.visible

	quest_scroll.visible = should_open
	conversation_scroll.visible = false
	used_by_scroll.visible = false
	command_generator_scroll.visible = false

	if should_open:
		quest_panel.refresh_catalogs()


func _toggle_used_by_panel() -> void:
	var should_open := not used_by_scroll.visible

	conversation_scroll.visible = false
	quest_scroll.visible = false
	used_by_scroll.visible = should_open
	command_generator_scroll.visible = false

	if should_open:
		used_by_panel.refresh()


func _toggle_command_generator_panel() -> void:
	var should_open := not command_generator_scroll.visible

	conversation_scroll.visible = false
	quest_scroll.visible = false
	used_by_scroll.visible = false
	command_generator_scroll.visible = should_open

	if should_open:
		command_generator_panel.refresh()


func _on_quest_created(resource_path: String) -> void:
	resource_created.emit(resource_path)
	_validate_project()


func _generate_documentation() -> void:
	var index := NarrativeIndex.build()
	var issues := NarrativeValidator.new().validate_project(index)
	var result := NarrativeDocumentationGenerator.new().generate(index, issues)

	if not result.success:
		summary_label.text = "Erro xerando documentación:\n%s" % result.error_message
		return

	summary_label.text = "Documentación xerada:\n%s" % "\n".join(result.generated_paths)
	documentation_generated.emit(result.generated_paths)


func _on_used_by_resource_open_requested(
	resource_path: String
) -> void:
	resource_open_requested.emit(resource_path)
