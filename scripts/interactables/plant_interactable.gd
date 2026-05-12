extends Area2D

@export var plant_data: PlantData

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

var player_near := false
var collected := false

func _ready() -> void:
	label.visible = false
	
	if plant_data and plant_data.sprite:
		sprite.texture = plant_data.sprite

func _process(_delta: float) -> void:
	if player_near and Input.is_action_just_pressed("interact"):
		interact()

func interact() -> void:
	if not plant_data:
		return
	
	if collected:
		print("Esta planta xa foi recollida.")
		return
	
	# TODO: Collect despois de minixogo
	collected = GameState.collect_plant(plant_data.id)
	label.visible = false
	
	# Temporal: ocultamos la planta al recogerla
	visible = false
	set_process(false)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not collected:
		player_near = true
		label.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_near = false
		label.visible = false