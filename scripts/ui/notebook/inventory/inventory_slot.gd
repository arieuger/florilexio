@tool
extends Control
class_name InventorySlot

signal hovered(slot: InventorySlot)
signal unhovered(slot: InventorySlot)
# TODO: Fará falta selected/dragged?

@export var frame_texture: Texture2D:
	set(value):
		frame_texture = value
		if is_node_ready():
			update_frame()

@onready var frame: TextureRect = $Frame
@onready var icon: TextureRect = $Icon

var item = null

func _ready() -> void:
	update_frame()


func update_frame() -> void:
	if is_instance_valid(frame):
		frame.texture = frame_texture


func set_icon(texture: Texture2D) -> void:
	icon.texture = texture


func clear() -> void:
	item = null
	icon.texture = null
