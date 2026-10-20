class_name ArenaAudioMix
extends RefCounted

const BUS := &"Combat"
const FOOTSTEPS := &"Footsteps"
const BUS_HEADROOM_DB := -3.0
const OUTPUT_CEILING_DB := -1.0
const SETTINGS_PATH := "user://audio_settings_v1.cfg"
const DEFAULTS := {"master":100.0,"effects":100.0,"footsteps":70.0}
static var _levels: Dictionary = {}
static var _settings_path := SETTINGS_PATH

static func configure() -> void:
	if _levels.is_empty():
		_levels = DEFAULTS.duplicate()
		var config := ConfigFile.new()
		if config.load(_settings_path) == OK:
			for key: String in DEFAULTS:
				var value: Variant = config.get_value("volume",key,DEFAULTS[key])
				if (value is float or value is int) and is_finite(float(value)): _levels[key] = clampf(float(value),0,100)
	var bus := _ensure_bus(BUS,&"Master")
	var steps := _ensure_bus(FOOTSTEPS,BUS)
	_apply_level(AudioServer.get_bus_index(&"Master"),float(_levels.master),0)
	_apply_level(bus,float(_levels.effects),BUS_HEADROOM_DB)
	_apply_level(steps,float(_levels.footsteps),0)
	var master := AudioServer.get_bus_index(&"Master")
	for index in range(AudioServer.get_bus_effect_count(master)):
		if AudioServer.get_bus_effect(master,index) is AudioEffectHardLimiter: return
	var limiter := AudioEffectHardLimiter.new()
	limiter.pre_gain_db = 0.0
	limiter.ceiling_db = OUTPUT_CEILING_DB
	limiter.release = 0.10
	AudioServer.add_bus_effect(master,limiter)

static func _ensure_bus(name: StringName, send: StringName) -> int:
	var index := AudioServer.get_bus_index(name)
	if index < 0:
		AudioServer.add_bus(AudioServer.bus_count)
		index = AudioServer.bus_count-1
		AudioServer.set_bus_name(index,name)
	AudioServer.set_bus_send(index,send)
	return index

static func _apply_level(bus: int, value: float, base_db: float) -> void:
	AudioServer.set_bus_mute(bus,value<=0)
	AudioServer.set_bus_volume_db(bus,base_db+linear_to_db(maxf(0.0001,value/100.0)))

static func volume(channel: String) -> float:
	configure()
	return float(_levels.get(channel,100))

static func set_volume(channel: String, value: float) -> Error:
	if not DEFAULTS.has(channel) or not is_finite(value): return ERR_INVALID_PARAMETER
	configure()
	_levels[channel] = clampf(value,0,100)
	configure()
	var config := ConfigFile.new()
	for key: String in DEFAULTS: config.set_value("volume",key,_levels[key])
	return config.save(_settings_path)

static func route(player: Node, voices: int = 1, bus: StringName = BUS) -> void:
	configure()
	player.set("bus",bus)
	player.set("max_polyphony",clampi(voices,1,4))
	player.set("playback_type",AudioServer.PLAYBACK_TYPE_STREAM)
