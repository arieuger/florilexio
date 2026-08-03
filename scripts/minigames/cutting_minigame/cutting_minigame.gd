extends BaseMinigame
class_name CuttingMinigame

signal completed(plant_id: StringName)
signal failed(plant_id: StringName)

const DIRECTION_CHANGE_INTERVAL := 3.0

var plant_id: StringName
var plant_display_name: String
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
@onready var cut_animation: AnimatedSprite2D = $GameRoot/CursorPivot/CutAnimation
@onready var success_zones: Sprite2D = $GameRoot/SuccessZones
@onready var feedback_label: Label = $FeedbackLabel
@onready var status_panel = $UIContainer

var _current_angle := 0.0
var _rotation_direction := 1.0
var _direction_change_elapsed := 0.0
var _hits := 0
var _misses := 0
var _feedback_tween: Tween
var _success_zones_image: Image
var movingGrassSound : FmodEvent

func _ready() -> void:
	add_to_group("cutting_minigame")
	get_viewport().size_changed.connect(_center_game)
	_center_game()
	cursor.position = Vector2(cursor_radius, 0.0)
	_setup_cut_animation()
	feedback_label.text = ""
	_cache_success_zones_image()
	status_panel.setup(required_hits, max_misses, time_cost_blocks, miss_time_cost_blocks)
	movingGrassSound = SoundManager.play_looped_sound('Minigame/Moving Grass')


func _process(delta: float) -> void:
	if is_finished:
		return

	_update_rotation_direction(delta)
	_current_angle = fposmod(_current_angle + rotation_speed_degrees * _rotation_direction * delta, 360.0)
	cursor_pivot.rotation_degrees = _current_angle
	cursor.rotation_degrees = -_current_angle


func setup(new_context: MinigameContext) -> void:
	super.setup(new_context)
	if not context:
		return

	plant_id = context.target_id
	plant_display_name = context.display_name
	required_hits = context.required_hits
	max_misses = context.max_misses
	time_cost_blocks = float(context.get_parameter(&"time_cost_blocks", time_cost_blocks))
	miss_time_cost_blocks = float(context.get_parameter(&"miss_time_cost_blocks", miss_time_cost_blocks))
	rotation_speed_degrees = float(context.get_parameter(&"rotation_speed_degrees", rotation_speed_degrees))
	direction_change_chance = float(context.get_parameter(&"direction_change_chance", direction_change_chance))
	success_alpha_threshold = float(context.get_parameter(&"success_alpha_threshold", success_alpha_threshold))


func _input(event: InputEvent) -> void:
	
	if is_finished:
		return

	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()
		return

	var wants_cut := event.is_action_pressed("ui_accept") or event.is_action_pressed("cut")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		wants_cut = true

	if wants_cut:
		get_viewport().set_input_as_handled()
		_try_cut()


func _try_cut() -> void:
	var hit_pixel := _get_success_zone_pixel_at_cursor()
	if _is_success_zone_pixel(hit_pixel):
		_play_cut_animation_at_cursor()
		_consume_success_zone_at(hit_pixel)
		_hits += 1
		_show_feedback("%s %d/%d" % [tr("Ben!"), _hits, required_hits], Color(0.6, 1.0, 0.6, 1.0), Color('#6f8f6f'))
		_pulse_success_zones()
		status_panel.set_hits(_hits)
		SoundManager.play_simple_sound("Minigame/Cutting Grass")
		if _hits >= required_hits:
			_finish(true)

	else:
		_misses += 1
		request_time_cost(miss_time_cost_blocks)
		_show_feedback("%s %d/%d" % [tr("Fallaches"), _misses, max_misses], Color(1.0, 0.45, 0.45, 1.0), Color('#db5968'))
		_shake_ring()
		status_panel.set_misses(_misses)
		SoundManager.play_simple_sound('Actions/Error')
		if _misses >= max_misses:
			_finish(false)
	


func cancel() -> void:
	if is_finished:
		return

	SoundManager.stop_looped_sound(movingGrassSound)
	emit_finished(_build_cancelled_result())
	queue_free()


func _update_rotation_direction(delta: float) -> void:
	if direction_change_chance <= 0.0:
		return

	_direction_change_elapsed += delta
	if _direction_change_elapsed < DIRECTION_CHANGE_INTERVAL:
		return

	_direction_change_elapsed = 0.0
	if randf() <= direction_change_chance:
		_rotation_direction *= -1.0


func _is_success_zone_pixel(pixel_position: Vector2i) -> bool:
	if not _success_zones_image:
		return false

	var image_size := _success_zones_image.get_size()
	if pixel_position.x < 0 or pixel_position.y < 0 or pixel_position.x >= image_size.x or pixel_position.y >= image_size.y:
		return false

	return _success_zones_image.get_pixelv(pixel_position).a >= success_alpha_threshold

func _consume_success_zone_at(start_pixel: Vector2i) -> void:
	if not _is_success_zone_pixel(start_pixel):
		return

	var image_size := _success_zones_image.get_size()
	var pending: Array[Vector2i] = [start_pixel]
	var visited := {}

	while not pending.is_empty():
		var pixel := pending.pop_back() as Vector2i
		if visited.has(pixel): continue
		visited[pixel] = true

		if pixel.x < 0 or pixel.y < 0 or pixel.x >= image_size.x or pixel.y >= image_size.y: continue
		if _success_zones_image.get_pixelv(pixel).a < success_alpha_threshold: continue

		_success_zones_image.set_pixelv(pixel, Color(0, 0, 0, 0))

		pending.append(pixel + Vector2i(1, 0))
		pending.append(pixel + Vector2i(-1, 0))
		pending.append(pixel + Vector2i(0, 1))
		pending.append(pixel + Vector2i(0, -1))

	_update_success_zones_texture()



func _get_success_zone_pixel_at_cursor() -> Vector2i:
	var local_position := success_zones.to_local(cursor.global_position)
	var texture_size := success_zones.texture.get_size()

	if success_zones.centered:
		local_position += texture_size * 0.5

	local_position -= success_zones.offset
	return Vector2i(floori(local_position.x), floori(local_position.y))


func _cache_success_zones_image() -> void:
	if success_zones.texture:
		_success_zones_image = success_zones.texture.get_image().duplicate()
		_update_success_zones_texture()

func _update_success_zones_texture() -> void:
	success_zones.texture = ImageTexture.create_from_image(_success_zones_image)


func _finish(was_successful: bool) -> void:
	if is_finished:
		return

	SoundManager.stop_looped_sound(movingGrassSound)
	var result := _build_result(was_successful)

	if was_successful:
		completed.emit(plant_id)
		SoundManager.play_simple_sound('Actions/Success')
	else:
		failed.emit(plant_id)

	emit_finished(result)

	await get_tree().create_timer(0.75).timeout
	queue_free()


func _build_result(was_successful: bool) -> MinigameResult:
	var result: MinigameResult
	var minigame_id := _get_minigame_id()
	var rewards := _get_result_rewards()
	var metadata := _get_result_metadata()

	if was_successful:
		result = MinigameResult.success_result(minigame_id, plant_id, rewards, metadata)
	else:
		result = MinigameResult.failed_result(minigame_id, plant_id, rewards, metadata)

	result.hits = _hits
	result.misses = _misses
	result.time_cost_blocks = time_cost_blocks
	result.miss_time_cost_blocks = miss_time_cost_blocks
	return result


func _build_cancelled_result() -> MinigameResult:
	var result := MinigameResult.cancelled_result(
		_get_minigame_id(),
		plant_id,
		_get_result_rewards(),
		_get_result_metadata()
	)
	result.hits = _hits
	result.misses = _misses
	return result


func _get_minigame_id() -> StringName:
	if context:
		var context_minigame_id := context.get_minigame_id()
		if context_minigame_id != &"":
			return context_minigame_id

	return &"cutting"


func _get_result_rewards() -> Dictionary:
	if context:
		return context.rewards.duplicate(true)

	return {
		&"plant_id": plant_id,
		&"amount": 1,
		&"display_name": plant_display_name,
	}


func _get_result_metadata() -> Dictionary:
	if context:
		return context.metadata.duplicate(true)

	return {}


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


func _setup_cut_animation() -> void:
	cut_animation.visible = false
	cut_animation.top_level = true
	if not cut_animation.animation_finished.is_connected(_on_cut_animation_finished):
		cut_animation.animation_finished.connect(_on_cut_animation_finished)


func _play_cut_animation_at_cursor() -> void:
	cut_animation.stop()
	cut_animation.global_position = cursor.global_position
	cut_animation.global_rotation = 0.0
	cut_animation.visible = true
	cut_animation.frame = 0
	cut_animation.frame_progress = 0.0
	cut_animation.play()


func _on_cut_animation_finished() -> void:
	cut_animation.visible = false
