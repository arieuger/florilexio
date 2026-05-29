extends Node

const BOUQUET_PLANT_ID_KEY := &"plant_id"
const BOUQUET_MARKS_KEY := &"marks"
const MARK_IS_INVASIVE := &"is_invasive"
const MARK_IS_MAGIC := &"is_magic"


func calculate(bouquet_entries: Array[Dictionary]) -> Dictionary:
	var entries := bouquet_entries.duplicate(true)
	var plant_counts := {}
	var magic_count := 0
	var invasive_count := 0

	for entry in entries:
		var plant_id := StringName(entry.get(BOUQUET_PLANT_ID_KEY, &""))
		if plant_id == &"":
			continue

		plant_counts[plant_id] = int(plant_counts.get(plant_id, 0)) + 1
		var marks: Dictionary = entry.get(BOUQUET_MARKS_KEY, {})
		if bool(marks.get(MARK_IS_MAGIC, false)):
			magic_count += 1
		if bool(marks.get(MARK_IS_INVASIVE, false)):
			invasive_count += 1

	var total_count := entries.size()
	var unique_count := plant_counts.size()
	var duplicate_count := total_count - unique_count
	var has_traditional_size := total_count == 7 or total_count == 9
	var score := _calculate_score(
		total_count,
		unique_count,
		duplicate_count,
		magic_count,
		invasive_count,
		has_traditional_size
	)

	return {
		"entries": entries,
		"plant_counts": plant_counts,
		"total_count": total_count,
		"unique_count": unique_count,
		"duplicate_count": duplicate_count,
		"magic_count": magic_count,
		"invasive_count": invasive_count,
		"ordinary_count": maxi(total_count - magic_count - invasive_count, 0),
		"has_traditional_size": has_traditional_size,
		"score": score,
		"rank": _get_rank(score, total_count, invasive_count, has_traditional_size),
	}


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
	score: int,
	total_count: int,
	invasive_count: int,
	has_traditional_size: bool
) -> StringName:
	if total_count <= 0:
		return &"empty"
	if invasive_count > 0:
		return &"risky"
	if has_traditional_size and score >= 18:
		return &"excellent"
	if has_traditional_size:
		return &"traditional"
	if score >= 10:
		return &"complete"

	return &"incomplete"
