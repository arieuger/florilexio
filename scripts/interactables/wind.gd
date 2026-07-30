extends Node2D

@export var conversation: ConversationDefinition
@onready var trigger_area: Area2D = $TriggerArea

var _is_running := false

func _ready():
	trigger_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"): return
	if _is_running: return
	if is_instance_valid(conversation) and ConversationHistory.has_finished(conversation.conversation_id):
		return

	_is_running = true
	_set_player_movement_enabled(false)

	if is_instance_valid(conversation):
		await DialogueBalloonCoordinator.play(conversation)
		
	_set_player_movement_enabled(true)
	_is_running = false

func _set_player_movement_enabled(enabled: bool) -> void:
	var root := get_tree().current_scene
	if root and root.has_method("set_player_movement_enabled"):
		root.set_player_movement_enabled(enabled)
