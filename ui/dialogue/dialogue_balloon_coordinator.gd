extends Node

const DEFAULT_NPC_BALLOON_SCENE: PackedScene = preload("res://ui/dialogue/npc_balloon.tscn")
const DEFAULT_PLAYER_RESPONSE_BALLOON_SCENE: PackedScene = preload("res://ui/dialogue/player_response_balloon.tscn")

var is_running := false


func run_world_sequence(
	dialogue_resource: DialogueResource,
	dialogue_title: String = "",
	world_position: Vector2 = Vector2.ZERO,
	balloon_color: Color = Color.WHITE,
	player_response_title: String = "",
	extra_game_states: Array = [],
	npc_balloon_scene: PackedScene = DEFAULT_NPC_BALLOON_SCENE,
	player_response_balloon_scene: PackedScene = DEFAULT_PLAYER_RESPONSE_BALLOON_SCENE
) -> bool:
	if is_running:
		return false
	if not is_instance_valid(dialogue_resource):
		push_warning("DialogueBalloonCoordinator: missing dialogue_resource.")
		return false

	is_running = true
	var resolved_npc_balloon_scene := npc_balloon_scene if is_instance_valid(npc_balloon_scene) else DEFAULT_NPC_BALLOON_SCENE
	var resolved_player_response_balloon_scene := player_response_balloon_scene if is_instance_valid(player_response_balloon_scene) else DEFAULT_PLAYER_RESPONSE_BALLOON_SCENE

	var npc_balloon := DialogueManager.show_dialogue_balloon_scene(
		resolved_npc_balloon_scene,
		dialogue_resource,
		dialogue_title,
		extra_game_states
	)
	await _prepare_world_balloon(npc_balloon, world_position, balloon_color)
	await _wait_for_dialogue_to_end(dialogue_resource)

	if not player_response_title.is_empty():
		DialogueManager.show_dialogue_balloon_scene(
			resolved_player_response_balloon_scene,
			dialogue_resource,
			player_response_title,
			extra_game_states
		)
		await _wait_for_dialogue_to_end(dialogue_resource)

	is_running = false
	return true


func run_player_response(
	dialogue_resource: DialogueResource,
	player_response_title: String,
	extra_game_states: Array = [],
	player_response_balloon_scene: PackedScene = DEFAULT_PLAYER_RESPONSE_BALLOON_SCENE
) -> bool:
	if is_running:
		return false
	if not is_instance_valid(dialogue_resource) or player_response_title.is_empty():
		return false

	is_running = true
	var resolved_player_response_balloon_scene := player_response_balloon_scene if is_instance_valid(player_response_balloon_scene) else DEFAULT_PLAYER_RESPONSE_BALLOON_SCENE
	DialogueManager.show_dialogue_balloon_scene(
		resolved_player_response_balloon_scene,
		dialogue_resource,
		player_response_title,
		extra_game_states
	)
	await _wait_for_dialogue_to_end(dialogue_resource)
	is_running = false
	return true


func _prepare_world_balloon(balloon: Node, world_position: Vector2, balloon_color: Color) -> void:
	await get_tree().process_frame
	if not is_instance_valid(balloon):
		return
	if balloon.has_method("set_balloon_color"):
		balloon.set_balloon_color(balloon_color)
	if balloon.has_method("set_balloon_world_position"):
		balloon.set_balloon_world_position(world_position)


func _wait_for_dialogue_to_end(dialogue_resource: DialogueResource) -> void:
	while true:
		var ended_resource: DialogueResource = await DialogueManager.dialogue_ended
		if ended_resource == dialogue_resource:
			return
