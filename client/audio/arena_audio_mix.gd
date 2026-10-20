class_name ArenaAudioMix
extends RefCounted

const BUS := &"Combat"
const BUS_HEADROOM_DB := 0.0

static func configure() -> void:
	var bus := AudioServer.get_bus_index(BUS)
	if bus < 0:
		# Explicit insertion avoids Web's negative-index bus reorder path.
		AudioServer.add_bus(AudioServer.bus_count)
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus,BUS)
		AudioServer.set_bus_send(bus,&"Master")
	# Original source levels: no limiter, normalization, EQ or bus attenuation.
	AudioServer.set_bus_volume_db(bus,0.0)

static func route(player: Node, voices: int = 1) -> void:
	configure()
	player.set("bus",BUS)
	player.set("max_polyphony",clampi(voices,1,4))
	# Transport only; preserve predictable playback on single-threaded Web.
	player.set("playback_type",AudioServer.PLAYBACK_TYPE_STREAM)
