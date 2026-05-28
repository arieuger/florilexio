extends CanvasLayer
class_name GenericInfoBalloon

signal closed
signal clicked

@export var auto_close_delay: float = 2.2
@export var fade_duration: float = 0.2
@export var next_action: StringName = &"ui_accept"

@onready var balloon: Control = %Balloon
@onready var message_label: Label = %MessageLabel

var dialogue_resource: DialogueResource
var temporary_game_states: Array = []
var is_waiting_for_input := false
var replacements: Dictionary = {}

var _close_tween: Tween
var _is_closing := false
var _pending_message := ""
var _pending_duration := -1.0
var _is_ready := false
var _click_to_close := false
var _close_on_click := true
var _is_dialogue_running := false

var dialogue_line: DialogueLine:
	set(value):
		dialogue_line = value
		if is_instance_valid(dialogue_line):
			_apply_dialogue_line()
		else:
			_is_dialogue_running = false
			close()
	get:
		return dialogue_line


func _ready() -> void:
	_is_ready = true
	balloon.modulate.a = 0.0
	if not balloon.gui_input.is_connected(_on_balloon_gui_input):
		balloon.gui_input.connect(_on_balloon_gui_input)

	if not _pending_message.is_empty():
		_show_message_now(_pending_message, _pending_duration, _close_on_click)


func start(with_dialogue_resource: DialogueResource = null, title: String = "", extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states
	if is_instance_valid(with_dialogue_resource):
		dialogue_resource = with_dialogue_resource
	_is_dialogue_running = true
	is_waiting_for_input = false
	dialogue_line = await dialogue_resource.get_next_dialogue_line(title, temporary_game_states)


func show_message(message: String, duration: float = -1.0, close_on_click: bool = true) -> void:
	_pending_message = message
	_pending_duration = duration
	_close_on_click = close_on_click

	if not _is_ready:
		return

	_show_message_now(message, duration, close_on_click)


func _show_message_now(message: String, duration: float, close_on_click: bool = true) -> void:
	if _close_tween:
		_close_tween.kill()

	_is_closing = false
	_click_to_close = duration == 0.0
	_close_on_click = close_on_click
	message_label.text = message
	balloon.show()
	balloon.modulate.a = 0.0

	var show_tween := create_tween()
	show_tween.tween_property(balloon, "modulate:a", 1.0, fade_duration)

	if duration == 0.0:
		return

	var close_delay := auto_close_delay if duration < 0.0 else duration
	_close_tween = create_tween()
	_close_tween.tween_interval(close_delay)
	_close_tween.tween_callback(close)


func close() -> void:
	if _is_closing:
		return

	_is_closing = true
	if _close_tween:
		_close_tween.kill()
	_click_to_close = false

	var tween := create_tween()
	tween.tween_property(balloon, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(_emit_closed)
	tween.tween_callback(queue_free)


func _on_balloon_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_handle_click()


func _unhandled_input(event: InputEvent) -> void:
	if _is_dialogue_running and event.is_action_pressed(next_action):
		get_viewport().set_input_as_handled()
		_advance_dialogue()
		return

	if not _click_to_close:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_handle_click()


func _emit_closed() -> void:
	closed.emit()


func _handle_click() -> void:
	if _is_dialogue_running:
		_advance_dialogue()
		return

	if _close_on_click:
		close()
	else:
		clicked.emit()


func _apply_dialogue_line() -> void:
	is_waiting_for_input = true
	show_message(_apply_replacements(dialogue_line.text), 0.0, false)


func _advance_dialogue() -> void:
	if not is_waiting_for_input or not is_instance_valid(dialogue_line):
		return

	is_waiting_for_input = false
	dialogue_line = await dialogue_resource.get_next_dialogue_line(dialogue_line.next_id, temporary_game_states)


func _apply_replacements(message: String) -> String:
	var resolved_message := message
	for key in replacements.keys():
		resolved_message = resolved_message.replace("{" + str(key) + "}", str(replacements[key]))
	return resolved_message
