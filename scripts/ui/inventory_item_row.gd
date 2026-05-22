extends HBoxContainer

@onready var name_label: Label = $NameLabel
@onready var amount_label: Label = $AmountLabel


func setup(display_name: String, amount: int) -> void:
	# A TextureRect icon slot can be added before NameLabel later.
	name_label.text = display_name
	amount_label.text = "x" + str(amount)
