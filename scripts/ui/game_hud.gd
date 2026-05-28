extends CanvasLayer

const TIME_LABEL_DEFAULT_COLOR := Color('#d3ffce')
const TIME_LABEL_WARNING_COLOR := Color(0.85, 0.08, 0.06, 1)

@export var final_composition_scene: PackedScene = preload("res://ui/final_composition/final_composition_panel.tscn")

@onready var inventory_button: TextureButton = $InventoryButton
@onready var time_label: Label = $TimeLabel
@onready var inventory_panel: Control = $InventoryPanel

var _time_shake_tween: Tween
var _time_blink_tween: Tween
var _time_label_base_position: Vector2
var _final_sequence_started := false
var _final_composition_panel: FinalCompositionPanel


func _ready() -> void:
	_time_label_base_position = time_label.position
	_set_inventory_open(false)
	_update_time_label(GameState.consumed_time)
	GameState.consumed_time_added.connect(_on_consumed_time_added)
	inventory_button.pressed.connect(_toggle_inventory)
	inventory_button.pressed.connect(_on_inventory_button_pressed)
	inventory_button.mouse_entered.connect(_on_inventory_button_mouse_entered)
	if inventory_panel.has_signal(&"close_requested"):
		inventory_panel.connect(&"close_requested", _hide_inventory)


func _toggle_inventory() -> void:
	_set_inventory_open(not inventory_panel.visible)


func _hide_inventory() -> void:
	_set_inventory_open(false)


func _on_inventory_button_pressed() -> void:
	SoundManager.play_simple_sound("Actions/Click")


func _on_inventory_button_mouse_entered() -> void:
	SoundManager.play_simple_sound("Actions/Hover")


func _set_inventory_open(is_open: bool) -> void:
	inventory_panel.visible = is_open
	inventory_button.visible = not is_open


func _update_time_label(_total_consumed_time: int) -> void:
	time_label.text = GameState.get_current_time_text()


func _on_consumed_time_added(total_consumed_time: int) -> void:
	_update_time_label(total_consumed_time)
	_play_time_feedback()
	if total_consumed_time >= GameState.TOTAL_BLOCKS and not _final_sequence_started:
		_final_sequence_started = true
		_launch_final_sequence.call_deferred()


func _play_time_feedback() -> void:
	if _time_shake_tween:
		_time_shake_tween.kill()
	if _time_blink_tween:
		_time_blink_tween.kill()

	time_label.position = _time_label_base_position
	time_label.add_theme_color_override("font_color", TIME_LABEL_DEFAULT_COLOR)

	_time_shake_tween = create_tween()
	_time_shake_tween.tween_property(time_label, "position", _time_label_base_position + Vector2(2, 0), 0.04)
	_time_shake_tween.tween_property(time_label, "position", _time_label_base_position + Vector2(-2, 0), 0.04)
	_time_shake_tween.tween_property(time_label, "position", _time_label_base_position, 0.04)

	_time_blink_tween = create_tween()
	for blink_index in range(3):
		_time_blink_tween.tween_method(_set_time_label_color, TIME_LABEL_DEFAULT_COLOR, TIME_LABEL_WARNING_COLOR, 0.12)
		_time_blink_tween.tween_interval(0.12)
		_time_blink_tween.tween_method(_set_time_label_color, TIME_LABEL_WARNING_COLOR, TIME_LABEL_DEFAULT_COLOR, 0.18)
		if blink_index < 2:
			_time_blink_tween.tween_interval(0.42)


func _set_time_label_color(color: Color) -> void:
	time_label.add_theme_color_override("font_color", color)


func _launch_final_sequence() -> void:
	_set_inventory_open(false)
	inventory_button.visible = false

	await get_tree().create_timer(0.45).timeout
	while DialogueBalloonCoordinator.is_running:
		await get_tree().process_frame

	await DialogueBalloonCoordinator.show_info_dialogue_and_wait("final_game_intro")
	_show_final_composition()


func _show_final_composition() -> void:
	if is_instance_valid(_final_composition_panel) or not is_instance_valid(final_composition_scene):
		return

	InventoryManager.clear_bouquet()
	_final_composition_panel = final_composition_scene.instantiate() as FinalCompositionPanel
	if not _final_composition_panel:
		return

	_final_composition_panel.composition_requested.connect(_on_final_composition_requested)
	add_child(_final_composition_panel)


func _on_final_composition_requested() -> void:
	print("TODO: desencadear cálculo final de puntuacións.")
