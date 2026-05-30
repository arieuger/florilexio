extends Node2D

@export var final_wind_dialogue: DialogueResource = preload("res://dialogues/scene2/wind_and_font.dialogue")
@export var final_wind_dialogue_title := "wind_blowing"
@export var final_wind_speake_id := "wind"

@onready var trigger_area: Area2D = $TriggerArea

var _is_running := false

func _ready():
	trigger_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"): return
	if GameState.wind_already_spoke or _is_running: return

	_is_running = true
	_set_player_movement_enabled(false)
	await DialogueBalloonCoordinator.run_speaker_sequence(
		final_wind_dialogue,
		final_wind_dialogue_title,
		final_wind_speake_id
	)
	_set_player_movement_enabled(true)
	_is_running = false

func _set_player_movement_enabled(enabled: bool) -> void:
	var root := get_tree().current_scene
	if root and root.has_method("set_player_movement_enabled"):
		root.set_player_movement_enabled(enabled)
