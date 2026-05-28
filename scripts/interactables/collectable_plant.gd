extends Node2D
class_name CollectablePlant

signal plant_selected(plant: CollectablePlant)
signal cutting_minigame_requested(plant_id: StringName, plant: CollectablePlant)

enum CuttingDifficulty { EASY, MEDIUM, HARD, TUTORIAL }

const CUTTING_DIFFICULTY_SETTINGS := {
	CuttingDifficulty.EASY: {
		"time_cost_blocks": 1.0,
		"miss_time_cost_blocks": 1,
		"base_rotation_speed_degrees": 300.0,
		"direction_change_chance": 0.6,
	},
	CuttingDifficulty.MEDIUM: {
		"time_cost_blocks": 1.0,
		"miss_time_cost_blocks": 1,
		"base_rotation_speed_degrees": 400.0,
		"direction_change_chance": 0.8,
	},
	CuttingDifficulty.HARD: {
		"time_cost_blocks": 2.0,
		"miss_time_cost_blocks": 1,
		"base_rotation_speed_degrees": 500.0,
		"direction_change_chance": 0.9,
	},
	CuttingDifficulty.TUTORIAL: {
		"time_cost_blocks": 1.0,
		"miss_time_cost_blocks": 1,
		"base_rotation_speed_degrees": 300.0,
		"direction_change_chance": 0,
	}
}

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

@export_group("Cutting Minigame")
@export var cutting_minigame_scene: PackedScene = preload("res://scenes/minigames/cutting_minigame.tscn")
@export_enum("Fácil", "Medio", "Difícil", "Tutorial") var cutting_difficulty: int = CuttingDifficulty.MEDIUM
## Negative values use the selected difficulty time cost.
@export var cutting_time_cost_blocks: float = -1.0
## Negative values use the selected difficulty miss time cost.
@export var cutting_miss_time_cost_blocks: float = -1.0
@export var cutting_required_hits: int = 3
@export var cutting_max_misses: int = 3
## 0 uses the selected difficulty base speed.
@export var cutting_rotation_speed_degrees: float = 0.0
@export_range(0.0, 1.0, 0.01) var cutting_success_alpha_threshold := 0.1
@export_group("")

@onready var hover_sprite: Sprite2D = $HoverSprite
@onready var name_label: Label = $NameLabel
@onready var click_area: Area2D = $ClickArea
@onready var interaction_point: Marker2D = get_node_or_null("InteractionPoint")

var _hover_tween: Tween
var _is_interacting := false
var _collection_id: StringName


func _ready() -> void:
	_collection_id = _get_collection_id()
	_make_hover_ignore_world_tint()
	hover_sprite.modulate = Color(hover_color.r, hover_color.g, hover_color.b, 0.0)
	name_label.text = plant_display_name
	name_label.visible = false
	click_area.input_pickable = not _is_collected()
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)
	click_area.input_event.connect(_on_input_event)


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
		if player and player.has_method("move_to_point"):
			var reached: bool = await player.move_to_point(interaction_point.global_position)
			if not reached:
				_is_interacting = false
				return

	if _should_launch_tutorial():
		var tutorial_was_run := await _run_tutorial()
		if not tutorial_was_run:
			_is_interacting = false
			return

	start_cutting_minigame()


func start_cutting_minigame() -> void:
	plant_selected.emit(self)
	cutting_minigame_requested.emit(plant_id, self)

	if not cutting_minigame_scene:
		_on_cutting_minigame_closed()
		return

	var minigame := cutting_minigame_scene.instantiate() as CuttingMinigame
	if not minigame:
		_on_cutting_minigame_closed()
		return

	var difficulty_settings := _get_cutting_difficulty_settings()
	minigame.plant_id = plant_id
	minigame.plant_display_name = plant_display_name
	minigame.time_cost_blocks = _get_cutting_time_cost(difficulty_settings)
	minigame.miss_time_cost_blocks = _get_cutting_miss_time_cost(difficulty_settings)
	minigame.required_hits = cutting_required_hits
	minigame.max_misses = cutting_max_misses
	minigame.rotation_speed_degrees = _get_cutting_rotation_speed(difficulty_settings)
	minigame.direction_change_chance = difficulty_settings["direction_change_chance"]
	minigame.success_alpha_threshold = cutting_success_alpha_threshold
	minigame.completed.connect(_on_cutting_minigame_completed)
	minigame.tree_exited.connect(_on_cutting_minigame_closed)
	get_tree().current_scene.add_child(minigame)


func _on_cutting_minigame_completed(_completed_plant_id: StringName) -> void:
	GameState.collect_plant(_collection_id)
	click_area.input_pickable = false
	_fade_hover_to(0.0)
	_set_name_label_visible(false)

	DialogueBalloonCoordinator.show_info_dialogue(
		"plant_collected",
		{"plant_name": plant_display_name},
		1.5
	)

func _on_cutting_minigame_closed() -> void:
	_is_interacting = false


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


func _get_cutting_difficulty_settings() -> Dictionary:
	return CUTTING_DIFFICULTY_SETTINGS.get(cutting_difficulty, CUTTING_DIFFICULTY_SETTINGS[CuttingDifficulty.MEDIUM])


func _get_cutting_time_cost(difficulty_settings: Dictionary) -> float:
	if cutting_time_cost_blocks >= 0.0:
		return cutting_time_cost_blocks

	return difficulty_settings["time_cost_blocks"]


func _get_cutting_miss_time_cost(difficulty_settings: Dictionary) -> float:
	if cutting_miss_time_cost_blocks >= 0.0:
		return cutting_miss_time_cost_blocks

	return difficulty_settings["miss_time_cost_blocks"]


func _get_cutting_rotation_speed(difficulty_settings: Dictionary) -> float:
	if cutting_rotation_speed_degrees > 0.0:
		return cutting_rotation_speed_degrees

	return difficulty_settings["base_rotation_speed_degrees"]


func _fade_hover_to(target_alpha: float) -> void:
	if _hover_tween:
		_hover_tween.kill()

	_hover_tween = create_tween()
	_hover_tween.tween_property(hover_sprite, "modulate:a", target_alpha, hover_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_name_label_visible(should_show: bool) -> void:
	name_label.visible = should_show and not plant_display_name.is_empty()


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
