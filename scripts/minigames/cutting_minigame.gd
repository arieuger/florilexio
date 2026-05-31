extends CanvasLayer
class_name CuttingMinigame

signal completed(plant_id: StringName)
signal failed(plant_id: StringName)

const DIRECTION_CHANGE_INTERVAL := 3.0

var plant_id: StringName
var plant_display_name: String
var plant_marks: Dictionary = {}
var required_hits: int = 3
var max_misses: int = 3
var rotation_speed_degrees: float = 120.0
var direction_change_chance: float = 0.0
@export var cursor_radius: float = 21.0
var time_cost_blocks: float = 1.0
var miss_time_cost_blocks: float = 0.0
var success_alpha_threshold := 0.1

@onready var game_root: Node2D = $GameRoot
@onready var cursor_pivot: Node2D = $GameRoot/CursorPivot
@onready var cursor: Sprite2D = $GameRoot/CursorPivot/Cursor
@onready var success_zones: Sprite2D = $GameRoot/SuccessZones
@onready var feedback_label: Label = $FeedbackLabel

var _current_angle := 0.0
var _rotation_direction := 1.0
var _direction_change_elapsed := 0.0
var _hits := 0
var _misses := 0
var _is_finished := false
var _feedback_tween: Tween
var _success_zones_image: Image
var movingGrassSound : FmodEvent

func _ready() -> void:
	add_to_group("cutting_minigame")
	get_viewport().size_changed.connect(_center_game)
	_center_game()
	cursor.position = Vector2(cursor_radius, 0.0)
	feedback_label.text = ""
	_cache_success_zones_image()
	movingGrassSound = SoundManager.play_looped_sound('Minigame/Moving Grass')


func _process(delta: float) -> void:
	if _is_finished:
		return

	_update_rotation_direction(delta)
	_current_angle = fposmod(_current_angle + rotation_speed_degrees * _rotation_direction * delta, 360.0)
	cursor_pivot.rotation_degrees = _current_angle
	cursor.rotation_degrees = -_current_angle


func _input(event: InputEvent) -> void:
	
	if _is_finished:
		return

	var wants_cut := event.is_action_pressed("ui_accept") or event.is_action_pressed("cut")
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_X:
		wants_cut = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		wants_cut = true

	if wants_cut:
		get_viewport().set_input_as_handled()
		_try_cut()


func _try_cut() -> void:
	if _is_successful_cut():
		_hits += 1
		_show_feedback("%s %d/%d" % [tr("Ben!"), _hits, required_hits], Color(0.6, 1.0, 0.6, 1.0), Color('#6f8f6f'))
		_pulse_success_zones()
		SoundManager.play_simple_sound("Minigame/Cutting Grass")
		if _hits >= required_hits:
			_finish(true)
	else:
		_misses += 1
		GameState.add_consumed_time(miss_time_cost_blocks)
		_show_feedback("%s %d/%d" % [tr("Fallaches"), _misses, max_misses], Color(1.0, 0.45, 0.45, 1.0), Color('#db5968'))
		_shake_ring()
		SoundManager.play_simple_sound('Actions/Error')
		if _misses >= max_misses:
			_finish(false)


func cancel() -> void:
	if _is_finished:
		return

	_is_finished = true
	SoundManager.stop_looped_sound(movingGrassSound)
	queue_free()


func _is_successful_cut() -> bool:
	return _is_cursor_on_success_zone()


func _update_rotation_direction(delta: float) -> void:
	if direction_change_chance <= 0.0:
		return

	_direction_change_elapsed += delta
	if _direction_change_elapsed < DIRECTION_CHANGE_INTERVAL:
		return

	_direction_change_elapsed = 0.0
	if randf() <= direction_change_chance:
		_rotation_direction *= -1.0


func _is_cursor_on_success_zone() -> bool:
	if not _success_zones_image:
		return false

	var pixel_position := _get_success_zone_pixel_at_cursor()
	var image_size := _success_zones_image.get_size()
	if pixel_position.x < 0 or pixel_position.y < 0 or pixel_position.x >= image_size.x or pixel_position.y >= image_size.y:
		return false

	var pixel_color := _success_zones_image.get_pixelv(pixel_position)
	return pixel_color.a >= success_alpha_threshold


func _get_success_zone_pixel_at_cursor() -> Vector2i:
	var local_position := success_zones.to_local(cursor.global_position)
	var texture_size := success_zones.texture.get_size()

	if success_zones.centered:
		local_position += texture_size * 0.5

	local_position -= success_zones.offset
	return Vector2i(floori(local_position.x), floori(local_position.y))


func _cache_success_zones_image() -> void:
	if success_zones.texture:
		_success_zones_image = success_zones.texture.get_image()


func _finish(was_successful: bool) -> void:
	_is_finished = true
	SoundManager.stop_looped_sound(movingGrassSound)
	GameState.add_consumed_time(time_cost_blocks)

	if was_successful:
		InventoryManager.add_item(plant_id, 1, plant_display_name, plant_marks)
		completed.emit(plant_id)
		SoundManager.play_simple_sound('Actions/Success')
	else:
		failed.emit(plant_id)

	await get_tree().create_timer(0.35).timeout
	queue_free()


func _show_feedback(text: String, color: Color, outline_color) -> void:
	if _feedback_tween:
		_feedback_tween.kill()

	feedback_label.text = text
	feedback_label.modulate = color
	var setting = LabelSettings.new()
	setting.outline_color = outline_color
	setting.outline_size = 1
	feedback_label.label_settings = setting
	_feedback_tween = create_tween()
	_feedback_tween.tween_interval(0.25)
	_feedback_tween.tween_property(feedback_label, "modulate:a", 0.0, 0.25)


func _pulse_success_zones() -> void:
	var tween := create_tween()
	tween.tween_property(success_zones, "scale", Vector2(1.12, 1.12), 0.06)
	tween.tween_property(success_zones, "scale", Vector2.ONE, 0.12)


func _shake_ring() -> void:
	var start_position := game_root.position
	var tween := create_tween()
	tween.tween_property(game_root, "position", start_position + Vector2(2, 0), 0.04)
	tween.tween_property(game_root, "position", start_position + Vector2(-2, 0), 0.04)
	tween.tween_property(game_root, "position", start_position, 0.04)


func _center_game() -> void:
	game_root.position = get_viewport().get_visible_rect().size * 0.5
