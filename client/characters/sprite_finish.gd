class_name ArenaSpriteFinish
extends RefCounted

const SHADER := preload("res://client/characters/shaders/sprite_finish.gdshader")

static func apply(sprite: CanvasItem, texture: Texture2D, strength: float = 0.18) -> void:
	if texture == null: return
	var material := sprite.material as ShaderMaterial
	if material == null or material.shader != SHADER:
		material = ShaderMaterial.new()
		material.shader = SHADER
		sprite.material = material
	var bounds := Vector4(0,0,1,1)
	if texture is AtlasTexture:
		var size := Vector2(texture.atlas.get_size())
		var region: Rect2 = texture.region
		bounds = Vector4(region.position.x/size.x,region.position.y/size.y,region.end.x/size.x,region.end.y/size.y)
	material.set_shader_parameter("atlas_bounds",bounds)
	material.set_shader_parameter("finish_strength",strength)
