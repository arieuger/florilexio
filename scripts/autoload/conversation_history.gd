extends Node

signal history_changed(conversation_id: StringName)
signal history_reloaded

const SAVE_VERSION := 1

const STATUS_STARTED := &"started"
const STATUS_FINISHED := &"finished"
const STATUS_INTERRUPTED := &"interrupted"

var _entries := {}

func _ready() -> void:
	DialogueBalloonCoordinator.conversation_started.connect(_on_conversation_started)
	DialogueBalloonCoordinator.conversation_finished.connect(_on_conversation_finished)
	DialogueBalloonCoordinator.conversation_interrupted.connect(_on_conversation_interrupted)

func has_started(conversation_id: StringName) -> bool:
	return get_started_count(conversation_id) > 0


func has_finished(conversation_id: StringName) -> bool:
	return get_finished_count(conversation_id) > 0

func has_been_interrupted(conversation_id: StringName) -> bool:
	var entry := _get_entry(conversation_id)
	return int(entry.get("interrupted_count", 0)) > 0


func get_started_count(conversation_id: StringName) -> int:
	var entry := _get_entry(conversation_id)
	return int(entry.get("started_count", 0))


func get_finished_count(conversation_id: StringName) -> int:
	var entry := _get_entry(conversation_id)
	return int(entry.get("finished_count", 0))


func get_interrupted_count(conversation_id: StringName) -> int:
	var entry := _get_entry(conversation_id)
	return int(entry.get("interrupted_count", 0))


func get_last_status(conversation_id: StringName) -> StringName:
	var entry := _get_entry(conversation_id)
	return StringName(entry.get("last_status", &""))


func get_last_interruption_reason(conversation_id: StringName) -> StringName:
	var entry := _get_entry(conversation_id)
	return StringName(entry.get("last_interruption_reason", &""))


func get_entry(conversation_id: StringName) -> Dictionary:
	return _get_entry(conversation_id).duplicate(true)


func export_state() -> Dictionary:
	var exported_conversations := {}

	for raw_conversation_id in _entries.keys():
		var conversation_id := StringName(raw_conversation_id)
		if conversation_id.is_empty():
			continue

		var entry := _get_entry(conversation_id)
		exported_conversations[str(conversation_id)] = {
			"started_count": max(0, int(entry.get("started_count", 0))),
			"finished_count": max(0, int(entry.get("finished_count", 0))),
			"interrupted_count": max(0, int(entry.get("interrupted_count", 0))),
			"last_status": str(entry.get("last_status", &"")),
			"last_interruption_reason": str(entry.get("last_interruption_reason", &"")),
		}

	return {
		"version": SAVE_VERSION,
		"conversations": exported_conversations,
	}


func import_state(data: Dictionary) -> bool:
	var version := int(data.get("version", -1))
	if version != SAVE_VERSION:
		push_warning("ConversationHistory: unsupported save version '%s'."% version)
		return false

	var raw_conversations: Variant = data.get("conversations", {})
	if not raw_conversations is Dictionary:
		push_warning("ConversationHistory: 'conversations' must be a Dictionary.")
		return false

	var imported_entries := {}

	for raw_conversation_id in raw_conversations.keys():
		var conversation_id := StringName(str(raw_conversation_id))
		if conversation_id.is_empty():
			continue

		var raw_entry: Variant = raw_conversations[raw_conversation_id]
		if not raw_entry is Dictionary:
			push_warning("ConversationHistory: invalid entry for '%s'."% conversation_id)
			continue

		var last_status := StringName(str(raw_entry.get("last_status", "")))
		if not _is_valid_status(last_status):
			push_warning("ConversationHistory: invalid status '%s' for '%s'."% [last_status, conversation_id,])
			last_status = &""

		imported_entries[conversation_id] = {
			"started_count": max(0, int(raw_entry.get("started_count", 0))),
			"finished_count": max(0, int(raw_entry.get("finished_count", 0))),
			"interrupted_count": max(0, int(raw_entry.get("interrupted_count", 0))),
			"last_status": last_status,
			"last_interruption_reason": StringName(str(raw_entry.get("last_interruption_reason", ""))),
		}

	_entries = imported_entries
	history_reloaded.emit()
	return true


func clear() -> void:
	if _entries.is_empty():
		return

	_entries.clear()
	history_reloaded.emit()


func _is_valid_status(status: StringName) -> bool:
	return status.is_empty() \
		or status == STATUS_STARTED \
		or status == STATUS_FINISHED \
		or status == STATUS_INTERRUPTED

func _on_conversation_started(conversation_id: StringName) -> void:
	var entry := _get_or_create_entry(conversation_id)
	entry["started_count"] = (int(entry["started_count"]) + 1)
	entry["last_status"] = STATUS_STARTED
	_entries[conversation_id] = entry
	history_changed.emit(conversation_id)


func _on_conversation_finished(conversation_id: StringName) -> void:
	var entry := _get_or_create_entry(conversation_id)
	entry["finished_count"] = (int(entry["finished_count"]) + 1)
	entry["last_status"] = STATUS_FINISHED
	entry["last_interruption_reason"] = &""
	_entries[conversation_id] = entry
	history_changed.emit(conversation_id)


func _on_conversation_interrupted(conversation_id: StringName, reason: StringName) -> void:
	var entry := _get_or_create_entry(conversation_id)
	entry["interrupted_count"] = (int(entry["interrupted_count"]) + 1)
	entry["last_status"] = STATUS_INTERRUPTED
	entry["last_interruption_reason"] = reason
	_entries[conversation_id] = entry
	history_changed.emit(conversation_id)


func _get_entry(conversation_id: StringName) -> Dictionary:
	var entry: Variant = _entries.get(conversation_id, {})
	return entry if entry is Dictionary else {}


func _get_or_create_entry(conversation_id: StringName) -> Dictionary:
	if _entries.has(conversation_id):
		return _get_entry(conversation_id)

	var entry := {
		"started_count": 0,
		"finished_count": 0,
		"interrupted_count": 0,
		"last_status": &"",
		"last_interruption_reason": &"",
	}
	_entries[conversation_id] = entry
	return entry
