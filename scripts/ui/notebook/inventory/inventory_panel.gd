extends Control
class_name InventoryPanel

@onready var left_grid: GridContainer = $LeftPageSlot/GridContainer
@onready var right_grid: GridContainer = $RightPageSlot/GridContainer

var slots: Array[InventorySlot] = []

func _ready() -> void:
	for child in left_grid.get_children():
		if child is InventorySlot:
			slots.append(child)

	for child in right_grid.get_children():
		if child is InventorySlot:
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