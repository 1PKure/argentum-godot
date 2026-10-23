extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool,message: String) -> void:
	checks += 1
	if not value: failures+=1;push_error(message)
func _run() -> void:
	var hunter := ClassCatalog.get_profile(8)
	var minimum := SpellCatalog.direct_damage(51,ClassCatalog.magic_damage(70,1,8))
	var maximum := SpellCatalog.direct_damage(51,ClassCatalog.magic_damage(76,1,8))
	check(minimum==148 and maximum==161,"mage discharge uses 148-161 against actual hunter preset")
	check(maximum*3<int(hunter.max_health) and minimum*4>=int(hunter.max_health),"full-health hunter always survives three and dies to four discharges without recovery")
	var registry := PlayerRegistry.new()
	root.add_child(registry)
	var mage := registry.add_player(811)
	var target := registry.add_player(812)
	registry.try_select_class(812,8,0)
	for index in range(3):
		mage.current_mana = mage.max_mana
		var result := registry.try_cast_spell(811,51,target.grid_position,index+1,10000+index*1000)
		check(result.ok and target.is_alive,"real server discharge %d keeps hunter alive"%(index+1))
	mage.current_mana = mage.max_mana
	check(registry.try_cast_spell(811,51,target.grid_position,4,13000).ok and not target.is_alive,"fourth authoritative discharge defeats hunter")
	var cleric_before := roundi(70*2.5*(1+float(ClassCatalog.get_profile(2).magic_bonus)/100)*(1-float(hunter.resistance_percent)/100))
	check(ClassCatalog.magic_damage(70,2,8)==cleric_before,"caster-class adjustment leaves cleric damage unchanged")
	registry.queue_free()
	await process_frame
	print("Mage/hunter balance checks: %d; failures: %d"%[checks,failures])
	quit(1 if failures else 0)
