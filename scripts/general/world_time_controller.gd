extends CanvasModulate

@export var morning_color:= Color("#dff9ff") 
@export var afternoon_color:= Color("#fff2d9") # Desde bloque 15
@export var sunset_color:= Color("#ffd1a6") # Desde bloque 29
@export var night_color:= Color("#5c6b99") # Desde bloque 41

var _color_tween: Tween
var _current_world_color: Color

func _ready() -> void:
	GameState.consumed_time_added.connect(_on_consumed_time_added)
	_current_world_color = _get_world_color(GameState.consumed_time)
	color = _current_world_color

func _on_consumed_time_added(total_consumed_time: int) -> void:
	var target_color = _get_world_color(total_consumed_time)
	if target_color == _current_world_color: return

	_current_world_color = target_color
	_tween_world_color(target_color)

func _get_world_color(consumed_time: int) -> Color:
	var clamped_blocks = clamp(consumed_time, 0, GameState.TOTAL_BLOCKS)
	var progress = float(clamped_blocks) / float(GameState.TOTAL_BLOCKS)
	if progress < 0.3:
		return morning_color
	elif progress < 0.6:
		return afternoon_color
	elif progress < 0.85:
		return sunset_color
	else:        
		return night_color

func _tween_world_color(target_color: Color) -> void:
	if _color_tween: _color_tween.kill()
	
	_color_tween = create_tween()
	_color_tween.tween_property(self, "color", target_color, 1.2).\
		set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
