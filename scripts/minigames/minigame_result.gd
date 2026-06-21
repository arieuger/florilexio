extends RefCounted
class_name MinigameResult

const OUTCOME_SUCCESS := &"success"
const OUTCOME_FAILED := &"failed"
const OUTCOME_CANCELLED := &"cancelled"

var minigame_id: StringName = &""
var target_id: StringName = &""
var outcome: StringName = OUTCOME_FAILED

var success := false
var cancelled := false

var hits := 0
var misses := 0
var time_cost_blocks := 0.0
var miss_time_cost_blocks := 0.0

var rewards: Dictionary = {} # Así podemos incluír algún elemento extra máis que a planta
var metadata: Dictionary = {} # Para calquera outra cousa que se queira pasar, como por exemplo a información do minixogo en si


static func success_result(
	p_minigame_id: StringName,
	p_target_id: StringName,
	p_rewards: Dictionary = {},
	p_metadata: Dictionary = {}
) -> MinigameResult:
	var result := MinigameResult.new()
	result.minigame_id = p_minigame_id
	result.target_id = p_target_id
	result.outcome = OUTCOME_SUCCESS
	result.success = true
	result.cancelled = false
	result.rewards = p_rewards.duplicate(true)
	result.metadata = p_metadata.duplicate(true)
	return result


static func failed_result(
	p_minigame_id: StringName,
	p_target_id: StringName,
	p_rewards: Dictionary = {},
	p_metadata: Dictionary = {}
) -> MinigameResult:
	var result := MinigameResult.new()
	result.minigame_id = p_minigame_id
	result.target_id = p_target_id
	result.outcome = OUTCOME_FAILED
	result.success = false
	result.cancelled = false
	result.rewards = p_rewards.duplicate(true)
	result.metadata = p_metadata.duplicate(true)
	return result


static func cancelled_result(
	p_minigame_id: StringName,
	p_target_id: StringName,
	p_rewards: Dictionary = {},
	p_metadata: Dictionary = {}
) -> MinigameResult:
	var result := MinigameResult.new()
	result.minigame_id = p_minigame_id
	result.target_id = p_target_id
	result.outcome = OUTCOME_CANCELLED
	result.success = false
	result.cancelled = true
	result.rewards = p_rewards.duplicate(true)
	result.metadata = p_metadata.duplicate(true)
	return result


func get_total_time_cost_blocks() -> float:
    # TODO: Ver como xestionar os hits
	return time_cost_blocks + (miss_time_cost_blocks * misses)


func is_success() -> bool:
	return success and outcome == OUTCOME_SUCCESS


func is_failure() -> bool:
	return not success and not cancelled and outcome == OUTCOME_FAILED


func is_cancelled() -> bool:
	return cancelled or outcome == OUTCOME_CANCELLED
