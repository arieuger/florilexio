@tool
class_name ConversationCreationRequest
extends RefCounted

var conversation_id: StringName
var dialogue_resource: DialogueResource
var start_title := "start"
var initial_speaker_id: StringName

var priority := 0
var repeatable := false
var fallback := false
var conditions: Array[ConversationCondition] = []

var target_profile: DialogueProfile
var save_path: String
