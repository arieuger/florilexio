@tool
extends VBoxContainer

signal conversation_created(resource_path: String)

const ConditionEditor := preload("res://addons/florilexio_narrative_tools/conversation_condition_editor.gd")

var feedback_label: Label
var character_field: LineEdit
var arc_field: LineEdit
var purpose_field: LineEdit
var conversation_id_field: LineEdit
var dialogue_path_field: LineEdit
var dialogue_file_dialog: FileDialog
var dialogue_resource: DialogueResource
var start_title_field: LineEdit
var speaker_id_field: LineEdit
var priority_field: SpinBox
var repeatable_check: CheckBox
var fallback_check: CheckBox
var profile_selector: OptionButton
var save_path_field: LineEdit
var create_button: Button
var save_directory_dialog: FileDialog
var save_directory: String
var conditions_container: VBoxContainer
var condition_group_mode_selector: OptionButton
var condition_editors: Array[ConditionEditor] = []


func _ready() -> void:
	var heading := Label.new()
	heading.text = "Crear conversa"
	heading.add_theme_font_size_override("font_size", 14)
	add_child(heading)

	character_field = _add_line_field("Personaxe/NPC")
	arc_field = _add_line_field("Arco narrativo")
	purpose_field = _add_line_field("Propósito")
	conversation_id_field = _add_line_field("Conversation ID")

	character_field.text_changed.connect(_update_suggested_id)
	arc_field.text_changed.connect(_update_suggested_id)
	purpose_field.text_changed.connect(_update_suggested_id)

	_add_label("Arquivo .dialogue")
	var dialogue_row := HBoxContainer.new()
	add_child(dialogue_row)

	dialogue_path_field = LineEdit.new()
	dialogue_path_field.placeholder_text = "Selecciona un .dialogue"
	dialogue_path_field.editable = false
	dialogue_path_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_row.add_child(dialogue_path_field)

	var browse_dialogue_button := Button.new()
	browse_dialogue_button.text = "Seleccionar"
	browse_dialogue_button.pressed.connect(_open_dialogue_file_dialog)
	dialogue_row.add_child(browse_dialogue_button)

	dialogue_file_dialog = FileDialog.new()
	dialogue_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialogue_file_dialog.access = FileDialog.ACCESS_RESOURCES
	dialogue_file_dialog.filters = PackedStringArray(["*.dialogue ; Dialogue Manager files", ])
	dialogue_file_dialog.current_dir = "res://dialogues"
	dialogue_file_dialog.file_selected.connect(_on_dialogue_file_selected)
	add_child(dialogue_file_dialog)

	start_title_field = _add_line_field("Start title", "start")
	speaker_id_field = _add_line_field("Initial speaker ID")

	_add_label("Prioridade")
	priority_field = SpinBox.new()
	priority_field.min_value = -10000
	priority_field.max_value = 10000
	priority_field.step = 1
	add_child(priority_field)

	repeatable_check = CheckBox.new()
	repeatable_check.text = "Repetible"
	add_child(repeatable_check)

	fallback_check = CheckBox.new()
	fallback_check.text = "Fallback"
	add_child(fallback_check)

	var conditions_heading := Label.new()
	conditions_heading.text = "Condicións"
	conditions_heading.add_theme_font_size_override("font_size", 13)
	add_child(conditions_heading)

	_add_label("Modo do grupo raíz")
	# TODO: Facer recursiva a selección de grupo ou condición
	condition_group_mode_selector = OptionButton.new()
	for mode in ConditionGroup.Mode.values():
		condition_group_mode_selector.add_item(
			ConditionGroup.Mode.keys()[mode]
		)
		condition_group_mode_selector.set_item_metadata(
			condition_group_mode_selector.item_count - 1,
			mode
		)
	add_child(condition_group_mode_selector)

	conditions_container = VBoxContainer.new()
	add_child(conditions_container)

	var add_condition_button := Button.new()
	add_condition_button.text = "Engadir condición"
	add_condition_button.pressed.connect(_add_condition)
	add_child(add_condition_button)

	_add_label("DialogueProfile destino")
	profile_selector = OptionButton.new()
	profile_selector.item_selected.connect(
		_on_profile_selected
	)
	add_child(profile_selector)

	_add_label("Carpeta de gardado")
	var save_directory_row := HBoxContainer.new()
	add_child(save_directory_row)

	save_path_field = LineEdit.new()
	save_path_field.placeholder_text = "Selecciona unha carpeta"
	save_path_field.editable = false
	save_path_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_directory_row.add_child(save_path_field)

	var browse_directory_button := Button.new()
	browse_directory_button.text = "Seleccionar"
	browse_directory_button.pressed.connect(_open_save_directory_dialog)
	save_directory_row.add_child(browse_directory_button)

	save_directory_dialog = FileDialog.new()
	save_directory_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	save_directory_dialog.access = FileDialog.ACCESS_RESOURCES
	save_directory_dialog.current_dir = "res://resources/dialogues"
	save_directory_dialog.dir_selected.connect(_on_save_directory_selected)
	add_child(save_directory_dialog)

	conversation_id_field.text_changed.connect(_on_conversation_id_changed)

	create_button = Button.new()
	create_button.text = "Crear conversa"
	create_button.pressed.connect(_create_conversation)
	add_child(create_button)

	feedback_label = Label.new()
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(feedback_label)

	refresh_profiles()


func refresh_profiles() -> void:
	profile_selector.clear()
	profile_selector.add_item("Selecciona un perfil")
	profile_selector.set_item_metadata(0, "")

	var index := NarrativeIndex.build()
	var profile_records := index.profiles.duplicate()

	profile_records.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			return str(first["id"]) < str(second["id"])
	)

	for record in profile_records:
		var item_index := profile_selector.item_count
		var profile_id := str(record.get("id", ""))
		var path := str(record.get("path", ""))

		profile_selector.add_item(profile_id)
		profile_selector.set_item_metadata(item_index, path)


func _update_suggested_id(_new_text: String) -> void:
	conversation_id_field.text = str(
		NarrativeResourceFactory.build_conversation_id(character_field.text, arc_field.text, purpose_field.text)
	)


func _add_line_field(label_text: String, default_value: String = "") -> LineEdit:
	_add_label(label_text)

	var field := LineEdit.new()
	field.text = default_value
	add_child(field)
	return field


func _add_label(label_text: String) -> void:
	var label := Label.new()
	label.text = label_text
	add_child(label)


func _open_dialogue_file_dialog() -> void:
	dialogue_file_dialog.popup_centered_ratio(0.8)


func _on_dialogue_file_selected(path: String) -> void:
	var loaded_resource := ResourceLoader.load(path)

	if loaded_resource is not DialogueResource:
		dialogue_resource = null
		dialogue_path_field.text = ""
		push_warning(
			"Selected file is not a valid DialogueResource: %s"
			% path
		)
		return

	dialogue_resource = loaded_resource as DialogueResource
	dialogue_path_field.text = path


func _open_save_directory_dialog() -> void:
	if not save_directory.is_empty():
		save_directory_dialog.current_dir = save_directory
	elif profile_selector.selected > 0:
		var profile_path := str(
			profile_selector.get_selected_metadata()
		)

		if not profile_path.is_empty():
			save_directory_dialog.current_dir = (
				profile_path.get_base_dir()
			)

	save_directory_dialog.popup_centered_ratio(0.8)


func _on_save_directory_selected(path: String) -> void:
	save_directory = path
	_update_suggested_save_path()


func _on_conversation_id_changed(_new_id: String) -> void:
	_update_suggested_save_path()


func _update_suggested_save_path() -> void:
	var conversation_id := str(
		NarrativeResourceFactory.normalize_id(
			conversation_id_field.text
		)
	)

	if save_directory.is_empty() or conversation_id.is_empty():
		save_path_field.text = ""
		return

	save_path_field.text = save_directory.path_join(
		"%s.tres" % conversation_id
	)

func _on_profile_selected(index: int) -> void:
	if index <= 0:
		save_directory_dialog.current_dir = (
			"res://resources/dialogues"
		)
		return

	var profile_path := str(
		profile_selector.get_item_metadata(index)
	)

	if profile_path.is_empty():
		return

	save_directory_dialog.current_dir = (
		profile_path.get_base_dir()
	)


func _create_conversation() -> void:
	_set_feedback("", Color.WHITE)

	var request := _build_creation_request()
	var index := NarrativeIndex.build()

	create_button.disabled = true

	var result := NarrativeResourceFactory.create_conversation(request, index)

	create_button.disabled = false

	if not result.success:
		_set_feedback(result.error_message, Color.INDIAN_RED)
		return

	_set_feedback("Conversa creada correctamente:\n%s" % result.resource_path, Color.LIGHT_GREEN)

	conversation_created.emit(result.resource_path)
	_reset_after_successful_creation()


func _build_creation_request() -> ConversationCreationRequest:
	var request := ConversationCreationRequest.new()

	request.conversation_id = NarrativeResourceFactory.normalize_id(
		conversation_id_field.text
	)

	request.dialogue_resource = dialogue_resource
	request.start_title = start_title_field.text.strip_edges()
	request.initial_speaker_id = StringName(
		speaker_id_field.text.strip_edges()
	)

	request.priority = int(priority_field.value)
	request.repeatable = repeatable_check.button_pressed
	request.fallback = fallback_check.button_pressed

	if not condition_editors.is_empty():
		var condition_group := ConditionGroup.new()
		condition_group.mode = int(
			condition_group_mode_selector.get_selected_metadata()
		)

		for editor in condition_editors:
			condition_group.conditions.append(
				editor.build_condition()
			)

		request.condition_group = condition_group

	if profile_selector.selected > 0:
		var profile_path := str(
			profile_selector.get_selected_metadata()
		)
		request.target_profile = ResourceLoader.load(
			profile_path
		) as DialogueProfile

	request.save_path = save_path_field.text

	return request


func _set_feedback(message: String, color: Color) -> void:
	feedback_label.text = message
	feedback_label.modulate = color


func _reset_after_successful_creation() -> void:
	purpose_field.clear()
	start_title_field.text = "start"
	priority_field.value = 0
	repeatable_check.button_pressed = false
	fallback_check.button_pressed = false
	condition_group_mode_selector.select(0)
	for editor in condition_editors:
		editor.queue_free()
	condition_editors.clear()

	_update_suggested_id("")
	purpose_field.grab_focus()


func _add_condition() -> void:
	var editor := ConditionEditor.new()
	editor.remove_requested.connect(_remove_condition)
	conditions_container.add_child(editor)
	condition_editors.append(editor)
	_renumber_conditions()


func _remove_condition(editor: Control) -> void:
	if not condition_editors.has(editor):
		return

	condition_editors.erase(editor)
	editor.queue_free()
	_renumber_conditions()


func _renumber_conditions() -> void:
	for index in range(condition_editors.size()):
		condition_editors[index].set_condition_number(
			index + 1
		)
