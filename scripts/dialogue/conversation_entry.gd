class_name ConversationEntry
extends Resource


@export var conversation: ConversationDefinition
@export var priority: int = 0
@export var repeatable := false
@export var is_fallback := false
@export var conditions: Array[ConversationCondition] = []
