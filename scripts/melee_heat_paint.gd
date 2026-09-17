extends RefCounted
## Six box faces in a 3x2 atlas, painted with Godot 4.7 DrawableTexture2D.
## Rebuild from the small recorded stamp list so seeking needs no GPU readback.
const FACE_SIZE := 96
const GRID_SIZE := 16
const MAX_CELLS := 6*GRID_SIZE*GRID_SIZE
const ADD_SHADER = preload("res://shaders/melee_heat_add.gdshader")
var additive := ShaderMaterial.new()
var texture := DrawableTexture2D.new()
var brush: ImageTexture
var clear_texture: ImageTexture
var previous_marks: Array = []
var previous_dimensions := Vector3.ZERO

func _init() -> void:
	additive.shader = ADD_SHADER
	texture.setup(FACE_SIZE*3,FACE_SIZE*2,DrawableTexture2D.DRAWABLE_FORMAT_RGBA8,Color.BLACK)
	var image := Image.create(32,32,false,Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var distance := (Vector2(x,y)-Vector2(15.5,15.5)).length()/15.5
			var value := exp(-distance*distance*4.0) if distance<1 else 0.0
			image.set_pixel(x,y,Color(value,value,value,1))
	brush = ImageTexture.create_from_image(image)
	image = Image.create(1,1,false,Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	clear_texture = ImageTexture.create_from_image(image)

static func project(point: Vector3, half_size: Vector3) -> Vector3:
	var p := point/half_size
	var axis := p.abs().max_axis_index()
	var face := axis*2+(1 if p[axis]<0 else 0)
	var uv := Vector2(p.z,p.y) if axis==0 else (Vector2(p.x,p.z) if axis==1 else Vector2(p.x,p.y))
	return Vector3(clampf(uv.x*.5+.5,0,1),clampf(uv.y*.5+.5,0,1),face)

func paint(mesh: MeshInstance3D, marks: Array) -> void:
	var half_size := mesh.get_aabb().size*.5
	var dimensions := mesh.get_aabb().size*mesh.global_basis.get_scale().abs()
	if marks==previous_marks and dimensions.is_equal_approx(previous_dimensions): return
	previous_marks = marks.duplicate()
	previous_dimensions = dimensions
	texture.blit_rect(Rect2i(0,0,FACE_SIZE*3,FACE_SIZE*2),clear_texture)
	for mark in marks:
		var projected := project(Vector3(mark.x,mark.y,mark.z),half_size)
		var face := int(projected.z)
		var axis := face/2
		var face_size := Vector2(dimensions.z,dimensions.y) if axis==0 else (Vector2(dimensions.x,dimensions.z) if axis==1 else Vector2(dimensions.x,dimensions.y))
		var radius := Vector2.ONE*.9/face_size*FACE_SIZE
		var center := Vector2(projected.x,projected.y)*FACE_SIZE
		# Bound each paint operation to its face tile. Edge stamps shrink instead
		# of leaking into an unrelated face; seam-spanning painting is deferred.
		radius.x = maxf(1,minf(radius.x,minf(center.x,FACE_SIZE-center.x)))
		radius.y = maxf(1,minf(radius.y,minf(center.y,FACE_SIZE-center.y)))
		center = center.clamp(radius,Vector2.ONE*FACE_SIZE-radius)
		var offset := Vector2i((face%3)*FACE_SIZE,(face/3)*FACE_SIZE)
		var rect := Rect2i(Vector2i(center-radius)+offset,Vector2i(radius*2).max(Vector2i.ONE))
		texture.blit_rect(rect,brush,Color(mark.w,mark.w,mark.w,1),0,additive)

## Spatial bins retain a bounded trail across every box face. A cell is retired
## only after cooling; moving contact never evicts an older hot mark.
static func cell_position(point: Vector3, half_size: Vector3) -> Vector3:
	var projected := project(point,half_size)
	var u := (clampi(int(projected.x*GRID_SIZE),0,GRID_SIZE-1)+.5)/GRID_SIZE*2-1
	var v := (clampi(int(projected.y*GRID_SIZE),0,GRID_SIZE-1)+.5)/GRID_SIZE*2-1
	var face := int(projected.z)
	var side := 1.0 if face%2==0 else -1.0
	var normalized := Vector3(side,v,u) if face/2==0 else (Vector3(u,side,v) if face/2==1 else Vector3(u,v,side))
	return normalized*half_size
