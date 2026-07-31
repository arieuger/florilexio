@tool
extends EditorScript

func _run() -> void:
	var index := NarrativeIndex.build()
	var issues := NarrativeValidator.new().validate_project(index)

	print("\n=== Florilexio Narrative Validation ===\n", index.get_summary())

	if issues.is_empty():
		print("Validation completed without issues.")
		return

	var error_count := 0
	var warning_count := 0
	var info_count := 0

	for issue in issues:
		print(issue)
		match issue.severity:
			NarrativeValidationIssue.Severity.ERROR:
				error_count += 1
			NarrativeValidationIssue.Severity.WARNING:
				warning_count += 1
			NarrativeValidationIssue.Severity.INFO:
				info_count += 1

	print("Validation completed: %d error(s), %d warning(s), %d info message(s)."
		% [error_count, warning_count, info_count]
	)
