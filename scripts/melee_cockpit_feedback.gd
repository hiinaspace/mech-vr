extends Node3D
## Cockpit-space actual/requested grip poses under the inverse arm calibration.
var actual_frames: Array[Node3D] = []
var desired_frames: Array[Node3D] = []
var tethers: Array[MeshInstance3D] = []
var captions: Array[Label3D] = []
func setup() -> void:
	for i in 2:
		actual_frames.append(_frame(Color("6fffe4"),.050))
		desired_frames.append(_frame(Color("ffc777"),.035))
		tethers.append(_box(self,Vector3.ONE,Color("8aefd9")))
		var caption := Label3D.new()
		caption.font_size = 24
		caption.pixel_size = .00038
		caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(caption)
		captions.append(caption)
func _box(parent: Node3D, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node
func _frame(color: Color, size: float) -> Node3D:
	var frame := Node3D.new()
	add_child(frame)
	# Open cube reads as a ghost grip without covering the tracked controller.
	for axis in 3:
		for a in [-1,1]:
			for b in [-1,1]:
				var dimensions := Vector3.ONE*.002
				dimensions[axis] = size
				var edge := _box(frame,dimensions,color)
				edge.position[(axis+1)%3] = a*size*.5
				edge.position[(axis+2)%3] = b*size*.5
	for axis in 3:
		var dimensions := Vector3.ONE*.003
		dimensions[axis] = size*1.6
		var bar := _box(frame,dimensions,[Color("ff6868"),Color("76e986"),Color("709bff")][axis])
		bar.position[axis] = size*.8
	return frame
func show_poses(actual: Array, desired: Array) -> void:
	for i in 2:
		actual_frames[i].transform = actual[i]
		desired_frames[i].transform = desired[i]
		var difference: Vector3 = desired[i].origin-actual[i].origin
		var angle: float = actual[i].basis.get_rotation_quaternion().angle_to(desired[i].basis.get_rotation_quaternion())
		tethers[i].visible = difference.length()>.002
		if tethers[i].visible:
			tethers[i].transform = Transform3D(Basis.looking_at(difference,Vector3.RIGHT if absf(difference.normalized().dot(Vector3.UP))>.95 else Vector3.UP),(actual[i].origin+desired[i].origin)*.5)
			tethers[i].scale = Vector3(.002,.002,difference.length())
		captions[i].position = desired[i].origin+Vector3(0,-.07,0)
		captions[i].text = "%s %.1fcm / %.0f°" % ["L" if i==0 else "R",difference.length()*100,rad_to_deg(angle)]
