extends Node

# SOUNDS
func play_simple_sound(soundPath: StringName) -> void:
	var instance = FmodServer.create_event_instance("event:/" + soundPath)
	instance.start()
	instance.release()

func play_looped_sound(soundPath: StringName) -> FmodEvent:
	var instance = FmodServer.create_event_instance("event:/" + soundPath)
	instance.start()
	return instance
	
func stop_looped_sound(instance: FmodEvent) -> void:
	if instance != null:
		instance.paused = true
		instance.release()
