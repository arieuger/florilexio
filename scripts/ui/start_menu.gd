extends Control

const GAME_SCENE_PATH := "res://main.tscn"
const DEFAULT_LOCALE := "gl"
const GALICIAN_LOCALE := "gl"
const ENGLISH_LOCALE := "en"

@onready var title_label: Label = %TitleLabel
@onready var play_button: Button = %PlayButton
@onready var exit_button: Button = %ExitButton
@onready var toggle_lang: TextureRect = %ToggleLang
@onready var language_label_gl: Label = %LanguageLabelGl
@onready var language_label_en: Label = %LanguageLabelEn

var _selected_locale := DEFAULT_LOCALE
var _project_translations: Array[Translation] = []


func _ready() -> void:
	_set_manual_text_translation_disabled()
	_set_locale(DEFAULT_LOCALE)
	play_button.pressed.connect(_on_play_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)
	toggle_lang.gui_input.connect(_on_toggle_lang_gui_input)
	play_button.grab_focus()
	call_deferred("_apply_texts")


func _set_manual_text_translation_disabled() -> void:
	title_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	play_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	exit_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	language_label_gl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	language_label_en.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func _set_locale(locale: String) -> void:
	_selected_locale = locale
	GameState.preferred_locale = _selected_locale
	_apply_locale_settings(_selected_locale)
	_update_toggle_state()
	_apply_texts()


func _apply_locale_settings(locale: String) -> void:
	TranslationServer.set_locale(locale)
	if locale == GALICIAN_LOCALE:
		_set_project_translations_enabled(false)
		DialogueManager.translation_source = DMConstants.TranslationSource.None
	else:
		_set_project_translations_enabled(true)
		DialogueManager.translation_source = DMConstants.TranslationSource.Guess


func _set_project_translations_enabled(enabled: bool) -> void:
	_ensure_project_translations_cached()

	for translation in _project_translations:
		# Remove first to avoid duplicate registrations when re-enabling.
		TranslationServer.remove_translation(translation)
		if enabled:
			TranslationServer.add_translation(translation)


func _ensure_project_translations_cached() -> void:
	if not _project_translations.is_empty():
		return

	var translation_files: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray())
	for file_path in translation_files:
		var translation_resource := load(file_path)
		if translation_resource is Translation:
			_project_translations.append(translation_resource)


func _apply_texts() -> void:
	if not is_instance_valid(title_label) or not is_instance_valid(play_button) or not is_instance_valid(exit_button) or not is_instance_valid(language_label_gl) or not is_instance_valid(language_label_en):
		return

	title_label.text = tr("Un pequeno florilexio")
	play_button.text = tr("Xogar")
	exit_button.text = tr("Saír")

	language_label_gl.text = "Galego"
	language_label_en.text = "English"


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_apply_texts()


func _update_toggle_state() -> void:
	if not is_instance_valid(toggle_lang):
		return

	toggle_lang.flip_h = _selected_locale == ENGLISH_LOCALE


func _on_toggle_lang_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if not mouse_event or not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	var next_locale := ENGLISH_LOCALE if _selected_locale == GALICIAN_LOCALE else GALICIAN_LOCALE
	_set_locale(next_locale)


func _on_play_button_pressed() -> void:
	GameState.preferred_locale = _selected_locale
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_exit_button_pressed() -> void:
	get_tree().quit()
