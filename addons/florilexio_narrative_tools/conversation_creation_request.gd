@tool
class_name ConversationCreationRequest
extends RefCounted

var character: String
var arc: String
var purpose: String

var conversation_id: StringName
var dialogue_resource: DialogueResource
var start_title := "start"
var initial_speaker_id: StringName

var priority := 0
var repeatable := false
var fallback := false

var target_profile: DialogueProfile
var save_path: String