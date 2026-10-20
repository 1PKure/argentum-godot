class_name ArenaFootstepAudio
extends RefCounted
## Exact AO20 source WAVs. IDs are verified against Recursos.bas:CargarPasos.
const BASE_PATH := "res://assets/argentum/source/audio/%d.wav"
const MATERIALS := ["forest","desert","lava","duel_room"]
const SOUNDS := {"forest":[201,69],"desert":[197,198],"lava":[23,24],"duel_room":[23,24]}
const VARIATIONS := 2
const MIN_CONTACT_INTERVAL_MSEC := 225
static var _streams: Dictionary = {}
static var _patterns: Dictionary = {}

static func stream_for(arena_id: String, variation: int) -> AudioStream:
	var material := arena_id if MATERIALS.has(arena_id) else "forest"
	var path := BASE_PATH % SOUNDS[material][posmod(variation,VARIATIONS)]
	if not _streams.has(path): _streams[path] = load(path)
	return _streams[path]

static func pattern_for(arena_id: String) -> AudioStreamRandomizer:
	var material := arena_id if MATERIALS.has(arena_id) else "forest"
	if not _patterns.has(material):
		var pattern := AudioStreamRandomizer.new()
		pattern.playback_mode = AudioStreamRandomizer.PLAYBACK_SEQUENTIAL
		pattern.random_pitch = 1.0
		pattern.random_volume_offset_db = 0.0
		for variation in range(VARIATIONS): pattern.add_stream(-1,stream_for(material,variation))
		_patterns[material] = pattern
	return _patterns[material]
