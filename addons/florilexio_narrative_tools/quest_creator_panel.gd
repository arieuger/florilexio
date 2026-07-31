@tool
extends VBoxContainer

signal quest_created(resource_path: String)

const ObjectiveEditor := preload("res://addons/florilexio_narrative_tools/quest_objective_editor.gd")

var quest_id_field: LineEdit
var catalog_selector: OptionButton
var objectives_container: VBoxContainer
var objective_editors: Array[Control] = []

var save_path_field: LineEdit
var save_directory_dialog: FileDialog
var save_directory: String

var create_button: Button
var feedback_label: Label


func _ready() -> void:
	var heading := Label.new()
	heading.text = "Crear quest"
	heading.add_theme_font_size_override("font_size", 14)
	add_child(heading)

	quest_id_field = _add_line_field("Quest ID")
	quest_id_field.text_changed.connect(_on_quest_id_changed)

	_add_label("Catálogo destino")
	catalog_selector = OptionButton.new()
	catalog_selector.item_selected.connect(_on_catalog_selected)
	add_child(catalog_selector)

	var objectives_heading := Label.new()
	objectives_heading.text = "Obxectivos"
	objectives_heading.add_theme_font_size_override("font_size", 13)
	add_child(objectives_heading)

	objectives_container = VBoxContainer.new()
	add_child(objectives_container)

	var add_objective_button := Button.new()
	add_objective_button.text = "Engadir obxectivo"
	add_objective_button.pressed.connect(_add_objective)
	add_child(add_objective_button)

	_add_label("Carpeta de gardado")

	var save_row := HBoxContainer.new()
	add_child(save_row)

	save_path_field = LineEdit.new()
	save_path_field.editable = false
	save_path_field.placeholder_text = "Selecciona unha carpeta"
	save_path_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(save_path_field)

	var browse_button := Button.new()
	browse_button.text = "Seleccionar"
	browse_button.pressed.connect(_open_save_directory_dialog)
	save_row.add_child(browse_button)

	save_directory_dialog = FileDialog.new()
	save_directory_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	save_directory_dialog.access = FileDialog.ACCESS_RESOURCES
	save_directory_dialog.current_dir = "res://resources/quests"
	save_directory_dialog.dir_selected.connect(_on_save_directory_selected)
	add_child(save_directory_dialog)

	create_button = Button.new()
	create_button.text = "Crear quest"
	create_button.pressed.connect(_create_quest)
	add_child(create_button)

	feedback_label = Label.new()
	feedback_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	add_child(feedback_label)

	refresh_catalogs()
	_add_objective()


func refresh_catalogs() -> void:
	catalog_selector.clear()
	catalog_selector.add_item("Selecciona un catálogo")
	catalog_selector.set_item_metadata(0, "")

	var index := NarrativeIndex.build()
	var records := index.catalogs.duplicate()

	records.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			return str(first["id"]) < str(second["id"])
	)

	for record in records:
		var item_index := catalog_selector.item_count
		catalog_selector.add_item(str(record.get("id", "")))
		catalog_selector.set_item_metadata(item_index, str(record.get("path", "")))


func _add_objective() -> void:
	var editor := ObjectiveEditor.new() as Control
	editor.remove_requested.connect(_remove_objective)
	objectives_container.add_child(editor)
	objective_editors.append(editor)
	_renumber_objectives()


func _remove_objective(editor: Control) -> void:
	if not objective_editors.has(editor):
		return

	objective_editors.erase(editor)
	editor.queue_free()
	_renumber_objectives()


func _renumber_objectives() -> void:
	for index in range(objective_editors.size()):
		objective_editors[index].set_objective_number(index + 1)


func _create_quest() -> void:
	_set_feedback("", Color.WHITE)

	var request := _build_creation_request()
	var index := NarrativeIndex.build()

	create_button.disabled = true
	var result := NarrativeResourceFactory.create_quest(
		request,
		index
	)
	create_button.disabled = false

	if not result.success:
		_set_feedback(
			result.error_message,
			Color.INDIAN_RED
		)
		return

	_set_feedback(
		"Quest creada correctamente:\n%s"
			% result.resource_path,
		Color.LIGHT_GREEN
	)
	quest_created.emit(result.resource_path)
	_reset_after_successful_creation()


func _build_creation_request() -> QuestCreationRequest:
	var request := QuestCreationRequest.new()

	request.quest_id = NarrativeResourceFactory.normalize_id(
		quest_id_field.text
	)

	for editor in objective_editors:
		request.objectives.append(editor.build_definition())

	if catalog_selector.selected > 0:
		var catalog_path := str(
			catalog_selector.get_selected_metadata()
		)
		request.target_catalog = ResourceLoader.load(
			catalog_path
		) as QuestCatalog

	request.save_path = save_path_field.text
	return request


func _reset_after_successful_creation() -> void:
	quest_id_field.clear()

	for editor in objective_editors:
		editor.queue_free()

	objective_editors.clear()
	_add_objective()
	quest_id_field.grab_focus()


func _on_quest_id_changed(_new_id: String) -> void:
	_update_suggested_save_path()


func _on_catalog_selected(index: int) -> void:
	if index <= 0:
		save_directory_dialog.current_dir = "res://resources/quests"
		return

	var catalog_path := str(catalog_selector.get_item_metadata(index))

	if not catalog_path.is_empty():
		save_directory_dialog.current_dir = catalog_path.get_base_dir()


func _open_save_directory_dialog() -> void:
	if not save_directory.is_empty():
		save_directory_dialog.current_dir = save_directory

	save_directory_dialog.popup_centered_ratio(0.8)


func _on_save_directory_selected(path: String) -> void:
	save_directory = path
	_update_suggested_save_path()


func _update_suggested_save_path() -> void:
	var quest_id := str(NarrativeResourceFactory.normalize_id(quest_id_field.text))

	if save_directory.is_empty() or quest_id.is_empty():
		save_path_field.text = ""
		return

	save_path_field.text = save_directory.path_join("%s.tres" % quest_id)


func _set_feedback(message: String, color: Color) -> void:
	feedback_label.text = message
	feedback_label.modulate = color


func _add_line_field(label_text: String) -> LineEdit:
	_add_label(label_text)

	var field := LineEdit.new()
	add_child(field)
	return field


func _add_label(label_text: String) -> void:
	var label := Label.new()
	label.text = label_text
	add_child(label)