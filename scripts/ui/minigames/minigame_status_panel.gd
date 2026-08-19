extends VBoxContainer
class_name MinigameStatusPanel

@export_multiline var explanation_label_text: String = ""

@onready var _hit_progress_bar: TextureProgressBar = $ControlProgressBox/HitProgressBar
@onready var _miss_progress_bar: TextureProgressBar = $ControlProgressBox/MissProgressBar
@onready var _time_cost_label: Label = $TimeContainer/TimeLabel
@onready var _explanation_label: RichTextLabel = $ExplanationLabel

var _time_cost_blocks := 0.0
var _miss_time_cost_blocks := 0.0
var _hits := 0
var _misses := 0
var _hit_progress_tween: Tween
var _miss_progress_tween: Tween
var _miss_bar_shake_tween: Tween


func setup(
	required_hits: int,
	max_misses: int,
	time_cost_blocks: float,
	miss_time_cost_blocks: float
) -> void:
	_time_cost_blocks = time_cost_blocks
	_miss_time_cost_blocks = miss_time_cost_blocks
	_hits = 0
	_misses = 0
	_explanation_label.text = explanation_label_text

	_setup_progress_bar(_hit_progress_bar, required_hits)
	_setup_progress_bar(_miss_progress_bar, max_misses)
	_update_time_cost_label()


func set_hits(hits: int, animate := true) -> void:
	_hits = hits
	if animate:
		_hit_progress_tween = _animate_progress_bar(_hit_progress_bar, _hit_progress_tween, float(_hits))
	else:
		_hit_progress_bar.value = _hits


func set_misses(misses: int, animate := true) -> void:
	_misses = misses
	if animate:
		_miss_progress_tween = _animate_progress_bar(_miss_progress_bar, _miss_progress_tween, float(_misses))
		_shake_miss_bar()
	else:
		_miss_progress_bar.value = _misses
	_update_time_cost_label(animate)


func _setup_progress_bar(bar: TextureProgressBar, max_value: int) -> void:
	bar.min_value = 0.0
	bar.max_value = max_value
	bar.step = 0.0
	bar.value = 0.0
	bar.self_modulate = Color.WHITE


func _animate_progress_bar(
	bar: TextureProgressBar,
	current_tween: Tween,
	target_value: float
) -> Tween:
	if current_tween:
		current_tween.kill()

	var start_modulate := bar.self_modulate
	var flash_modulate := Color(2.5, 2.5, 2.5, 1.0)
	var overshoot := minf(target_value + 0.12, bar.max_value)

	var tween := create_tween()
	tween.tween_property(bar, "value", target_value, 0.18)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(bar, "self_modulate", flash_modulate, 0.05)
	tween.tween_property(bar, "value", overshoot, 0.07)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(bar, "value", target_value, 0.12)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(bar, "self_modulate", start_modulate, 0.16)
	return tween


func _shake_miss_bar() -> void:
	if _miss_bar_shake_tween:
		_miss_bar_shake_tween.kill()

	var start_position := _miss_progress_bar.position
	_miss_bar_shake_tween = create_tween()
	_miss_bar_shake_tween.tween_property(_miss_progress_bar, "position", start_position + Vector2(1.5, 0), 0.035)
	_miss_bar_shake_tween.tween_property(_miss_progress_bar, "position", start_position + Vector2(-1.5, 0), 0.035)
	_miss_bar_shake_tween.tween_property(_miss_progress_bar, "position", start_position + Vector2(1.0, 0), 0.03)
	_miss_bar_shake_tween.tween_property(_miss_progress_bar, "position", start_position, 0.04)


func _update_time_cost_label(animate := false) -> void:
	var total_blocks := _time_cost_blocks + (float(_misses) * _miss_time_cost_blocks)
	var total_minutes := roundi(total_blocks * GameState.BLOCK_MINUTES)
	_time_cost_label.text = "+%d min" % total_minutes
	if animate:
		_shake_time_cost()


func _shake_time_cost() -> void:
	var start_position := _time_cost_label.position
	var base_color := _time_cost_label.modulate
	var flash_color := Color(2.5, 2.5, 2.5, 1.0)

	var tween := create_tween()
	tween.tween_property(_time_cost_label, "position", start_position + Vector2(1.5, 0), 0.035)
	tween.tween_property(_time_cost_label, "position", start_position + Vector2(-1.5, 0), 0.035)
	tween.tween_property(_time_cost_label, "position", start_position + Vector2(1.0, 0), 0.03)
	tween.tween_property(_time_cost_label, "position", start_position, 0.04)
	tween.parallel().tween_property(_time_cost_label, "modulate", flash_color, 0.06)
	tween.tween_property(_time_cost_label, "modulate", base_color, 0.16)
