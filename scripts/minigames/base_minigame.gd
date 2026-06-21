extends CanvasLayer
class_name BaseMinigame

signal finished(result: MinigameResult)
signal time_cost_requested(time_cost_blocks: float)

var context: MinigameContext
var is_finished := false


func setup(new_context: MinigameContext) -> void:
	context = new_context


func cancel() -> void:
	pass


func emit_finished(result: MinigameResult) -> void:
	if is_finished:
		return

	is_finished = true
	finished.emit(result)


func request_time_cost(time_cost_blocks: float) -> void:
	if time_cost_blocks <= 0.0:
		return

	time_cost_requested.emit(time_cost_blocks)
