extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var p := SkinProgress.new()
	p.storage_path = "user://class-progress-regression.cfg"
	DirAccess.remove_absolute(p.storage_path)
	p.restore()
	for id: int in ClassCatalog.all_ids():
		p.set_class(id)
		_check(p.wins == 0 and p.selected == "preset" and not p.select("explorer"), "Class %d begins independently locked" % id)
		for number in range(1,6):
			var result := p.award("class-%d-win-%d" % [id,number],id)
			_check(result.wins == number and result.class_id == id and not result.invite_other_class and result.unlocked == (["explorer"] if number == 1 else ["scarlet"] if number == 3 else ["light"] if number == 5 else []), "Class %d milestones unlock at their own 1/3/5 wins, without premature invitation" % id)
		var tier := "light" if id % 3 == 1 else "scarlet" if id % 3 == 2 else "explorer"
		_check(p.select(tier), "Class %d keeps its own equipped tier" % id)
		var extra := p.award("class-%d-win-6" % id,id)
		_check(extra.invite_other_class == (id != 12) and (int(extra.suggested_class_id) == 0 or p.wins_for_class(int(extra.suggested_class_id)) < 5), "Sixth victory suggests an incomplete class; never a completed collection")
		_check(extra.all_collections_complete == (id == 12), "All-complete feedback only appears after all nine collections are earned")
	p.set_class(8)
	_check(p.award("class-1-win-1",8).is_empty() and p.wins == 6 and p.award("invalid",9).is_empty(), "Duplicate round IDs cannot be reassigned to another class and invalid classes earn nothing")
	var result := p.award("delayed-mage-win",1)
	_check(p.class_id == 8 and p.wins == 6 and p.wins_for_class(1) == 7 and result.class_id == 1, "A delayed result credits the winning class without changing the active class")
	var restored := SkinProgress.new()
	restored.storage_path = p.storage_path
	restored.restore()
	for id: int in ClassCatalog.all_ids():
		var tier := "light" if id % 3 == 1 else "scarlet" if id % 3 == 2 else "explorer"
		_check(restored.wins_for_class(id) == (7 if id == 1 else 6) and restored.selection_for_class(id) == tier, "Disk reload preserves independent class %d counters and selection" % id)
	var registry = load("res://server/systems/player_registry.gd").new()
	root.add_child(registry)
	var owner: PlayerState = registry.add_player(111)
	_check(registry.try_select_skin(111,"light",5,1).ok,"Current-class cosmetic request is accepted")
	registry.try_select_class(111,8)
	_check(owner.skin_id == "preset" and not registry.try_select_skin(111,"light",5,1).ok and owner.skin_id == "preset", "Class switch clears old appearance and rejects a stale request for the previous class")
	var legacy := ConfigFile.new()
	legacy.set_value("skins","wins",5)
	legacy.set_value("skins","selected","light")
	legacy.set_value("skins","claimed",["old-round"])
	legacy.save(p.storage_path)
	p.restore()
	p.set_class(8)
	_check(p.wins == 0 and p.selected == "preset" and p.wins_for_class(1) == 5 and p.selection_for_class(1) == "light" and p.award("old-round",8).is_empty(), "Legacy global progress moves once to Mage without unlocking Hunter or replaying old rewards")
	p.award("new-hunter-round",8)
	p.restore()
	_check(p.wins_for_class(1) == 5 and p.wins_for_class(8) == 1, "Second restore does not repeat migration or overwrite new class progress")
	DirAccess.remove_absolute(p.storage_path)
	registry.queue_free()
	await process_frame
	print("Class progress checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+message)
