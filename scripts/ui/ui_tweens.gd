class_name UITweens

static func pop_tween(control: Control, base_y: float) -> Tween:
	var tween = control.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)

	control.show()
	control.modulate.a = 0.0
	control.position.y = base_y + 5.5
	control.rotation = 0.0

	tween.parallel().tween_property(
		control,
		"modulate:a",
		1.0,
		0.08
	)
	tween.parallel().tween_property(
		control,
		"position:y",
		base_y,
		0.08
	)
	tween.tween_property(
		control,
		"rotation_degrees",
		3.0,
		0.09
	)
	tween.tween_property(
		control,
		"rotation_degrees",
		0.0,
		0.1
	)

	return tween


static func hide_tween(control: Control) -> Tween:
	var tween = control.create_tween()
	tween.parallel().tween_property(
		control,
		"modulate:a",
		0.0,
		0.06
	)
	tween.tween_callback(control.hide)
	return tween