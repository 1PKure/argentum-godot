class_name ArenaCanvasBatch
extends RefCounted
## Static colored geometry in one canvas mesh instead of one draw call per line.
var _vertices := PackedVector2Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()

func quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	var start := _vertices.size()
	_vertices.append_array(PackedVector2Array([a,b,c,d]))
	for i in range(4): _colors.append(color)
	_indices.append_array(PackedInt32Array([start,start+1,start+2,start,start+2,start+3]))

func rect(area: Rect2, color: Color, filled: bool = true, width: float = -1.0) -> void:
	if filled:
		quad(area.position,Vector2(area.end.x,area.position.y),area.end,Vector2(area.position.x,area.end.y),color)
		return
	var half := (width if width > 0 else 1.0)*0.5
	var outer := area.grow(half)
	var inner := area.grow(-half)
	if not inner.has_area():
		rect(outer,color)
		return
	rect(Rect2(outer.position,Vector2(outer.size.x,half*2)),color)
	rect(Rect2(Vector2(outer.position.x,inner.end.y),Vector2(outer.size.x,half*2)),color)
	rect(Rect2(Vector2(outer.position.x,inner.position.y),Vector2(half*2,inner.size.y)),color)
	rect(Rect2(Vector2(inner.end.x,inner.position.y),Vector2(half*2,inner.size.y)),color)

func line(from: Vector2, to: Vector2, color: Color, width: float = -1.0, _antialiased: bool = false) -> void:
	if from.is_equal_approx(to): return
	var normal := (to-from).normalized().orthogonal()*(width if width > 0 else 1.0)*0.5
	quad(from-normal,to-normal,to+normal,from+normal,color)

func polyline(points: PackedVector2Array, color: Color, width: float = -1.0, antialiased: bool = false) -> void:
	for i in range(1,points.size()):line(points[i-1],points[i],color,width,antialiased)

func arc(center: Vector2, radius: float, start: float, end: float, count: int, color: Color, width: float = -1.0, antialiased: bool = false) -> void:
	var points := PackedVector2Array()
	for i in range(count):points.append(center+Vector2.from_angle(lerpf(start,end,float(i)/maxi(1,count-1)))*radius)
	polyline(points,color,width,antialiased)

func polygon(points: PackedVector2Array, color: Color) -> void:
	var start := _vertices.size()
	_vertices.append_array(points)
	for point in points:_colors.append(color)
	for index: int in Geometry2D.triangulate_polygon(points):_indices.append(start+index)

func circle(center: Vector2, radius: float, color: Color) -> void:
	for i in range(32):
		var a := center+Vector2.from_angle(i*TAU/32)*radius
		var b := center+Vector2.from_angle((i+1)*TAU/32)*radius
		quad(center,a,b,center,color)

func mesh() -> ArrayMesh:
	if _vertices.is_empty():return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=_vertices
	arrays[Mesh.ARRAY_COLOR]=_colors
	arrays[Mesh.ARRAY_INDEX]=_indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	return result
