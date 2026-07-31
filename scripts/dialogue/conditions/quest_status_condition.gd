@tool
class_name QuestStatusCondition
extends ConversationCondition

@export var quest_id: StringName
@export var expected_status: QuestState.Status = QuestState.Status.ACTIVE

func is_met(_context: ConversationContext) -> bool:
	if quest_id.is_empty():
		return false

	match expected_status:
		QuestState.Status.INACTIVE:
			return QuestManager.is_inactive(quest_id)
		QuestState.Status.ACTIVE:
			return QuestManager.is_active(quest_id)
		QuestState.Status.COMPLETED:
			return QuestManager.is_completed(quest_id)
		QuestState.Status.FAILED:
			return QuestManager.is_failed(quest_id)

	return false

func get_debug_description() -> String:
	return "Quest '%s' status == %s"% [quest_id, QuestState.Status.keys()[expected_status]]