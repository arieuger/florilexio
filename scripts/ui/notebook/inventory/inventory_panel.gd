extends Control
class_name InventoryPanel

@onready var left_grid: GridContainer = $LeftPageSlot/GridContainer
@onready var right_grid: GridContainer = $RightPageSlot/GridContainer
@onready var left_item_description: RichTextLabel = $LeftPageSlot/ItemDescription
@onready var right_item_description: RichTextLabel = $RightPageSlot/ItemDescription
var slots: Array[InventorySlot] = []

var _hover_tween: Tween
var _item_description_y: float

func _ready() -> void:
	_item_description_y = left_item_description.position.y
	for child in left_grid.get_children():
		if child is InventorySlot:
			child.hovered_slot_item.connect(_on_hovered_slot_item.bind(left_item_description))
			slots.append(child)

	for child in right_grid.get_children():
		if child is InventorySlot:
			child.hovered_slot_item.connect(_on_hovered_slot_item.bind(right_item_description))
			slots.append(child)

	InventoryManager.inventory_changed.connect(refresh)


func prepare_to_open() -> void:
	refresh()


func on_selected() -> void:
	pass


func refresh() -> void:
	for slot in slots:
		slot.clear()

	var inventory_items := InventoryManager.get_items()
	var item_ids := inventory_items.keys()
	var visible_count := mini(item_ids.size(), slots.size()) # TODO: Pensar que facer coa paxinación

	for index in range(visible_count):
		var item_id := StringName(item_ids[index])
		var item_data := ItemDatabase.get_item(item_id)

		if item_data == null:
			push_warning("InventoryPanel: unknown item id '%s'" % item_id)

		slots[index].setup(
			item_data,
			int(inventory_items[item_id])
		)


func _on_hovered_slot_item(item: ItemData, entered: bool, item_description: RichTextLabel) -> void:
	if _hover_tween:
		_hover_tween.kill()

	if entered:
		if item.description.is_empty():
			return

		item_description.text = item.description
		_hover_tween = UITweens.pop_tween(item_description, _item_description_y)

	else:
		_hover_tween = UITweens.hide_tween(item_description)