extends SceneTree
class HitRegistry extends PlayerRegistry:
 var outcome:="hit"
 func _roll_physical_outcome(_target:PlayerState)->String:return outcome
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("FAIL: ",label)
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var registry:=HitRegistry.new();root.add_child(registry)
 var actor:=registry.add_player(901);var target:=registry.add_player(902)
 registry.try_select_class(901,4,0)
 actor.grid_position=Vector2i(5,5);actor.facing_direction=MovementRules.Direction.EAST
 target.grid_position=Vector2i(6,5);target.max_health=1000000;target.current_health=1000000
 for direction:int in range(4):
  var at:=target.grid_position-MovementRules.get_offset(direction)
  check(CombatRules.is_behind(at,target.grid_position,direction),"Rear uses victim authoritative facing%d"%direction)
  check(not CombatRules.is_behind(target.grid_position+MovementRules.get_offset(direction),target.grid_position,direction),"Front is never a rear attack%d"%direction)
 check(CombatRules.stab_chance(1,126,actor.grid_position,target.grid_position,1)==0,"Non-assassins cannot stab")
 check(CombatRules.stab_chance(4,0,actor.grid_position,target.grid_position,1)==0,"Unequipped assassin cannot stab")
 var events:Array[Dictionary]=[];registry.basic_attack_resolved.connect(func(event:Dictionary)->void:events.append(event))
 var clock:=10000
 var counts:Array[int]=[]
 for rear:bool in [false,true]:
  target.facing_direction=MovementRules.Direction.EAST if rear else MovementRules.Direction.WEST
  registry._physical_rng.seed=2341
  var stabbed:=0;var legal:=true
  for i in range(600):
   var before:=target.current_health
   var hit:=registry.try_basic_attack(901,clock)
   var event:Dictionary=events[-1]
   legal=legal and hit==target and before-target.current_health==int(event.amount)
   if event.stabbed:
    stabbed+=1
    legal=legal and bool(event.rear_attack)==rear
   var hp:=target.current_health;var size:=events.size()
   legal=legal and registry.try_basic_attack(901,clock+1199)==null and hp==target.current_health and events.size()==size
   clock+=1200
  counts.append(stabbed)
  check(legal,"Stab damage and shared melee cooldown are authoritative, rear=%s"%rear)
 check(counts[0]>=25 and counts[0]<=75 and counts[1]>=130 and counts[1]<=205,"Seeded actual hits show low normal and higher rear chance: %s"%str(counts))
 # Identical physical RNG produces identical base damage; only the proc adds damage.
 var bonus:=false
 for seed_value in range(100):
  target.facing_direction=MovementRules.Direction.EAST
  registry._physical_rng.seed=seed_value
  registry.try_basic_attack(901,clock);clock+=1200
  var first:Dictionary=events[-1]
  target.facing_direction=MovementRules.Direction.WEST
  registry._physical_rng.seed=seed_value
  registry.try_basic_attack(901,clock);clock+=1200
  var second:Dictionary=events[-1]
  if first.stabbed and not second.stabbed:
   bonus=int(first.amount)==roundi(int(second.amount)*1.35);break
 check(bonus,"Rear proc adds exactly35% to the same rolled physical damage")
 for avoided:String in ["evaded","blocked"]:
  registry.outcome=avoided
  registry.try_basic_attack(901,clock);clock+=1200
  check(not events[-1].stabbed and int(events[-1].amount)==0,"Stab never bypasses "+avoided)
 registry.queue_free();await process_frame
 print("Assassin checks: %d; failures: %d"%[checks,failures]);quit(1 if failures else 0)
