class_name ArenaFootstepAudio
extends RefCounted
const BASE_PATH := "res://assets/argentum/custom/audio/footstep_%s_%d.wav"
const MATERIALS := ["forest","desert","lava","duel_room"]
static var _streams: Dictionary = {}

static func stream_for(arena_id: String, variation: int) -> AudioStream:
	var material := arena_id if MATERIALS.has(arena_id) else "forest"
	var path := BASE_PATH % [material,posmod(variation,2) + 1]
	if not _streams.has(path): _streams[path] = load(path)
	return _streams[path]
