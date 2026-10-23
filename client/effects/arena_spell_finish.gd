class_name ArenaSpellFinish
extends RefCounted
const SHADER := preload("res://client/effects/shaders/spell_finish.gdshader")
static var _materials: Dictionary = {}
static func material(golden: bool = false) -> ShaderMaterial:
	if not _materials.has(golden):
		var value := ShaderMaterial.new()
		value.shader = SHADER
		value.set_shader_parameter("warmth", 1.0 if golden else 0.0)
		_materials[golden] = value
	return _materials[golden]
static func apply(sprite: AnimatedSprite2D, golden: bool = false) -> void:
	sprite.material = material(golden)

static func prewarm(tree: SceneTree) -> void:
	if DisplayServer.get_name() == "headless": return
	# Compile the shared shader during loading, not on the first combat impact.
	var image := Image.create_empty(1,1,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var preview := Sprite2D.new()
	preview.texture = ImageTexture.create_from_image(image)
	preview.material = material()
	preview.position = Vector2(1,1)
	preview.modulate.a = 0.02
	tree.root.add_child(preview)
	await tree.process_frame
	await RenderingServer.frame_post_draw
	preview.queue_free()
