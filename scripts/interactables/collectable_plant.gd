extends Node2D
class_name CollectablePlant

@export var plant_launches_tutorial := false
@export var tutorial_dialogue: DialogueResource = preload("res://dialogues/scene1/tutorial.dialogue")
@export var tutorial_dialogue_title := "start"
@export var tutorial_speaker_id := "dog"

## Identifies the plant type/species. Multiple CollectablePlant instances can share it.
@export var plant_id: StringName
## Optional stable id for this exact plant instance. Empty ids are derived from the area scene and node path.
@export var collection_id: StringName
@export var plant_display_name: String
@export var hover_color: Color = Color(1.0, 1.0, 1.0, 0.75)
@export var hover_fade_duration: float = 0.18

@export_group("Plant features")
@export var is_poisonous := false
@export var is_mortal := false
@export var is_on_danger := false
@export var is_magic := false
@export var is_invasive := false

@export_group("Collection Minigame")
@export var collection_minigame_config: MinigameConfig = preload("res://resources/minigames/cutting_minigame_config.tres")
## Si queremos parametrizar específicamente unha planta, creamos un "new tuning resource" do tipo de minixogo que sexa dende o inspector. NUNCA MODIFICAR O RESOURCE BASE
@export var collection_minigame_tuning: MinigameTuning = preload("res://resources/minigames/cutting_minigame_tuning.tres")
@export_enum("Easy", "Medium", "Hard", "Tutorial") var collection_difficulty: int = MinigameDifficulty.Level.MEDIUM
## Negative values use the selected minigame/difficulty time cost.
@export var collection_time_cost_blocks: float = -1.0
## Negative values use the selected minigame/difficulty miss time cost.
@export var collection_miss_time_cost_blocks: float = -1.0
@export_group("")

@onready var hover_sprite: Sprite2D = $HoverSprite
@onready var name_label: Label = $NameLabel
@onready var click_area: Area2D = $ClickArea
@onready var interaction_point: Area2D = get_node_or_null("InteractionPoint") as Area2D

var _hover_tween: Tween
var _is_interacting := false
var _collection_id: StringName


func _ready() -> void:
	_collection_id = _get_collection_id()
	_make_hover_ignore_world_tint()
	hover_sprite.modulate = Color(hover_color.r, hover_color.g, hover_color.b, 0.0)
	name_label.text = _get_localized_plant_display_name()
	name_label.visible = false
	click_area.input_pickable = not _is_collected()
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)
	click_area.input_event.connect(_on_input_event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(name_label):
		name_label.text = _get_localized_plant_display_name()


func _on_mouse_entered() -> void:
	if not _can_interact():
		return

	SoundManager.play_simple_sound('Actions/Hover')
	
	_fade_hover_to(hover_color.a)
	_set_name_label_visible(true)


func _on_mouse_exited() -> void:
	_fade_hover_to(0.0)
	_set_name_label_visible(false)


func _on_input_event(viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _can_interact():
			return

		viewport.set_input_as_handled()
		_interact()


func _interact() -> void:
	if not _can_interact():
		return
		
	_is_interacting = true

	SoundManager.play_simple_sound('Actions/Click')

	if interaction_point:
		var player := get_tree().get_first_node_in_group("player")
		if player and player.has_method("move_to_area"):
			var reached: bool = await player.move_to_area(interaction_point)
			if not reached:
				_is_interacting = false
				return
		elif player and player.has_method("move_to_point"):
			var stop_distance: float = player.interaction_stop_distance if "interaction_stop_distance" in player else 6.0
			var reached: bool = await player.move_to_point(interaction_point.global_position, stop_distance)
			if not reached:
				_is_interacting = false
				return

	if _should_launch_tutorial():
		var tutorial_was_run := await _run_tutorial()
		if not tutorial_was_run:
			_is_interacting = false
			return

	start_collection_minigame()


func start_collection_minigame() -> void:
	var context := build_collection_minigame_context()
	var coordinator := _get_minigame_coordinator()
	if not coordinator:
		push_warning("CollectablePlant: MinigameCoordinator not found")
		_on_collection_minigame_closed()
		return

	_connect_minigame_time_cost(coordinator)
	var result: MinigameResult = await coordinator.play_minigame(context)
	_disconnect_minigame_time_cost(coordinator)
	_apply_collection_minigame_result(result)
	_on_collection_minigame_closed()


func build_collection_minigame_context() -> MinigameContext:
	var context := MinigameContext.new()
	context.config = collection_minigame_config
	context.target_id = plant_id
	context.display_name = plant_display_name
	context.difficulty_id = MinigameDifficulty.get_id(collection_difficulty)
	context.parameters = _build_collection_parameters()
	context.rewards = _build_collection_rewards()
	context.metadata = _build_collection_metadata()
	return context


func _build_collection_parameters() -> Dictionary:
	var difficulty_settings := CuttingMinigameDifficulty.get_settings(collection_difficulty)
	var parameters := {
		&"time_cost_blocks": _get_collection_time_cost(difficulty_settings),
		&"miss_time_cost_blocks": _get_collection_miss_time_cost(difficulty_settings),
	}
	if collection_minigame_tuning:
		parameters = collection_minigame_tuning.build_parameters(collection_difficulty, parameters)

	return parameters


func _build_collection_rewards() -> Dictionary:
	return {
		&"plant_id": plant_id,
		&"amount": 1,
		&"display_name": plant_display_name,
		&"marks": InventoryManager.build_plant_marks(self),
	}


func _build_collection_metadata() -> Dictionary:
	return {
		&"collection_id": _collection_id,
	}


func _apply_collection_minigame_result(result: MinigameResult) -> void:
	if not result or result.is_cancelled():
		return

	GameState.add_consumed_time(result.time_cost_blocks)
	if not result.is_success():
		return

	InventoryManager.add_item(
		StringName(result.rewards.get(&"plant_id", result.target_id)),
		int(result.rewards.get(&"amount", 1)),
		str(result.rewards.get(&"display_name", "")),
		_get_result_marks(result)
	)
	_on_collection_minigame_completed(result.target_id)


func _get_result_marks(result: MinigameResult) -> Dictionary:
	var marks: Variant = result.rewards.get(&"marks", {})
	return marks if marks is Dictionary else {}


func _on_collection_minigame_completed(_completed_plant_id: StringName) -> void:
	GameState.collect_plant(_collection_id)
	click_area.input_pickable = false
	_fade_hover_to(0.0)
	_set_name_label_visible(false)

	DialogueBalloonCoordinator.show_info_dialogue(
		"plant_collected",
		{"plant_name": _get_localized_plant_display_name()},
		1.5
	)

func _on_collection_minigame_closed() -> void:
	_is_interacting = false


func _connect_minigame_time_cost(coordinator: MinigameCoordinator) -> void:
	if coordinator.time_cost_requested.is_connected(_on_minigame_time_cost_requested):
		return

	coordinator.time_cost_requested.connect(_on_minigame_time_cost_requested)


func _disconnect_minigame_time_cost(coordinator: MinigameCoordinator) -> void:
	if coordinator.time_cost_requested.is_connected(_on_minigame_time_cost_requested):
		coordinator.time_cost_requested.disconnect(_on_minigame_time_cost_requested)


func _on_minigame_time_cost_requested(time_cost_blocks: float) -> void:
	GameState.add_consumed_time(time_cost_blocks)


func _should_launch_tutorial() -> bool:
	return plant_launches_tutorial and not GameState.tutorial_already_launched


func _can_interact() -> bool:
	return not _is_interacting and not _is_collected() and not _is_blocked_by_tutorial()


func _is_collected() -> bool:
	return GameState.is_plant_collected(_collection_id)


func _is_blocked_by_tutorial() -> bool:
	return not GameState.tutorial_already_launched and not plant_launches_tutorial


func _run_tutorial() -> bool:
	var tutorial_was_run: bool = await DialogueBalloonCoordinator.run_speaker_sequence(
		tutorial_dialogue,
		tutorial_dialogue_title,
		tutorial_speaker_id,
		global_position,
		hover_color,
		[self]
	)
	if tutorial_was_run:
		GameState.tutorial_already_launched = true
	return tutorial_was_run


func _get_minigame_coordinator() -> MinigameCoordinator:
	var coordinator := get_tree().get_first_node_in_group(&"minigame_coordinator") as MinigameCoordinator
	if coordinator:
		return coordinator

	var current_scene := get_tree().current_scene
	if current_scene:
		return current_scene.get_node_or_null("MinigameCoordinator") as MinigameCoordinator
	return null


func _get_collection_time_cost(difficulty_settings: Dictionary) -> float:
	if collection_time_cost_blocks >= 0.0:
		return collection_time_cost_blocks

	return float(difficulty_settings["time_cost_blocks"])


func _get_collection_miss_time_cost(difficulty_settings: Dictionary) -> float:
	if collection_miss_time_cost_blocks >= 0.0:
		return collection_miss_time_cost_blocks

	return float(difficulty_settings["miss_time_cost_blocks"])


func _fade_hover_to(target_alpha: float) -> void:
	if _hover_tween:
		_hover_tween.kill()

	_hover_tween = create_tween()
	_hover_tween.tween_property(hover_sprite, "modulate:a", target_alpha, hover_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_name_label_visible(should_show: bool) -> void:
	name_label.visible = should_show and not plant_display_name.is_empty()


func _get_localized_plant_display_name() -> String:
	if plant_display_name.is_empty():
		return ""

	return tr(plant_display_name)


func _make_hover_ignore_world_tint() -> void:
	# TODO: Unificar funcións aquí e en  npc.gd
	var hover_material := CanvasItemMaterial.new()
	hover_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	hover_sprite.material = hover_material
	name_label.material = hover_material


func _get_collection_id() -> StringName:
	if collection_id != &"":
		return collection_id

	var area_root := _get_area_root()
	if area_root:
		var area_path := area_root.scene_file_path
		if area_path.is_empty():
			area_path = str(area_root.get_path())

		return StringName("%s:%s" % [area_path, area_root.get_path_to(self)])

	return StringName(str(get_path()))


func _get_area_root() -> Node:
	var current := get_parent()
	while current:
		if not current.scene_file_path.is_empty():
			return current

		current = current.get_parent()

	return null
