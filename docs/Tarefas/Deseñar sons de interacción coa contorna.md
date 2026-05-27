---
tipo: son
responsable: poch
---
## Subtarefas

- [ ] Camiñar
	- [ ] Zapato xenérico
	      https://freesound.org/people/kyles/sounds/637555/
	- [ ] Cemento
	      https://freesound.org/people/camdenavenue/sounds/851346/
	      https://freesound.org/people/Subby-Spaced/sounds/849321/
	      https://freesound.org/people/NachtmahrTV/sounds/571802/
	- [ ] Asfalto
	      https://freesound.org/people/Gasdust_cloud/sounds/851919/
	- [ ] Grava
	      https://freesound.org/people/ser%C3%B8ut%C5%8Dnin--depriv%C9%99d/sounds/854495/
	      https://freesound.org/people/MarcProoo/sounds/853545/
	      https://freesound.org/people/SiliconeSound/sounds/848249/
	- [ ] Herba
	      https://freesound.org/people/outoftheboxcm/sounds/846017/
	      https://freesound.org/people/samdom/sounds/843890/
	- [ ] Madeira
	      https://freesound.org/people/loucas_st_jacques/sounds/850809/
	      https://freesound.org/people/Marley_W/sounds/852287/
	      https://freesound.org/people/JoanCalsina/sounds/851223/
	      https://freesound.org/people/onursamli/sounds/846921/
	- [ ] Area
	      https://freesound.org/people/thesynesthiser/sounds/852214/
- [ ] Encontrar herba


> # Sounds
> const MIN_STEP_GAP := 0.25  # segundos mínimos entre pasos
> const STEP_INTERVAL := 1.5
> var last_step_time := 0.0
> var step_distance := 0.0
> 
> func play_footstep(delta):
> 	if velocity.length() > 10.0:
> 		step_distance += velocity.length() * delta
> 		if step_distance >= STEP_INTERVAL:
> 			step_distance = fmod(step_distance, STEP_INTERVAL)
> 			play_footstep_sound()
> 	else:
> 		step_distance = 0.0  # reset ao parar
> 
> func play_footstep_sound():
> 	var now = Time.get_ticks_msec() / 1000.0
> 	if now - last_step_time < MIN_STEP_GAP:
> 		return
> 	last_step_time = now
> 	
> 	FmodServer.set_global_parameter_by_name("GroundType", 0.0)
> 	var instance = FmodServer.create_event_instance("event:/Player/Steps")
> 	instance.start()
> 	instance.release()