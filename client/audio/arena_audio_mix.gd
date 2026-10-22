class_name ArenaAudioMix
extends RefCounted

const BUS := &"Combat"
const FOOTSTEPS := &"Footsteps"
const BUS_HEADROOM_DB := -3.0
const OUTPUT_CEILING_DB := -1.0
const SETTINGS_PATH := "user://audio_settings_v1.cfg"
const DEFAULTS := {"master":100.0,"effects":100.0,"footsteps":85.0}
static var _levels: Dictionary = {}
static var _platform_web := OS.has_feature("web")
static var _web_players: Dictionary = {}
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
	if _platform_web: return # Browser samples bypass unsupported Godot DSP.
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
	for key in _web_players.keys():
		var player = _web_players[key].get_ref()
		if player == null: _web_players.erase(key)
		else: _apply_web_gain(player)
	var config := ConfigFile.new()
	for key: String in DEFAULTS: config.set_value("volume",key,_levels[key])
	return config.save(_settings_path)

static func route(player: Node, voices: int = 1, bus: StringName = BUS) -> void:
	configure()
	player.set("max_polyphony",clampi(voices,1,4))
	if _platform_web:
		if not player.has_meta("source_gain_db"):
			player.set_meta("source_gain_db",float(player.get("volume_db")))
			var id := player.get_instance_id()
			player.tree_exiting.connect(func() -> void: _web_players.erase(id))
		player.set_meta("logical_audio_bus",bus)
		player.set("bus",&"Master")
		player.set("playback_type",AudioServer.PLAYBACK_TYPE_SAMPLE)
		_web_players[player.get_instance_id()] = weakref(player)
		_apply_web_gain(player)
	else:
		player.set("bus",bus)
		player.set("playback_type",AudioServer.PLAYBACK_TYPE_STREAM)

static func _apply_web_gain(player: Node) -> void:
	var gain := float(_levels.effects)/100.0
	if player.get_meta("logical_audio_bus",BUS)==FOOTSTEPS: gain *= float(_levels.footsteps)/100.0
	player.set("volume_db",float(player.get_meta("source_gain_db",0))+BUS_HEADROOM_DB+linear_to_db(maxf(gain,0.00001)))
