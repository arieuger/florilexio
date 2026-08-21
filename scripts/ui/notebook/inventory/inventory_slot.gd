@tool
extends Control
class_name InventorySlot

@export var frame_texture: Texture2D:
	set(value):
		frame_texture = value
		if is_node_ready():
			update_frame()

@onready var frame: TextureRect = $Frame
@onready var icon: TextureRect = $Icon
@onready var amount_label: RichTextLabel = $AmountLabel
@onready var name_tag: NinePatchRect = $NameTag
@onready var name_label: RichTextLabel = $NameTag/Label

var item = null

func _ready() -> void:
	mouse_entered.connect(_on_hovered.bind(true))
	mouse_exited.connect(_on_hovered.bind(false))
	update_frame()


func update_frame() -> void:
	if is_instance_valid(frame):
		frame.texture = frame_texture


func setup(item_data: ItemData, amount: int) -> void:
	item = item_data
	icon.texture = item_data.icon
	amount_label.text = "[b]%d[/b]" % amount
	amount_label.visible = amount > 1
	_set_name_tag(item.display_name)


func clear() -> void:
	item = null
	icon.texture = null
	amount_label.text = ""
	amount_label.visible = false


func _set_name_tag(text: String) -> void:
	name_label.text = text

	await get_tree().process_frame

	var tag_width := maxf(name_label.get_content_width() + 5.0, 22.0)
	var half_width := tag_width / 2.0

	name_tag.offset_left = - half_width
	name_tag.offset_right = half_width


func _on_hovered(entered: bool) -> void:
	name_tag.visible = item != null and entered
