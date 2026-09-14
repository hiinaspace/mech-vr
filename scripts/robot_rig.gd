extends Node3D
## One authored exterior pose. Equipment remains authoritative in cockpit space.
const Flight = preload("res://scripts/flight_pose.gd")
const HEAD_ANCHOR := Vector3(0,-1.8,1.0)
const ARM_LENGTH := 6.0
var flight := Flight.new()
var torso := Node3D.new()
var lower := Node3D.new()
var head := Node3D.new()
var chest: MeshInstance3D
var links: Array[MeshInstance3D] = []
var rails: Array[MeshInstance3D] = []
var legs: Array[MeshInstance3D] = []
var flames: Array[MeshInstance3D] = []
var endpoints: Array[Vector3] = []
var rail_extension := [0.0,0.0]
var chest_yaw := 0.0
var lower_basis := Basis.IDENTITY
var head_basis := Basis.IDENTITY
var posture_enabled := true

func box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .65
	node.material_override = material
	parent.add_child(node)
	node.position = at
	return node

func reset() -> void:
	flight = Flight.new()
	chest_yaw = 0.0
	lower_basis = Basis.IDENTITY
	head_basis = Basis.IDENTITY

func setup() -> void:
	add_child(torso)
	chest = box(torso,Vector3(4.8,4.2,2.5),Vector3(0,3,0),Color("38546a"))
	box(torso,Vector3(3.8,2.4,1.5),Vector3(0,2,1.8),Color("233d50"))
	box(torso,Vector3(3.8,.22,.15),Vector3(0,3.4,-1.3),Color("72cdd6"))
	add_child(lower)
	box(lower,Vector3(3.4,1.8,2.1),Vector3.ZERO,Color("2a4258"))
	add_child(head)
	box(head,Vector3(2,1.5,1.8),Vector3.ZERO,Color("597284"))
	box(head,Vector3(1.7,.30,.12),Vector3(0,.1,-.95),Color("ffc777"))
	for _side in 2:
		rails.append(box(self,Vector3.ONE,Vector3.ZERO,Color("76959c")))
		for _part in 2: links.append(box(self,Vector3.ONE,Vector3.ZERO,Color("537285")))
		for _part in 3: legs.append(box(self,Vector3.ONE,Vector3.ZERO,Color("3e5c72")))
	for i in 3:
		var flame := box(self,Vector3.ONE,Vector3.ZERO,Color("8cfff0") if i<2 else Color("ffc777"))
		flame.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flames.append(flame)

func update_pose(dt: float, velocity: Vector3, acceleration: Vector3, equipment: Array[Node3D], gaze: Basis, paused := false) -> void:
	flight.step(dt,velocity if posture_enabled else Vector3.ZERO,acceleration if posture_enabled else Vector3.ZERO,paused)
	var heading := Vector3.ZERO
	# Hands well in front of the neck contribute; close/behind hands cannot spin the chest.
	for hand in equipment:
		var relative: Vector3 = hand.position-HEAD_ANCHOR
		if relative.z < -1.0:
			var flat := Vector3(relative.x,0,relative.z)
			heading += flat.normalized()*clampf(flat.length()/6.0,0,1)
	var look := -gaze.z
	heading += Vector3(look.x,0,minf(look.z,-.01)).normalized()*.35
	var desired_yaw := clampf(atan2(-heading.x,-heading.z),-.45,.45) if heading.length()>.01 else 0.0
	if not paused and absf(desired_yaw-chest_yaw)>deg_to_rad(6):
		chest_yaw = move_toward(chest_yaw,desired_yaw,dt*deg_to_rad(25))
	var orientation := Basis(Vector3.UP,chest_yaw)*flight.body_basis
	# Neck-anchored body: the cockpit is a stabilized remote projection, not parented to the spine.
	torso.basis = orientation
	torso.position = HEAD_ANCHOR-orientation*Vector3(0,6.1,0)
	var pelvis := torso.position+orientation*Vector3(0,-.5,0)
	if not paused:
		lower_basis = Basis(lower_basis.get_rotation_quaternion().slerp(orientation.get_rotation_quaternion(),1-exp(-maxf(dt,0)*2.8)))
	lower.transform = Transform3D(lower_basis,pelvis)
	if not paused:
		var head_target := Basis.from_euler(Vector3(clampf(gaze.get_euler().x,-.45,.45),clampf(gaze.get_euler().y,-.8,.8),0))
		head_basis = Basis(head_basis.get_rotation_quaternion().slerp(head_target.get_rotation_quaternion(),1-exp(-maxf(dt,0)*5)))
	head.transform = Transform3D(head_basis,HEAD_ANCHOR)
	endpoints.clear()
	for i in 2:
		var side := -1.0 if i==0 else 1.0
		var shoulder := torso.position+orientation*Vector3(side*3,4,0)
		var target: Vector3 = equipment[i].position
		# Visible sliding clavicle accommodates the existing large controller workspace.
		# Fixed-length arm bones and parked weapon endpoints both stay honest.
		var delta := target-shoulder
		rail_extension[i] = maxf(0,delta.length()-(2*ARM_LENGTH-.02))
		var socket: Vector3 = shoulder+delta.normalized()*rail_extension[i]
		link(rails[i],shoulder,socket,.5)
		rails[i].visible = rail_extension[i]>.02
		var points: Array[Vector3] = Flight.arm_points(socket,target,orientation*Vector3(side,-.6,.3),ARM_LENGTH)
		link(links[i*2],points[0],points[1],.7)
		link(links[i*2+1],points[1],points[2],.6)
		endpoints.append(points[2])
		var hip := pelvis+lower_basis*Vector3(side*1.2,-.5,0)
		var knee := pelvis+lower_basis*Vector3(side*1.35,-3.6,.45+flight.flight_amount*.7)
		var ankle := pelvis+lower_basis*Vector3(side*1.4,-6.6,.25+flight.flight_amount*1.1)
		link(legs[i*3],hip,knee,1.25)
		link(legs[i*3+1],knee,ankle,.95)
		link(legs[i*3+2],ankle,ankle+lower_basis*Vector3(0,-.1,-1.5),1)
	flight.set_jet_basis(orientation,Vector3.ZERO if paused else acceleration)
	for i in 2:
		var nozzle := torso.position+orientation*Vector3(-1.1 if i==0 else 1.1,.8,2)
		flames[i].visible = flight.main_acceleration>.2
		link(flames[i],nozzle,nozzle-orientation.y*(.2+minf(flight.main_acceleration/8,3)),.4)
	var residual: Vector3 = flight.residual_acceleration
	var nozzle := torso.position+orientation*Vector3(0,3,1.9)
	flames[2].visible = residual.length()>.2
	link(flames[2],nozzle,nozzle-residual.normalized()*(.2+minf(residual.length()/8,3)),.3)

func link(node: MeshInstance3D, a: Vector3, b: Vector3, width: float) -> void:
	var delta := b-a
	var direction := delta.normalized() if delta.length()>.00001 else Vector3.UP
	node.position = (a+b)*.5
	node.basis = Basis.looking_at(direction,Vector3.UP if absf(direction.y)<.99 else Vector3.RIGHT)
	node.scale = Vector3(width,width,maxf(delta.length(),.001))
