extends Node3D
## Sparse cockpit-fixed combiner plus world-anchored contact and impact symbols.
const INK := Color("8deacb")
const AMBER := Color("ffce78")
var attitude := Node3D.new()
var readout: Label3D
var contact_nodes: Array[Node3D] = []
var contact_labels: Array[Label3D] = []
var gun := Node3D.new()

func stroke(parent: Node3D, a: Vector3, b: Vector3, color: Color = INK, width: float = .008) -> void:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width,width,a.distance_to(b))
	n.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.no_depth_test = true
	n.material_override = mat
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)
	n.position = (a+b)*.5
	n.look_at_from_position(n.position,n.position+(b-a),Vector3.UP if absf((b-a).normalized().y)<.99 else Vector3.RIGHT)

func caption(parent: Node3D, value: String, pos: Vector3, color: Color = INK) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.font_size = 32
	label.pixel_size = .0018
	label.modulate = color
	label.outline_size = 3
	label.no_depth_test = true
	parent.add_child(label)
	label.position = pos
	return label

func setup(contacts: Array[Dictionary]) -> void:
	add_child(attitude)
	# Reference sphere is centered on the calibrated cockpit, not the HMD.
	for degrees in [-30,-20,-10,0,10,20,30]:
		var y := 4.0*tan(deg_to_rad(float(degrees)))
		var extent := .62 if degrees == 0 else .30
		for side in [-1,1]:
			stroke(attitude,Vector3(side*.14,y,-4),Vector3(side*extent,y,-4))
			if degrees != 0:
				stroke(attitude,Vector3(side*extent,y,-4),Vector3(side*extent,y+(.035 if degrees>0 else -.035),-4))
		if degrees != 0: caption(attitude,"%+d" % degrees,Vector3(.40,y,-4))
	stroke(self,Vector3(-.13,0,-4),Vector3(-.045,0,-4))
	stroke(self,Vector3(.045,0,-4),Vector3(.13,0,-4))
	stroke(self,Vector3(-.045,0,-4),Vector3(0,-.035,-4))
	stroke(self,Vector3(0,-.035,-4),Vector3(.045,0,-4))
	readout = caption(self,"",Vector3(0,.83,-4))
	caption(self,"NAV / COLONY REF",Vector3(0,.96,-4))
	for contact in contacts:
		var node := Node3D.new()
		add_child(node)
		node.top_level = true
		contact_nodes.append(node)
		# Diamonds identify training hostiles; no targeting lock or aim assistance.
		var points := [Vector3(0,.13,0),Vector3(.10,0,0),Vector3(0,-.13,0),Vector3(-.10,0,0),Vector3(0,.13,0)]
		for i in range(4): stroke(node,points[i],points[i+1],AMBER,.006)
		contact_labels.append(caption(node,"",Vector3(0,-.20,0),AMBER))
	add_child(gun)
	gun.top_level = true
	for side in [-1,1]:
		stroke(gun,Vector3(side*.065,-.025,0),Vector3(side*.065,.025,0),AMBER,.005)
		stroke(gun,Vector3(side*.065,0,0),Vector3(side*.105,0,0),AMBER,.005)
	stroke(gun,Vector3(0,-.015,0),Vector3(0,.015,0),AMBER,.004)
	caption(gun,"GUN",Vector3(0,-.075,0),AMBER)

func update_hud(cockpit: Transform3D, eye: Transform3D, contacts: Array[Dictionary], impact: Vector3, speed: float) -> void:
	var forward := -cockpit.basis.z
	var pitch := asin(clampf(forward.y,-1,1))
	var heading := fposmod(rad_to_deg(atan2(-forward.x,-forward.z)),360.0)
	# World-level ladder in the cockpit's heading plane; looking around does not steer it.
	attitude.basis = cockpit.basis.inverse()*Basis(Vector3.UP,deg_to_rad(heading))
	for mark in attitude.get_children():
		var local: Vector3 = attitude.basis*mark.position
		mark.visible = local.z < -.1 and absf(local.y) < .78
	readout.text = "%03d°    P %+.0f°    %02.0f m/s" % [roundi(heading)%360,rad_to_deg(pitch),speed]
	for i in range(contact_nodes.size()):
		var location: Vector3 = contacts[i].hud_position
		place_symbol(contact_nodes[i],location,eye)
		contact_labels[i].text = "TRN-H %02d / %.0fm" % [i+1,eye.origin.distance_to(location)]
	place_symbol(gun,impact,eye)

func place_symbol(node: Node3D, location: Vector3, eye: Transform3D) -> void:
	var offset := location-eye.origin
	node.visible = offset.dot(-eye.basis.z) > .1
	if not node.visible: return
	node.global_position = location
	node.global_basis = eye.basis
	# Constant angular size while retaining true binocular target depth.
	node.scale = Vector3.ONE*maxf(offset.length()/4.0,.05)
