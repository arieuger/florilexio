extends BaseMinigame
class_name BushMinigame

signal completed(plant_id: StringName)
signal failed(plant_id: StringName)

enum ZoneType { NONE, CHARGE, CUT, DANGER }

const ZONE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/minigame/bush/rd-game-zone1.png"),
	preload("res://assets/sprites/minigame/bush/ld-game-zone2.png"),
	preload("res://assets/sprites/minigame/bush/ld-game-zone3.png"),
	preload("res://assets/sprites/minigame/bush/rd-game-zone4.png"),
	preload("res://assets/sprites/minigame/bush/rd-game-zone5.png"),
]
const ZONE_DIRECTIONS := [
	1.0,
	-1.0,
	-1.0,
	1.0,
	1.0,
]
const ZONE_NAMES := [
	"rd-game-zone1",
	"ld-game-zone2",
	"ld-game-zone3",
	"rd-game-zone4",
	"rd-game-zone5",
]

var plant_id: StringName
var plant_display_name: String
var plant_marks: Dictionary = {}
var required_hits: int = 3
var max_misses: int = 3
var rotation_speed_degrees: float = 115.0
@export var cursor_radius: float = 19.0
var time_cost_blocks: float = 1.0
var miss_time_cost_blocks: float = 1.0
var required_charge: float = 3.5
var charge_rate: float = 7.0
var charge_grace_seconds: float = 0.25
var cut_zone_margin_pixels := 1
var zone_alpha_threshold := 0.1

@onready var game_root: Node2D = $GameRoot
@onready var charge_bar_root: Node2D = $ChargeBarRoot
@onready var cursor_pivot: Node2D = $GameRoot/CursorPivot
@onready var cursor: Sprite2D = $GameRoot/CursorPivot/Cursor
@onready var cut_animation: AnimatedSprite2D = $GameRoot/CursorPivot/CutAnimation
@onready var zone_sprite: Sprite2D = $GameRoot/ZoneSprite
@onready var charge_bar: TextureProgressBar = $ChargeBarRoot/ChargeBar
@onready var feedback_label: Label = $FeedbackLabel
@onready var status_panel = $UIContainer

var _current_angle := 0.0
var _rotation_direction := 1.0
var _hits := 0
var _misses := 0
var _charge := 0.0
var _charge_grace_remaining := 0.0
var _is_button_down := false
var _feedback_tween: Tween
var _charge_bar_flash_tween: Tween
var _charge_bar_loss_tween: Tween
var _charge_bar_base_position := Vector2.ZERO
var _zone_image: Image
var _current_zone_index := -1
var _last_logged_charge_step := -1


func _ready() -> void:
	add_to_group("bush_minigame")
	get_viewport().size_changed.connect(_center_game)
	_center_game()
	cursor.position = Vector2(cursor_radius, 0.0)
	_setup_cut_animation()
	_setup_charge_bar()
	feedback_label.text = ""
	status_panel.setup(required_hits, max_misses, time_cost_blocks, miss_time_cost_blocks)
	_load_next_zone_pack()


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
	required_charge = float(context.get_parameter(&"required_charge", required_charge))
	charge_rate = float(context.get_parameter(&"charge_rate", charge_rate))
	charge_grace_seconds = float(context.get_parameter(&"charge_grace_seconds", charge_grace_seconds))
	cut_zone_margin_pixels = int(context.get_parameter(&"cut_zone_margin_pixels", cut_zone_margin_pixels))
	zone_alpha_threshold = float(context.get_parameter(&"zone_alpha_threshold", zone_alpha_threshold))


func _process(delta: float) -> void:
	if is_finished:
		return

	var current_rotation_speed := rotation_speed_degrees
	if _is_button_down and _get_effective_zone_at_cursor() == ZoneType.CHARGE:
		current_rotation_speed /= 1.5

	_current_angle = fposmod(_current_angle + current_rotation_speed * _rotation_direction * delta, 360.0)
	cursor_pivot.rotation_degrees = _current_angle
	cursor.rotation_degrees = -_current_angle
	_update_charge(delta)


func _input(event: InputEvent) -> void:
	if is_finished:
		return

	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()
		return

	if _is_press_event(event):
		get_viewport().set_input_as_handled()
		_is_button_down = true
		return

	if _is_release_event(event):
		get_viewport().set_input_as_handled()
		_is_button_down = false
		_try_release_cut()


func _is_press_event(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("cut"):
		return true
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT


func _is_release_event(event: InputEvent) -> bool:
	if event.is_action_released("ui_accept") or event.is_action_released("cut"):
		return true
	return event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT


func _update_charge(delta: float) -> void:
	if not _is_button_down:
		return

	var zone := _get_effective_zone_at_cursor()
	if zone == ZoneType.DANGER:
		_apply_danger_failure()
		return

	if zone == ZoneType.CHARGE:
		_charge = minf(required_charge, _charge + charge_rate * delta)
		_charge_grace_remaining = charge_grace_seconds
		_update_charge_bar()
		_log_charge()
		return

	if _charge_grace_remaining > 0.0:
		_charge_grace_remaining = maxf(0.0, _charge_grace_remaining - delta)


func _try_release_cut() -> void:
	var zone := _get_effective_zone_at_cursor()
	if zone == ZoneType.CUT and _charge >= required_charge:
		_apply_successful_cut()
		return
	if zone == ZoneType.CUT:
		print("[BushMinigame] Kept charge %.2f after release in cut zone without enough charge" % _charge)
		return
	if zone == ZoneType.CHARGE:
		print("[BushMinigame] Kept charge %.2f after release in charge zone" % _charge)
		return

	if _charge > 0.0:
		print("[BushMinigame] Lost charge %.2f outside cut zone" % _charge)
		_reset_charge(true)
	else:
		_reset_charge()


func _apply_successful_cut() -> void:
	_hits += 1
	print("[BushMinigame] Cut %d/%d with charge %.2f" % [_hits, required_hits, _charge])
	_play_cut_animation_at_cursor()
	_show_feedback("%s %d/%d" % [tr("Ben!"), _hits, required_hits], Color(0.6, 1.0, 0.6, 1.0), Color("#6f8f6f"))
	status_panel.set_hits(_hits)
	SoundManager.play_simple_sound("Minigame/Cutting Grass")
	_reset_charge()

	if _hits >= required_hits:
		_finish(true)
	else:
		_load_next_zone_pack()


func _apply_danger_failure() -> void:
	_misses += 1
	print("[BushMinigame] Danger failure %d/%d" % [_misses, max_misses])
	_is_button_down = false
	_reset_charge(true)
	request_time_cost(miss_time_cost_blocks)
	_show_feedback("%s %d/%d" % [tr("Fallaches"), _misses, max_misses], Color(1.0, 0.45, 0.45, 1.0), Color("#db5968"))
	_shake_ring()
	status_panel.set_misses(_misses)
	SoundManager.play_simple_sound("Actions/Error")

	if _misses >= max_misses:
		_finish(false)


func _reset_charge(show_loss_feedback := false) -> void:
	var lost_charge := _charge
	_charge = 0.0
	_charge_grace_remaining = 0.0
	_last_logged_charge_step = -1
	_stop_charge_bar_flash()
	if show_loss_feedback and lost_charge > 0.0:
		_show_charge_bar_loss_feedback(lost_charge)
	else:
		_update_charge_bar()


func _setup_charge_bar() -> void:
	_charge_bar_base_position = charge_bar.position
	charge_bar.min_value = 0.0
	charge_bar.max_value = required_charge
	charge_bar.step = 0.0
	charge_bar.self_modulate = Color.WHITE
	_update_charge_bar()


func _update_charge_bar() -> void:
	_stop_charge_bar_loss_feedback()
	charge_bar.value = clampf(_charge, 0.0, required_charge)
	if _charge >= required_charge:
		_start_charge_bar_flash()
	else:
		_stop_charge_bar_flash()


func _start_charge_bar_flash() -> void:
	if _charge_bar_flash_tween:
		return

	_charge_bar_flash_tween = create_tween().set_loops()
	_charge_bar_flash_tween.tween_property(charge_bar, "self_modulate", Color(2.2, 2.2, 2.2, 1.0), 0.8)
	_charge_bar_flash_tween.tween_property(charge_bar, "self_modulate", Color.WHITE, 0.8)


func _stop_charge_bar_flash() -> void:
	if _charge_bar_flash_tween:
		_charge_bar_flash_tween.kill()
		_charge_bar_flash_tween = null
	charge_bar.self_modulate = Color.WHITE


func _show_charge_bar_loss_feedback(lost_charge: float) -> void:
	_stop_charge_bar_loss_feedback(false)

	var time_cost_color := Color(0.69803923, 0.36078432, 0.2, 1.0)
	charge_bar.value = clampf(lost_charge, 0.0, required_charge)
	charge_bar.self_modulate = time_cost_color
	_charge_bar_loss_tween = create_tween()
	_charge_bar_loss_tween.tween_property(charge_bar, "position", _charge_bar_base_position + Vector2(1.5, 0), 0.035)
	_charge_bar_loss_tween.tween_property(charge_bar, "position", _charge_bar_base_position + Vector2(-1.5, 0), 0.035)
	_charge_bar_loss_tween.tween_property(charge_bar, "position", _charge_bar_base_position + Vector2(1.0, 0), 0.03)
	_charge_bar_loss_tween.tween_property(charge_bar, "position", _charge_bar_base_position, 0.04)
	_charge_bar_loss_tween.tween_interval(0.2)
	_charge_bar_loss_tween.tween_property(charge_bar, "value", 0.0, 0.16)
	_charge_bar_loss_tween.parallel().tween_property(charge_bar, "self_modulate", Color.WHITE, 0.16)


func _stop_charge_bar_loss_feedback(reset_visual := true) -> void:
	if _charge_bar_loss_tween:
		_charge_bar_loss_tween.kill()
		_charge_bar_loss_tween = null
	charge_bar.position = _charge_bar_base_position
	if reset_visual:
		charge_bar.self_modulate = Color.WHITE


func _log_charge() -> void:
	var charge_step := floori((_charge / required_charge) * 10.0)
	if charge_step == _last_logged_charge_step:
		return

	_last_logged_charge_step = charge_step
	print("[BushMinigame] Charge %.2f/%.2f" % [_charge, required_charge])


func _load_next_zone_pack() -> void:
	if ZONE_TEXTURES.is_empty():
		return

	var next_index := randi_range(0, ZONE_TEXTURES.size() - 1)
	if ZONE_TEXTURES.size() > 1:
		while next_index == _current_zone_index:
			next_index = randi_range(0, ZONE_TEXTURES.size() - 1)

	_current_zone_index = next_index
	zone_sprite.texture = ZONE_TEXTURES[_current_zone_index]
	_rotation_direction = ZONE_DIRECTIONS[_current_zone_index]
	_cache_zone_image()
	print("[BushMinigame] Loaded zone pack %s, direction %s" % [
		ZONE_NAMES[_current_zone_index],
		"clockwise" if _rotation_direction > 0.0 else "counter-clockwise",
	])


func _cache_zone_image() -> void:
	if zone_sprite.texture:
		_zone_image = zone_sprite.texture.get_image()


func _get_zone_at_cursor() -> ZoneType:
	return _get_zone_at_pixel(_get_zone_pixel_at_global_position(cursor.global_position))


func _get_effective_zone_at_cursor() -> ZoneType:
	if _charge >= required_charge and _is_cut_zone_near_cursor():
		return ZoneType.CUT

	return _get_zone_at_cursor()


func _is_cut_zone_near_cursor() -> bool:
	var center_pixel := _get_zone_pixel_at_global_position(cursor.global_position)
	for y in range(-cut_zone_margin_pixels, cut_zone_margin_pixels + 1):
		for x in range(-cut_zone_margin_pixels, cut_zone_margin_pixels + 1):
			if Vector2(x, y).length() > cut_zone_margin_pixels:
				continue
			if _get_zone_at_pixel(center_pixel + Vector2i(x, y)) == ZoneType.CUT:
				return true

	return false


func _get_zone_at_angle(angle_degrees: float) -> ZoneType:
	var local_position := Vector2.RIGHT.rotated(deg_to_rad(angle_degrees)) * cursor_radius
	return _get_zone_at_pixel(_get_zone_pixel_at_global_position(game_root.to_global(local_position)))


func _get_zone_pixel_at_global_position(global_position: Vector2) -> Vector2i:
	var local_position := zone_sprite.to_local(global_position)
	var texture_size := zone_sprite.texture.get_size()

	if zone_sprite.centered:
		local_position += texture_size * 0.5

	local_position -= zone_sprite.offset
	return Vector2i(floori(local_position.x), floori(local_position.y))


func _get_zone_at_pixel(pixel_position: Vector2i) -> ZoneType:
	if not _zone_image:
		return ZoneType.NONE

	var image_size := _zone_image.get_size()
	if pixel_position.x < 0 or pixel_position.y < 0 or pixel_position.x >= image_size.x or pixel_position.y >= image_size.y:
		return ZoneType.NONE

	var color := _zone_image.get_pixelv(pixel_position)
	if color.a < zone_alpha_threshold:
		return ZoneType.NONE
	if color.r > 0.55 and color.g > 0.45 and color.b < 0.35:
		return ZoneType.CHARGE
	if color.g > color.r and color.g > color.b:
		return ZoneType.CUT
	if color.r > 0.5 and color.g < 0.45 and color.b < 0.45:
		return ZoneType.DANGER

	return ZoneType.NONE


func cancel() -> void:
	if is_finished:
		return

	emit_finished(_build_cancelled_result())
	queue_free()


func _finish(was_successful: bool) -> void:
	if is_finished:
		return

	var result := _build_result(was_successful)
	if was_successful:
		completed.emit(plant_id)
		SoundManager.play_simple_sound("Actions/Success")
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
	result.time_cost_blocks = time_cost_blocks
	result.miss_time_cost_blocks = miss_time_cost_blocks
	return result


func _get_minigame_id() -> StringName:
	if context:
		var context_minigame_id := context.get_minigame_id()
		if context_minigame_id != &"":
			return context_minigame_id

	return &"bush"


func _get_result_rewards() -> Dictionary:
	if context:
		return context.rewards.duplicate(true)

	return {
		&"plant_id": plant_id,
		&"amount": 1,
		&"display_name": plant_display_name,
		&"marks": plant_marks,
	}


func _get_result_metadata() -> Dictionary:
	if context:
		return context.metadata.duplicate(true)

	return {}


func _show_feedback(text: String, color: Color, outline_color: Color) -> void:
	if _feedback_tween:
		_feedback_tween.kill()

	feedback_label.text = text
	feedback_label.modulate = color
	var setting := LabelSettings.new()
	setting.outline_color = outline_color
	setting.outline_size = 1
	feedback_label.label_settings = setting
	_feedback_tween = create_tween()
	_feedback_tween.tween_interval(0.25)
	_feedback_tween.tween_property(feedback_label, "modulate:a", 0.0, 0.25)


func _shake_ring() -> void:
	var start_position := game_root.position
	var tween := create_tween()
	tween.tween_property(game_root, "position", start_position + Vector2(2, 0), 0.04)
	tween.tween_property(game_root, "position", start_position + Vector2(-2, 0), 0.04)
	tween.tween_property(game_root, "position", start_position, 0.04)


func _center_game() -> void:
	var center := get_viewport().get_visible_rect().size * 0.5
	game_root.position = center
	charge_bar_root.position = center


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
