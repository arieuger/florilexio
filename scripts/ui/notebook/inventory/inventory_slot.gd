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
@onready var amount_label: RichTextLabel = $AmountLabel

var item = null

func _ready() -> void:
	update_frame()


func update_frame() -> void:
	if is_instance_valid(frame):
		frame.texture = frame_texture


func setup(item_data: ItemData, amount: int) -> void:
	item = item_data
	icon.texture = item_data.icon
	amount_label.text = "[b]%d[/b]" % amount
	amount_label.visible = amount > 1


func clear() -> void:
	item = null
	icon.texture = null
	amount_label.text = ""
	amount_label.visible = false
