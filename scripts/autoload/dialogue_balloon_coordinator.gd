extends Node

const DEFAULT_NPC_BALLOON_SCENE: PackedScene = preload("res://ui/dialogue/npc_balloon.tscn")
const DEFAULT_PLAYER_RESPONSE_BALLOON_SCENE: PackedScene = preload("res://ui/dialogue/player_response_balloon.tscn")
const STEP_NPC := "npc"
const STEP_PLAYER := "player"

var is_running := false
var _requested_dialogue_steps: Array[Dictionary] = []


func request_npc_dialogue(title: String) -> void:
	_request_dialogue_step(STEP_NPC, title)


func request_player_dialogue(title: String) -> void:
	_request_dialogue_step(STEP_PLAYER, title)


func run_world_sequence(
	dialogue_resource: DialogueResource,
	dialogue_title: String = "",
	world_position: Vector2 = Vector2.ZERO,
	balloon_color: Color = Color.WHITE,
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
	var dialogue_states := [self] + extra_game_states
	_requested_dialogue_steps.clear()

	var npc_balloon := DialogueManager.show_dialogue_balloon_scene(
		resolved_npc_balloon_scene,
		dialogue_resource,
		dialogue_title,
		dialogue_states
	)
	await _prepare_world_balloon(npc_balloon, world_position, balloon_color)
	await _wait_for_dialogue_to_end(dialogue_resource)
	await _run_requested_dialogues(
		dialogue_resource,
		world_position,
		balloon_color,
		dialogue_states,
		resolved_npc_balloon_scene,
		resolved_player_response_balloon_scene
	)

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
	var dialogue_states := [self] + extra_game_states
	_requested_dialogue_steps.clear()
	DialogueManager.show_dialogue_balloon_scene(
		resolved_player_response_balloon_scene,
		dialogue_resource,
		player_response_title,
		dialogue_states
	)
	await _wait_for_dialogue_to_end(dialogue_resource)
	is_running = false
	return true


func _request_dialogue_step(speaker: String, title: String) -> void:
	if title.is_empty():
		return
	_requested_dialogue_steps.append({
		speaker = speaker,
		title = title,
	})


func _prepare_world_balloon(balloon: Node, world_position: Vector2, balloon_color: Color) -> void:
	await get_tree().process_frame
	if not is_instance_valid(balloon):
		return
	if balloon.has_method("set_balloon_color"):
		balloon.set_balloon_color(balloon_color)
	if balloon.has_method("set_balloon_world_position"):
		balloon.set_balloon_world_position(world_position)


func _run_requested_dialogues(
	dialogue_resource: DialogueResource,
	world_position: Vector2,
	balloon_color: Color,
	dialogue_states: Array,
	npc_balloon_scene: PackedScene,
	player_response_balloon_scene: PackedScene
) -> void:
	while _requested_dialogue_steps.size() > 0:
		var step: Dictionary = _requested_dialogue_steps.pop_front()
		var speaker: String = step.get("speaker", STEP_NPC)
		var title: String = step.get("title", "")
		var balloon_scene := npc_balloon_scene if speaker == STEP_NPC else player_response_balloon_scene
		var balloon := DialogueManager.show_dialogue_balloon_scene(balloon_scene, dialogue_resource, title, dialogue_states)

		if speaker == STEP_NPC:
			await _prepare_world_balloon(balloon, world_position, balloon_color)

		await _wait_for_dialogue_to_end(dialogue_resource)


func _wait_for_dialogue_to_end(dialogue_resource: DialogueResource) -> void:
	while true:
		var ended_resource: DialogueResource = await DialogueManager.dialogue_ended
		if ended_resource == dialogue_resource:
			return
