extends CanvasLayer

const TIME_LABEL_DEFAULT_COLOR := Color('#d3ffce')
const TIME_LABEL_WARNING_COLOR := Color(0.85, 0.08, 0.06, 1)

@export var final_composition_scene: PackedScene = preload("res://ui/final_composition/final_composition_panel.tscn")
@export var final_firelight_dialogue: DialogueResource = preload("res://dialogues/scene1/firelight.dialogue")
@export var final_firelight_dialogue_title := "final_firelight_talk"
@export var final_firelight_speaker_id := "firelight"
@export_file("*.tscn") var final_area_path := "res://scenes/world/town_square.tscn"
@export var final_spawn_id: StringName = &"final_player_spawn"
@export var final_area_transition_duration := 0.45
@export_group("Final Spotlight")
@export_range(8.0, 360.0, 1.0) var final_spotlight_radius := 72.0
@export_range(0.0, 120.0, 1.0) var final_spotlight_softness := 10.0
@export var final_spotlight_marker_id: StringName = &"fire_place"
@export var final_spotlight_marker_path: NodePath
@export var final_spotlight_color := Color.BLACK
@export_group("Mortal Final")
@export var final_mortal_overlay_color := Color(0.7, 0.02, 0.02, 0.65)
@export_range(0.1, 8.0, 0.1) var final_mortal_overlay_fade_duration := 3
@export_group("")

@onready var inventory_button: TextureButton = $InventoryButton
@onready var time_label: Label = $TimeLabel
@onready var inventory_panel: Control = $InventoryPanel

var _time_shake_tween: Tween
var _time_blink_tween: Tween
var _time_label_base_position: Vector2
var _final_sequence_started := false
var _final_composition_panel: FinalCompositionPanel
var _final_scene_spotlight: FinalSceneSpotlight
var _final_mortal_overlay_layer: CanvasLayer
var _final_mortal_overlay_tween: Tween


func _ready() -> void:
	_time_label_base_position = time_label.position
	_set_inventory_open(false)
	_update_time_label(GameState.consumed_time)
	GameState.consumed_time_added.connect(_on_consumed_time_added)
	inventory_button.pressed.connect(_toggle_inventory)
	inventory_button.pressed.connect(_on_inventory_button_pressed)
	inventory_button.mouse_entered.connect(_on_inventory_button_mouse_entered)
	if inventory_panel.has_signal(&"close_requested"):
		inventory_panel.connect(&"close_requested", _hide_inventory)
	if inventory_panel.has_signal(&"compose_bouquet_requested"):
		inventory_panel.connect(&"compose_bouquet_requested", _on_inventory_compose_bouquet_requested)


func _toggle_inventory() -> void:
	_set_inventory_open(not inventory_panel.visible)


func _hide_inventory() -> void:
	_set_inventory_open(false)


func _on_inventory_button_pressed() -> void:
	SoundManager.play_simple_sound("Inventory/Open Inventory")


func _on_inventory_button_mouse_entered() -> void:
	SoundManager.play_simple_sound("Actions/Hover")


func _set_inventory_open(is_open: bool) -> void:
	inventory_panel.visible = is_open
	inventory_button.visible = not is_open


func _update_time_label(_total_consumed_time: int) -> void:
	time_label.text = GameState.get_current_time_text()


func _on_consumed_time_added(total_consumed_time: int) -> void:
	_update_time_label(total_consumed_time)
	_play_time_feedback()
	if total_consumed_time >= GameState.TOTAL_BLOCKS:
		_start_final_sequence()


func _on_inventory_compose_bouquet_requested() -> void:
	GameState.set_consumed_time_blocks(GameState.TOTAL_BLOCKS)
	_start_final_sequence()


func _start_final_sequence() -> void:
	if _final_sequence_started:
		return

	_final_sequence_started = true
	_launch_final_sequence.call_deferred()


func _play_time_feedback() -> void:
	if _time_shake_tween:
		_time_shake_tween.kill()
	if _time_blink_tween:
		_time_blink_tween.kill()

	time_label.position = _time_label_base_position
	time_label.add_theme_color_override("font_color", TIME_LABEL_DEFAULT_COLOR)

	_time_shake_tween = create_tween()
	_time_shake_tween.tween_property(time_label, "position", _time_label_base_position + Vector2(2, 0), 0.04)
	_time_shake_tween.tween_property(time_label, "position", _time_label_base_position + Vector2(-2, 0), 0.04)
	_time_shake_tween.tween_property(time_label, "position", _time_label_base_position, 0.04)

	_time_blink_tween = create_tween()
	for blink_index in range(3):
		_time_blink_tween.tween_method(_set_time_label_color, TIME_LABEL_DEFAULT_COLOR, TIME_LABEL_WARNING_COLOR, 0.12)
		_time_blink_tween.tween_interval(0.12)
		_time_blink_tween.tween_method(_set_time_label_color, TIME_LABEL_WARNING_COLOR, TIME_LABEL_DEFAULT_COLOR, 0.18)
		if blink_index < 2:
			_time_blink_tween.tween_interval(0.42)


func _set_time_label_color(color: Color) -> void:
	time_label.add_theme_color_override("font_color", color)


func _launch_final_sequence() -> void:
	_set_inventory_open(false)
	inventory_button.visible = false
	_set_player_movement_enabled(false)

	await _close_cutting_minigames()
	await _go_to_final_area()
	await get_tree().create_timer(0.45).timeout
	while DialogueBalloonCoordinator.is_running:
		await get_tree().process_frame

	await DialogueBalloonCoordinator.show_info_dialogue_and_wait("final_game_intro")
	_show_final_composition()


func _close_cutting_minigames() -> void:
	var minigames := get_tree().get_nodes_in_group("cutting_minigame")
	for minigame in minigames:
		if minigame.has_method("cancel"):
			minigame.cancel()
		else:
			minigame.queue_free()

	for minigame in minigames:
		if is_instance_valid(minigame):
			await minigame.tree_exited


func _go_to_final_area() -> void:
	if final_area_path.is_empty():
		return

	var root := get_tree().current_scene
	if not root:
		return

	var final_area := load(final_area_path) as PackedScene
	if not final_area:
		push_warning("GameHUD: could not load final area: %s" % final_area_path)
		return

	if root.has_method("transition_to_area"):
		await root.transition_to_area(final_area, final_spawn_id, final_area_transition_duration)
	elif root.has_method("load_area"):
		root.load_area(final_area, final_spawn_id)


func _show_final_composition() -> void:
	if is_instance_valid(_final_composition_panel) or not is_instance_valid(final_composition_scene):
		return

	GameState.clear_final_bouquet_composition()
	InventoryManager.clear_bouquet()
	_final_composition_panel = final_composition_scene.instantiate() as FinalCompositionPanel
	if not _final_composition_panel:
		return

	_final_composition_panel.composition_requested.connect(_on_final_composition_requested)
	add_child(_final_composition_panel)


func _on_final_composition_requested(composition: Dictionary) -> void:
	print("Composición final do cacho: ", composition)
	var is_mortal_final := _is_mortal_final(composition)
	if is_mortal_final:
		_set_player_visible(false)
	_close_final_composition_panel()
	await _move_player_to_final_spawn()
	_show_final_scene_spotlight()
	await get_tree().create_timer(0.35).timeout
	await _show_final_firelight_dialogue()
	if is_mortal_final:
		_show_mortal_red_overlay()
	await DialogueBalloonCoordinator.show_info_dialogue_and_wait(_get_final_result_dialogue_title(composition))
	if bool(composition.get("player_removed_invasors", false)):
		await DialogueBalloonCoordinator.show_info_dialogue_and_wait("final_player_removed_invasors")


func _close_final_composition_panel() -> void:
	if not is_instance_valid(_final_composition_panel):
		return

	_final_composition_panel.queue_free()
	_final_composition_panel = null


func _move_player_to_final_spawn() -> void:
	var root := get_tree().current_scene
	if root and root.has_method("move_player_to_spawn"):
		root.move_player_to_spawn(final_spawn_id)
		await get_tree().process_frame


func _show_final_scene_spotlight() -> void:
	if is_instance_valid(_final_scene_spotlight):
		return

	_final_scene_spotlight = FinalSceneSpotlight.new()
	_final_scene_spotlight.radius_pixels = final_spotlight_radius
	_final_scene_spotlight.softness_pixels = final_spotlight_softness
	_final_scene_spotlight.dim_color = final_spotlight_color
	var root := get_tree().current_scene
	if root:
		root.add_child(_final_scene_spotlight)
	else:
		add_child(_final_scene_spotlight)

	var marker := _get_final_spotlight_marker()
	if marker:
		_final_scene_spotlight.set_focus_node(marker)
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		_final_scene_spotlight.set_focus_node(player)


func _is_mortal_final(composition: Dictionary) -> bool:
	return StringName(composition.get("rank", &"empty")) == &"mortal"


func _set_player_visible(should_show: bool) -> void:
	var player := get_tree().get_first_node_in_group("player") as CanvasItem
	if player:
		player.visible = should_show


func _show_mortal_red_overlay() -> void:
	if is_instance_valid(_final_mortal_overlay_layer):
		return

	_final_mortal_overlay_layer = CanvasLayer.new()
	_final_mortal_overlay_layer.layer = 79

	var overlay := ColorRect.new()
	overlay.color = Color(
		final_mortal_overlay_color.r,
		final_mortal_overlay_color.g,
		final_mortal_overlay_color.b,
		0.0
	)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_final_mortal_overlay_layer.add_child(overlay)

	var root := get_tree().current_scene
	if root:
		root.add_child(_final_mortal_overlay_layer)
	else:
		add_child(_final_mortal_overlay_layer)

	if _final_mortal_overlay_tween:
		_final_mortal_overlay_tween.kill()
	_final_mortal_overlay_tween = create_tween()
	_final_mortal_overlay_tween.tween_property(
		overlay,
		"color:a",
		final_mortal_overlay_color.a,
		final_mortal_overlay_fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _show_final_firelight_dialogue() -> void:
	if not is_instance_valid(final_firelight_dialogue):
		return

	var fallback_marker := _get_final_spotlight_marker()
	var fallback_position := fallback_marker.global_position if fallback_marker else Vector2.ZERO
	await DialogueBalloonCoordinator.run_speaker_sequence(
		final_firelight_dialogue,
		final_firelight_dialogue_title,
		final_firelight_speaker_id,
		fallback_position
	)


func _get_final_spotlight_marker() -> Node2D:
	if not final_spotlight_marker_path.is_empty():
		var marker_from_path := get_node_or_null(final_spotlight_marker_path) as Node2D
		if marker_from_path:
			return marker_from_path

	var root := get_tree().current_scene
	if root and root.has_method("get_current_area_marker"):
		return root.get_current_area_marker(final_spotlight_marker_id) as Node2D

	return null


func _get_final_result_dialogue_title(composition: Dictionary) -> String:
	var rank := StringName(composition.get("rank", &"empty"))
	match rank:
		&"mortal":
			return "final_bouquet_mortal"
		&"traditional":
			return "final_bouquet_traditional"
		&"invader":
			return "final_bouquet_invader"
		&"too_big":
			return "final_bouquet_too_big"
		&"too_small":
			return "final_bouquet_too_small"
		&"empty":
			return "final_bouquet_empty"
		_:
			return "final_bouquet_mediocre"


func _set_player_movement_enabled(enabled: bool) -> void:
	var root := get_tree().current_scene
	if root and root.has_method("set_player_movement_enabled"):
		root.set_player_movement_enabled(enabled)
