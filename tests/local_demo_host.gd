extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--demo-state-output="):
			output = argument.trim_prefix("--demo-state-output=")
	var session := root.get_node("LocalDemoSession")
	if output.is_empty() or not await session.start_session():
		quit(1)
		return
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"url": session.get_server_url()}))
	file.close()
	await create_timer(120).timeout
	quit()
