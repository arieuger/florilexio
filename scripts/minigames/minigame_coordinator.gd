extends Node
class_name MinigameCoordinator

signal time_cost_requested(time_cost_blocks: float)

var _active_minigame: BaseMinigame
var _minigame_player: Node
var _minigame_player_movement_was_enabled := true


func is_minigame_running() -> bool:
	return is_instance_valid(_active_minigame)


func play_minigame(context: MinigameContext) -> MinigameResult:
	if is_minigame_running():
		push_warning("MinigameCoordinator: a minigame is already running")
		return _make_failed_result(context)
	if not context or not context.get_scene():
		push_warning("MinigameCoordinator: missing minigame context or scene")
		return _make_failed_result(context)

	var minigame := context.get_scene().instantiate() as BaseMinigame
	if not minigame:
		push_warning("MinigameCoordinator: scene does not inherit BaseMinigame")
		return _make_failed_result(context)

	_active_minigame = minigame
	_disable_player_movement_for_minigame()
	minigame.time_cost_requested.connect(_on_minigame_time_cost_requested)
	minigame.setup(context)
	var parent := get_tree().current_scene if get_tree().current_scene else self
	parent.add_child(minigame)

	var result: MinigameResult = await minigame.finished
	if minigame.time_cost_requested.is_connected(_on_minigame_time_cost_requested):
		minigame.time_cost_requested.disconnect(_on_minigame_time_cost_requested)
	_restore_player_movement_after_minigame()
	_active_minigame = null
	return result


func _make_failed_result(context: MinigameContext) -> MinigameResult:
	if not context:
		return MinigameResult.failed_result(&"", &"")

	return MinigameResult.failed_result(
		context.get_minigame_id(),
		context.target_id,
		context.rewards,
		context.metadata
	)


func _disable_player_movement_for_minigame() -> void:
	_minigame_player = get_tree().get_first_node_in_group(&"player")
	_minigame_player_movement_was_enabled = true
	if not _minigame_player:
		return

	if "movement_enabled" in _minigame_player:
		_minigame_player_movement_was_enabled = bool(_minigame_player.get("movement_enabled"))
	if _minigame_player.has_method(&"set_movement_enabled"):
		_minigame_player.call(&"set_movement_enabled", false)
	else:
		_minigame_player.set("movement_enabled", false)


func _restore_player_movement_after_minigame() -> void:
	if not is_instance_valid(_minigame_player):
		_minigame_player = null
		return

	if _minigame_player.has_method(&"set_movement_enabled"):
		_minigame_player.call(&"set_movement_enabled", _minigame_player_movement_was_enabled)
	else:
		_minigame_player.set("movement_enabled", _minigame_player_movement_was_enabled)
	_minigame_player = null


func _on_minigame_time_cost_requested(time_cost_blocks: float) -> void:
	time_cost_requested.emit(time_cost_blocks)
