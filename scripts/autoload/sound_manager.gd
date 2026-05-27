extends Node

# SOUNDS
func play_simple_sound(soundPath: StringName) -> void:
	var instance = FmodServer.create_event_instance("event:/" + soundPath)
	instance.start()
	instance.release()
