extends SceneTree


func _initialize() -> void:
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--license-output="):
			output = argument.trim_prefix("--license-output=")
	if output.is_empty():
		quit(1)
		return
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({
		"engine": "Godot " + Engine.get_version_info()["string"],
		"engine_license": Engine.get_license_text(),
		"third_party_copyrights": Engine.get_copyright_info(),
		"third_party_licenses": Engine.get_license_info(),
	}, "\t") + "\n")
	file.close()
	quit()
