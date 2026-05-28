extends Node

const DEFAULT_NPC_BALLOON_SCENE: PackedScene = preload("res://ui/dialogue/npc_balloon.tscn")
const DEFAULT_PLAYER_RESPONSE_BALLOON_SCENE: PackedScene = preload("res://ui/dialogue/player_response_balloon.tscn")
const DEFAULT_INFO_BALLOON_SCENE: PackedScene = preload("res://ui/dialogue/generic_info_balloon.tscn")
const GENERAL_INFO_DIALOGUE : DialogueResource = preload("res://dialogues/info.dialogue")
const STEP_NPC := "npc"
const STEP_PLAYER := "player"
const STEP_SPEAKER := "speaker"

var is_running := false
var _requested_dialogue_steps: Array[Dictionary] = []
var _current_info_balloon: GenericInfoBalloon


func request_npc_dialogue(title: String) -> void:
	_request_dialogue_step(STEP_NPC, title)


func request_player_dialogue(title: String) -> void:
	_request_dialogue_step(STEP_PLAYER, title)


func request_speaker_dialogue(speaker_id: String, title: String) -> void:
	_request_dialogue_step(STEP_SPEAKER, title, speaker_id)


func run_world_sequence(
	dialogue_resource: DialogueResource,
	dialogue_title: String = "",
	world_position: Vector2 = Vector2.ZERO,
	balloon_color: Color = Color.WHITE,
	voice_type: float = 0.0,
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
	SoundManager.set_global_parameter("VoiceType", voice_type)
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


func run_speaker_sequence(
	dialogue_resource: DialogueResource,
	dialogue_title: String,
	speaker_id: String,
	fallback_world_position: Vector2 = Vector2.ZERO,
	fallback_balloon_color: Color = Color.WHITE,
	extra_game_states: Array = [],
	npc_balloon_scene: PackedScene = DEFAULT_NPC_BALLOON_SCENE,
	player_response_balloon_scene: PackedScene = DEFAULT_PLAYER_RESPONSE_BALLOON_SCENE
) -> bool:
	if is_running:
		return false
	if not is_instance_valid(dialogue_resource) or dialogue_title.is_empty() or speaker_id.is_empty():
		return false

	is_running = true
	var resolved_npc_balloon_scene := npc_balloon_scene if is_instance_valid(npc_balloon_scene) else DEFAULT_NPC_BALLOON_SCENE
	var resolved_player_response_balloon_scene := player_response_balloon_scene if is_instance_valid(player_response_balloon_scene) else DEFAULT_PLAYER_RESPONSE_BALLOON_SCENE
	var dialogue_states := [self] + extra_game_states
	var speaker_step := {
		speaker = STEP_SPEAKER,
		title = dialogue_title,
		speaker_id = speaker_id,
	}
	_requested_dialogue_steps.clear()

	var balloon_scene := _get_step_balloon_scene(STEP_SPEAKER, speaker_step, resolved_npc_balloon_scene, resolved_player_response_balloon_scene)
	_set_voice_type_for_speaker_step(speaker_step)
	var balloon := DialogueManager.show_dialogue_balloon_scene(balloon_scene, dialogue_resource, dialogue_title, dialogue_states)
	await _prepare_speaker_balloon(balloon, speaker_step, fallback_world_position, fallback_balloon_color)
	await _wait_for_dialogue_to_end(dialogue_resource)
	await _run_requested_dialogues(
		dialogue_resource,
		fallback_world_position,
		fallback_balloon_color,
		dialogue_states,
		resolved_npc_balloon_scene,
		resolved_player_response_balloon_scene
	)

	is_running = false
	return true


func show_info_dialogue(
	dialogue_title: String,
	replacements: Dictionary = {},
	duration: float = -1.0,
	extra_game_states: Array = []
) -> bool:
	if not is_instance_valid(GENERAL_INFO_DIALOGUE):
		push_warning("DialogueBalloonCoordinator: missing info dialogue_resource.")
		return false

	var dialogue_states := [self] + extra_game_states
	var line: DialogueLine = await GENERAL_INFO_DIALOGUE.get_next_dialogue_line(dialogue_title, dialogue_states)
	if not is_instance_valid(line):
		return false

	var message := _apply_info_replacements(line.text, replacements)
	if is_instance_valid(_current_info_balloon):
		_current_info_balloon.queue_free()

	var balloon := DEFAULT_INFO_BALLOON_SCENE.instantiate() as GenericInfoBalloon
	if not balloon:
		push_warning("DialogueBalloonCoordinator: DEFAULT_INFO_BALLOON_SCENE must instantiate a GenericInfoBalloon.")
		return false

	_current_info_balloon = balloon
	get_tree().current_scene.add_child(balloon)
	balloon.show_message(message, duration)
	return true


func show_info_dialogue_and_wait(
	dialogue_title: String,
	replacements: Dictionary = {},
	extra_game_states: Array = []
) -> bool:
	if not is_instance_valid(GENERAL_INFO_DIALOGUE):
		push_warning("DialogueBalloonCoordinator: missing info dialogue_resource.")
		return false

	if is_instance_valid(_current_info_balloon):
		_current_info_balloon.queue_free()

	var balloon := DialogueManager.show_dialogue_balloon_scene(
		DEFAULT_INFO_BALLOON_SCENE,
		GENERAL_INFO_DIALOGUE,
		dialogue_title,
		[self] + extra_game_states
	) as GenericInfoBalloon
	if is_instance_valid(balloon):
		_current_info_balloon = balloon
		balloon.replacements = replacements

	await _wait_for_dialogue_to_end(GENERAL_INFO_DIALOGUE)
	return true


func _apply_info_replacements(message: String, replacements: Dictionary) -> String:
	var resolved_message := message
	for key in replacements.keys():
		resolved_message = resolved_message.replace("{" + str(key) + "}", str(replacements[key]))
	return resolved_message


func _request_dialogue_step(speaker: String, title: String, speaker_id: String = "") -> void:
	if title.is_empty():
		return
	_requested_dialogue_steps.append({
		speaker = speaker,
		title = title,
		speaker_id = speaker_id,
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
		var balloon_scene := _get_step_balloon_scene(speaker, step, npc_balloon_scene, player_response_balloon_scene)
		if speaker == STEP_SPEAKER:
			_set_voice_type_for_speaker_step(step)
		var balloon := DialogueManager.show_dialogue_balloon_scene(balloon_scene, dialogue_resource, title, dialogue_states)

		if speaker == STEP_NPC:
			await _prepare_world_balloon(balloon, world_position, balloon_color)
		elif speaker == STEP_SPEAKER:
			await _prepare_speaker_balloon(balloon, step, world_position, balloon_color)

		await _wait_for_dialogue_to_end(dialogue_resource)


func _get_step_balloon_scene(
	speaker: String,
	step: Dictionary,
	npc_balloon_scene: PackedScene,
	player_response_balloon_scene: PackedScene
) -> PackedScene:
	if speaker == STEP_PLAYER:
		return player_response_balloon_scene
	if speaker == STEP_SPEAKER:
		var dialogue_speaker := _get_dialogue_speaker(str(step.get("speaker_id", "")))
		if is_instance_valid(dialogue_speaker) and is_instance_valid(dialogue_speaker.get("balloon_scene")):
			return dialogue_speaker.get("balloon_scene") as PackedScene
	return npc_balloon_scene


func _prepare_speaker_balloon(balloon: Node, step: Dictionary, fallback_world_position: Vector2, fallback_balloon_color: Color) -> void:
	var dialogue_speaker := _get_dialogue_speaker(str(step.get("speaker_id", "")))
	if is_instance_valid(dialogue_speaker):
		var speaker_color: Color = dialogue_speaker.get("balloon_color")
		await _prepare_world_balloon(balloon, dialogue_speaker.global_position, speaker_color)
	else:
		await _prepare_world_balloon(balloon, fallback_world_position, fallback_balloon_color)


func _set_voice_type_for_speaker_step(step: Dictionary) -> void:
	var dialogue_speaker := _get_dialogue_speaker(str(step.get("speaker_id", "")))
	if not is_instance_valid(dialogue_speaker):
		return

	var voice_type_value = dialogue_speaker.get("voice_type")
	if voice_type_value is float:
		SoundManager.set_global_parameter("VoiceType", voice_type_value)


func _get_dialogue_speaker(speaker_id: String) -> Node2D:
	if speaker_id.is_empty():
		return null
	for speaker in get_tree().get_nodes_in_group("dialogue_speaker"):
		if str(speaker.get("speaker_id")) == speaker_id:
			return speaker as Node2D
	return null


func _wait_for_dialogue_to_end(dialogue_resource: DialogueResource) -> void:
	while true:
		var ended_resource: DialogueResource = await DialogueManager.dialogue_ended
		if ended_resource == dialogue_resource:
			return
