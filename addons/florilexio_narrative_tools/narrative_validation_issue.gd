class_name NarrativeValidationIssue
extends RefCounted

enum Severity {
	INFO,
	WARNING,
	ERROR,
}

var severity: Severity = Severity.INFO
var code: StringName
var message: String
var resource_path: String
var related_id: StringName


func _init(
	initial_severity: Severity = Severity.INFO,
	initial_code: StringName = &"",
	initial_message: String = "",
	initial_resource_path: String = "",
	initial_related_id: StringName = &""
) -> void:
	severity = initial_severity
	code = initial_code
	message = initial_message
	resource_path = initial_resource_path
	related_id = initial_related_id


func get_severity_name() -> String:
	return Severity.keys()[severity]


func is_error() -> bool:
	return severity == Severity.ERROR


func is_warning() -> bool:
	return severity == Severity.WARNING


func _to_string() -> String:
	var location := resource_path

	if not related_id.is_empty():
		location += " [%s]" % related_id

	if location.is_empty():
		return "[%s] %s: %s" % [get_severity_name(), code, message]

	return "[%s] %s: %s — %s" % [get_severity_name(), code, message, location]