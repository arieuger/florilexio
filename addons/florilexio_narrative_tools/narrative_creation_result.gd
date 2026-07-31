@tool
class_name NarrativeCreationResult
extends RefCounted

var success := false
var error_message: String
var resource_path: String

var conversation: ConversationDefinition
var entry: ConversationEntry