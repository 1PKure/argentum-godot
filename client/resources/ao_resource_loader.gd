class_name AOResourceLoader
extends Node

const DATA_PATH := (
	"res://assets/argentum/source/data/"
)

const GRAPHICS_PATH := (
	"res://assets/argentum/source/graphics/"
)

const BODY_DIRECTIONS := [
	"down",
	"up",
	"left",
	"right"
]

const HEAD_DIRECTION_KEYS := {
	"up": "Head1",
	"right": "Head2",
	"down": "Head3",
	"left": "Head4"
}

var _graphics: Dictionary = {}
var _bodies: Dictionary = {}
var _molds: Dictionary = {}
var _heads: Dictionary = {}

var _texture_cache: Dictionary = {}

var _is_loaded := false


func _ready() -> void:
	load_database()


func load_database() -> void:
	if _is_loaded:
		return

	_graphics = _parse_ini_like_file(
		DATA_PATH + "graficos.ini"
	)

	_bodies = _parse_ini_like_file(
		DATA_PATH + "cuerpos.dat"
	)

	_molds = _parse_ini_like_file(
		DATA_PATH + "moldes.ini"
	)

	_heads = _parse_ini_like_file(
		DATA_PATH + "cabezas.ini"
	)

	_is_loaded = true

	print(
		"AO resource database loaded."
	)


func get_body_definition(
	body_id: int
) -> Dictionary:
	_ensure_loaded()

	var body_section_name := (
		"BODY%d" % body_id
	)

	if not _bodies.has(
		body_section_name
	):
		push_error(
			"AO body not found: %d"
			% body_id
		)

		return {}

	var body_data: Dictionary = (
		_bodies[
			body_section_name
		]
	)

	var standard_id: int = int(
		body_data.get(
			"Std",
			"0"
		)
	)

	if standard_id <= 0:
		push_error(
			(
				"AO body %d uses direct GRHs. "
				+ "This format is not supported yet."
			)
			% body_id
		)

		return {}

	var file_num: int = int(
		body_data.get(
			"FileNum",
			"0"
		)
	)

	var mold_section_name := (
		"Molde%d"
		% standard_id
	)

	if not _molds.has(
		mold_section_name
	):
		push_error(
			"AO mold not found: %d"
			% standard_id
		)

		return {}

	var mold_data: Dictionary = (
		_molds[
			mold_section_name
		]
	)

	var origin_x: int = int(
		mold_data.get(
			"X",
			"0"
		)
	)

	var origin_y: int = int(
		mold_data.get(
			"Y",
			"0"
		)
	)

	var frame_width: int = int(
		mold_data.get(
			"Width",
			"0"
		)
	)

	var frame_height: int = int(
		mold_data.get(
			"Height",
			"0"
		)
	)

	var animations: Dictionary = {}

	for direction_index in range(4):
		var direction_name: String = str(
			BODY_DIRECTIONS[
				direction_index
			]
		)

		var direction_key := (
			"Dir%d"
			% (direction_index + 1)
		)

		var frame_count: int = int(
			mold_data.get(
				direction_key,
				"0"
			)
		)

		var frame_regions: Array[Rect2] = []

		for frame_index in range(
			frame_count
		):
			frame_regions.append(
				Rect2(
					origin_x
					+ frame_index
					* frame_width,

					origin_y
					+ direction_index
					* frame_height,

					frame_width,
					frame_height
				)
			)

		animations[
			direction_name
		] = frame_regions

	var head_offset := Vector2(
		float(
			body_data.get(
				"HeadOffsetX",
				"0"
			)
		),
		float(
			body_data.get(
				"HeadOffsetY",
				"0"
			)
		)
	)

	return {
		"body_id": body_id,
		"file_num": file_num,
		"frame_size": Vector2(
			frame_width,
			frame_height
		),
		"head_offset": head_offset,
		"animations": animations
	}


func get_head_definition(
	head_id: int
) -> Dictionary:
	_ensure_loaded()

	var head_section_name := (
		"HEAD%d" % head_id
	)

	if not _heads.has(
		head_section_name
	):
		push_error(
			"AO head not found: %d"
			% head_id
		)

		return {}

	var head_data: Dictionary = (
		_heads[
			head_section_name
		]
	)

	var directions: Dictionary = {}

	for direction_name: String in (
		HEAD_DIRECTION_KEYS
	):
		var head_key: String = str(
			HEAD_DIRECTION_KEYS[
				direction_name
			]
		)

		var grh_id: int = int(
			head_data.get(
				head_key,
				"0"
			)
		)

		if grh_id <= 0:
			continue

		var grh_definition := (
			_get_static_grh(
				grh_id
			)
		)

		if grh_definition.is_empty():
			continue

		directions[
			direction_name
		] = grh_definition

	return {
		"head_id": head_id,
		"directions": directions
	}


func get_texture(
	file_num: int
) -> Texture2D:
	if _texture_cache.has(
		file_num
	):
		return (
			_texture_cache[
				file_num
			] as Texture2D
		)

	var lowercase_path := (
		GRAPHICS_PATH
		+ "%d.png"
		% file_num
	)

	var uppercase_path := (
		GRAPHICS_PATH
		+ "%d.PNG"
		% file_num
	)

	var texture_path := ""

	if ResourceLoader.exists(
		lowercase_path
	):
		texture_path = lowercase_path
	elif ResourceLoader.exists(
		uppercase_path
	):
		texture_path = uppercase_path
	else:
		push_error(
			"AO texture not found: %d"
			% file_num
		)

		return null

	var texture: Texture2D = load(
		texture_path
	) as Texture2D

	_texture_cache[
		file_num
	] = texture

	return texture


func _get_static_grh(
	grh_id: int
) -> Dictionary:
	if not _graphics.has(
		"Graphics"
	):
		return {}

	var graphics_section: Dictionary = (
		_graphics["Graphics"]
	)

	var grh_key := (
		"Grh%d" % grh_id
	)

	if not graphics_section.has(
		grh_key
	):
		push_error(
			"AO GRH not found: %d"
			% grh_id
		)

		return {}

	var raw_value: String = str(
		graphics_section[
			grh_key
		]
	)

	var parts: PackedStringArray = (
		raw_value.split(
			"-",
			false
		)
	)

	if parts.size() < 6:
		push_error(
			"Invalid AO GRH: %d"
			% grh_id
		)

		return {}

	var frame_count: int = int(
		parts[0]
	)

	if frame_count != 1:
		push_error(
			(
				"GRH %d is animated. "
				+ "Static GRH expected."
			)
			% grh_id
		)

		return {}

	return {
		"grh_id": grh_id,
		"file_num": int(
			parts[1]
		),
		"region": Rect2(
			int(parts[2]),
			int(parts[3]),
			int(parts[4]),
			int(parts[5])
		)
	}


func _ensure_loaded() -> void:
	if not _is_loaded:
		load_database()
		
func get_grh_definition(
	grh_id: int
) -> Dictionary:
	_ensure_loaded()

	return _get_static_grh(
		grh_id
	)


func get_grh_animation(grh_id: int) -> Dictionary:
	_ensure_loaded()
	var value := str(_graphics.get("Graphics", {}).get("Grh%d" % grh_id, ""))
	var parts := value.split("-", false)
	if parts.size() < 2:
		return {}
	var count := int(parts[0])
	var frames: Array[Dictionary] = []
	if count == 1:
		frames.append(_get_static_grh(grh_id))
		return {"frames": frames, "fps": 1.0}
	if parts.size() < count + 2:
		return {}
	for index in range(count):
		var frame := _get_static_grh(int(parts[index + 1]))
		if frame.is_empty():
			return {}
		frames.append(frame)
	var duration := maxf(float(parts[count + 1]), 1.0)
	return {"frames": frames, "fps": count * 1000.0 / duration}

func _parse_ini_like_file(
	path: String
) -> Dictionary:
	var result: Dictionary = {}

	if not FileAccess.file_exists(
		path
	):
		push_error(
			"AO data file not found: %s"
			% path
		)

		return result

	var file := FileAccess.open(
		path,
		FileAccess.READ
	)

	if file == null:
		push_error(
			"Could not open AO data file: %s"
			% path
		)

		return result

	var current_section := ""

	while not file.eof_reached():
		var line: String = (
			file.get_line()
			.strip_edges()
		)

		if line.is_empty():
			continue

		if (
			line.begins_with(";")
			or line.begins_with("#")
			or line.begins_with("'")
		):
			continue

		var comment_index: int = (
			line.find("'")
		)

		if comment_index >= 0:
			line = (
				line.substr(
					0,
					comment_index
				)
				.strip_edges()
			)

		if line.is_empty():
			continue

		if (
			line.begins_with("[")
			and line.ends_with("]")
		):
			current_section = (
				line.substr(
					1,
					line.length() - 2
				)
			)

			if not result.has(
				current_section
			):
				result[
					current_section
				] = {}

			continue

		var separator_index: int = (
			line.find("=")
		)

		if separator_index < 0:
			continue

		if current_section.is_empty():
			continue

		var key := (
			line.substr(
				0,
				separator_index
			)
			.strip_edges()
		)

		var value := (
			line.substr(
				separator_index + 1
			)
			.strip_edges()
		)

		var section_data: Dictionary = (
			result[
				current_section
			]
		)

		section_data[key] = value

	return result
