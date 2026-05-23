extends CanvasLayer
class_name GenericInfoBalloon

@export var auto_close_delay: float = 2.2
@export var fade_duration: float = 0.2

@onready var balloon: Control = %Balloon
@onready var message_label: Label = %MessageLabel

var _close_tween: Tween
var _is_closing := false
var _pending_message := ""
var _pending_duration := -1.0
var _is_ready := false


func _ready() -> void:
	_is_ready = true
	balloon.modulate.a = 0.0
	if not balloon.gui_input.is_connected(_on_balloon_gui_input):
		balloon.gui_input.connect(_on_balloon_gui_input)

	if not _pending_message.is_empty():
		_show_message_now(_pending_message, _pending_duration)


func show_message(message: String, duration: float = -1.0) -> void:
	_pending_message = message
	_pending_duration = duration

	if not _is_ready:
		return

	_show_message_now(message, duration)


func _show_message_now(message: String, duration: float) -> void:
	if _close_tween:
		_close_tween.kill()

	_is_closing = false
	message_label.text = message
	balloon.show()
	balloon.modulate.a = 0.0

	var show_tween := create_tween()
	show_tween.tween_property(balloon, "modulate:a", 1.0, fade_duration)

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

	var tween := create_tween()
	tween.tween_property(balloon, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(queue_free)


func _on_balloon_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		close()
