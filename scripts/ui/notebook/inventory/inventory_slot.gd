@tool
extends Control
class_name InventorySlot

signal hovered_slot_item(item: ItemData, entered: bool)

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

var _item = null
var _hover_tween: Tween

var _name_tag_y: float

func _ready() -> void:
	mouse_entered.connect(_on_hovered.bind(true))
	mouse_exited.connect(_on_hovered.bind(false))
	_name_tag_y = name_tag.position.y
	name_tag.hide()
	update_frame()


func update_frame() -> void:
	if is_instance_valid(frame):
		frame.texture = frame_texture


func setup(item_data: ItemData, amount: int) -> void:
	_item = item_data
	icon.texture = item_data.icon
	amount_label.text = "[b]%d[/b]" % amount
	amount_label.visible = amount > 1
	_set_name_tag(_item.display_name)


func clear() -> void:
	_item = null
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
	if _item == null:
		return

	if _hover_tween:
		_hover_tween.kill()

	if entered:
		_hover_tween = UITweens.pop_tween(name_tag, _name_tag_y)
		var current_tween = _hover_tween # con esto o await non bloquea futuros tweens que se pisen
		await get_tree().create_timer(0.2).timeout
		if current_tween != _hover_tween:
			return
	else:
		_hover_tween = UITweens.hide_tween(name_tag)

	hovered_slot_item.emit(_item, entered)
