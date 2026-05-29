extends Control

const GAME_SCENE_PATH := "res://main.tscn"
const DEFAULT_LOCALE := "gl"
const GALICIAN_LOCALE := "gl"
const ENGLISH_LOCALE := "en"

@onready var play_button: Button = %PlayButton
@onready var exit_button: Button = %ExitButton
@onready var toggle_lang: TextureRect = %ToggleLang

var _selected_locale := DEFAULT_LOCALE


func _ready() -> void:
	_set_locale(DEFAULT_LOCALE)
	_apply_texts()
	play_button.pressed.connect(_on_play_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)
	toggle_lang.gui_input.connect(_on_toggle_lang_gui_input)
	play_button.grab_focus()


func _set_locale(locale: String) -> void:
	_selected_locale = locale
	GameState.preferred_locale = _selected_locale
	TranslationServer.set_locale(_selected_locale)
	_update_toggle_state()


func _apply_texts() -> void:
	play_button.text = "Xogar" if _selected_locale == GALICIAN_LOCALE else "Play"


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
	_apply_texts()


func _on_play_button_pressed() -> void:
	GameState.preferred_locale = _selected_locale
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_exit_button_pressed() -> void:
	get_tree().quit()
