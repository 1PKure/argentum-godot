class_name ArenaVisualSettings
extends RefCounted
## Rendering preference only; never sent to the authoritative server.
const PATH := "user://visual_settings_v1.cfg"
static var _loaded := false
static var _original := false
static var metrics := false
static func default_original(web: bool) -> bool: return web
static func uses_original_fx() -> bool:
	if not _loaded:
		_loaded = true
		_original = default_original(OS.has_feature("web"))
		metrics = false
		var config := ConfigFile.new()
		if config.load(PATH) == OK:
			var choice: Variant = config.get_value("visual", "original_fx", _original)
			if choice is bool: _original = choice
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--fx-original": return true
		if argument == "--fx-modern": return false
	return _original
static func set_original_fx(original: bool) -> Error:
	uses_original_fx()
	_original = original
	var config := ConfigFile.new()
	config.set_value("visual", "original_fx", original)
	return config.save(PATH)
