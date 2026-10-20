class_name ArenaAudioMix
extends RefCounted

const BUS := &"Combat"
const BUS_HEADROOM_DB := -3.0
const OUTPUT_CEILING_DB := -1.0

static func configure() -> void:
	var bus := AudioServer.get_bus_index(BUS)
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus,BUS)
		AudioServer.set_bus_send(bus,&"Master")
	AudioServer.set_bus_volume_db(bus,BUS_HEADROOM_DB)
	var master := AudioServer.get_bus_index(&"Master")
	for index in range(AudioServer.get_bus_effect_count(master)):
		if AudioServer.get_bus_effect(master,index) is AudioEffectHardLimiter: return
	# Transparent peak protection for overlapping spell tails and impacts.
	# Never normalize/boost a source, clip its waveform or change playback speed.
	var limiter := AudioEffectHardLimiter.new()
	limiter.pre_gain_db = 0.0
	limiter.ceiling_db = OUTPUT_CEILING_DB
	limiter.release = 0.10
	AudioServer.add_bus_effect(master,limiter)

static func route(player: Node) -> void:
	configure()
	player.set("bus",BUS)
	player.set("max_polyphony",1)
