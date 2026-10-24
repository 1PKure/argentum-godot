class_name ArenaBakedSpellAtlas
extends RefCounted
## Shared pre-rendered textures/frames; each live cast owns its playback cursor.
const MANIFEST := "res://client/effects/modern_atlas/manifest.json"
static var _entries: Dictionary = {}
static var _frames: Dictionary = {}
static func entry(id: int) -> Dictionary:
 if _entries.is_empty():
  var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
  if data is Dictionary: _entries = data.spells
 return _entries.get(str(id),{})
static func frames(id: int) -> SpriteFrames:
 if _frames.has(id):return _frames[id]
 var data:=entry(id)
 if data.is_empty():return null
 var texture:=load(str(data.file)) as Texture2D
 if texture==null:return null
 var value:=SpriteFrames.new();value.set_animation_speed("default",24);value.set_animation_loop("default",false)
 var size:=Vector2(data.size[0],data.size[1])
 for index in range(int(data.count)):
  var region:=AtlasTexture.new();region.atlas=texture
  region.region=Rect2(Vector2(index%8,index/8)*size,size)
  value.add_frame("default",region)
 _frames[id]=value
 return value
static func prewarm(tree: SceneTree)->void:
 for id:int in ArenaSpellVisual.CONCEPTS:
  if not _frames.has(id) and not entry(id).is_empty():
   frames(id)
   await tree.process_frame

 ArenaMeditationVisual.modern_frames() # Warm the shared gold loop before combat.
