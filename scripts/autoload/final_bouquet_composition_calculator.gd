extends Node

func calculate(bouquet_entries: Array[Dictionary]) -> Dictionary:
	var entries := bouquet_entries.duplicate(true)
	var plant_counts := {}
	var total_count := 0
	var magic_count := 0
	var invasive_count := 0
	var some_mortal := false

	for entry in entries:
		var plant_id := StringName(entry.get(InventoryManager.BOUQUET_PLANT_ID_KEY, &""))
		if plant_id == &"":
			continue

		total_count += 1
		plant_counts[plant_id] = int(plant_counts.get(plant_id, 0)) + 1
		var marks: Dictionary = entry.get(InventoryManager.BOUQUET_MARKS_KEY, {})
		if bool(marks.get(InventoryManager.MARK_IS_MAGIC, false)):
			magic_count += 1
		if bool(marks.get(InventoryManager.MARK_IS_INVASIVE, false)):
			invasive_count += 1
		if bool(marks.get(InventoryManager.MARK_IS_MORTAL, false)):
			some_mortal = true

	var unique_count := plant_counts.size()
	var duplicate_count := total_count - unique_count
	var has_traditional_size := total_count == 7 or total_count == 9

	return {
		"mortal": some_mortal,
		"invasive": invasive_count,
		"magic": magic_count,
		"rank": _get_rank(some_mortal, total_count, invasive_count, magic_count, has_traditional_size, duplicate_count),
		"player_removed_invasors": GameState.discarded_invasive_plants_count >= 3
	}


# TODO: útil a futuro
func _calculate_score(
	total_count: int,
	unique_count: int,
	duplicate_count: int,
	magic_count: int,
	invasive_count: int,
	has_traditional_size: bool
) -> int:
	if total_count <= 0:
		return 0

	var score := total_count + unique_count + magic_count
	if has_traditional_size:
		score += 5

	score -= duplicate_count
	score -= invasive_count * 3
	return maxi(score, 0)


func _get_rank(
	some_mortal: bool,
	total_count: int,
	invasive_count: int,
	magic_count: int,
	has_traditional_size: bool,
	duplicate_count: int
) -> StringName:
	if some_mortal:
		return &"mortal"
	if total_count <= 0:
		return &"empty"
	if invasive_count > 0:
		return &"invader"
	if has_traditional_size and magic_count == total_count and duplicate_count == 0:
		return &"traditional"
	if total_count > 7:
		return &"too_big"
	if total_count < 7:
		return &"too_small"
	
	return &"mediocre"
