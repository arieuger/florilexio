class_name ConversationContext
extends RefCounted

var requester: Node
var current_scene: Node

static func create(requester_node: Node, scene_node: Node) -> ConversationContext:
	var context := ConversationContext.new()
	context.requester = requester_node
	context.current_scene = scene_node
	return context
