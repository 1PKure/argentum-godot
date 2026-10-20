class_name ArenaFootstepAudio
extends RefCounted
const BASE_PATH := "res://assets/argentum/custom/audio/footstep_%s_%d.wav"
const MATERIALS := ["forest","desert","lava","duel_room"]
const VARIATIONS := 4
const MIN_CONTACT_INTERVAL_MSEC := 225
static var _streams: Dictionary = {}
static var _patterns: Dictionary = {}

static func stream_for(arena_id: String, variation: int) -> AudioStream:
	var material := arena_id if MATERIALS.has(arena_id) else "forest"
	var path := BASE_PATH % [material,posmod(variation,VARIATIONS) + 1]
	if not _streams.has(path): _streams[path] = load(path)
	return _streams[path]

static func pattern_for(arena_id: String) -> AudioStreamRandomizer:
	var material := arena_id if MATERIALS.has(arena_id) else "forest"
	if not _patterns.has(material):
		var pattern := AudioStreamRandomizer.new()
		pattern.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
		pattern.random_pitch = 1.025
		pattern.random_volume_offset_db = 1.0
		for variation in range(VARIATIONS): pattern.add_stream(-1,stream_for(material,variation))
		_patterns[material] = pattern
	return _patterns[material]
