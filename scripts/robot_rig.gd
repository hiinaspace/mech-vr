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
var nozzles: Array[MeshInstance3D] = []
var jet_lights: Array[OmniLight3D] = []
var exhaust_origins: Array[Vector3] = []
var rail_extension := [0.0,0.0]
var chest_yaw := 0.0
var lower_basis := Basis.IDENTITY
var head_basis := Basis.IDENTITY
var posture_enabled := true
var effect_strength := 0.0

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
	for i in 7:
		var flame := box(self,Vector3.ONE,Vector3.ZERO,Color("8cfff0") if i!=2 else Color("ffc777"))
		flame.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		flame.material_override.emission_enabled = true
		flame.material_override.emission = Color("72e8ff") if i != 2 else Color("ffbe72")
		flame.material_override.emission_energy_multiplier = 3.5
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flames.append(flame)
		nozzles.append(box(self,Vector3.ONE,Vector3.ZERO,Color("182b3b")))
	for _i in 2:
		var light := OmniLight3D.new()
		light.light_color = Color("7ccfff")
		light.omni_range = 9.0
		light.omni_attenuation = 1.6
		light.shadow_enabled = false
		add_child(light)
		jet_lights.append(light)

func update_pose(dt: float, velocity: Vector3, acceleration: Vector3, equipment: Array[Node3D], gaze: Basis, paused := false, boost_active := false) -> void:
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
	var limb_nozzles: Array[Vector3] = []
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
		limb_nozzles.append(points[1].lerp(points[2],.72)+orientation*Vector3(side*.65,0,.3))
		var hip := pelvis+lower_basis*Vector3(side*1.2,-.5,0)
		var knee := pelvis+lower_basis*Vector3(side*1.35,-3.6,.45+flight.flight_amount*.7)
		var ankle := pelvis+lower_basis*Vector3(side*1.4,-6.6,.25+flight.flight_amount*1.1)
		link(legs[i*3],hip,knee,1.25)
		link(legs[i*3+1],knee,ankle,.95)
		link(legs[i*3+2],ankle,ankle+lower_basis*Vector3(0,-.1,-1.5),1)
		limb_nozzles.append(knee.lerp(ankle,.7)+lower_basis*Vector3(side*.55,0,.7))
	flight.set_jet_basis(orientation,Vector3.ZERO if paused else acceleration)
	# A speed-limited boost still reads as an active engine. This floor drives
	# visuals only; the posture model and force decomposition remain physical.
	var effect_acceleration := Vector3.ZERO if paused else acceleration
	if not paused and boost_active and velocity.length()>.4 and acceleration.length()<.2:
		effect_acceleration = velocity.normalized()*6.0
	effect_strength = effect_acceleration.length()
	var effect_main := maxf(effect_acceleration.dot(orientation.y),0.0)
	exhaust_origins.clear()
	for i in 2:
		var nozzle := torso.position+orientation*Vector3(-1.25 if i==0 else 1.25,.8,2.35)
		exhaust_origins.append(nozzle)
		jet(i,nozzle,-orientation.y,effect_main,.8,5.8)
	var residual: Vector3 = effect_acceleration-orientation.y*effect_main
	var nozzle := torso.position+orientation*Vector3(0,3,2.1)
	jet(2,nozzle,-residual.normalized() if residual.length()>.2 else orientation.z,residual.length(),.48,3.8)
	# Forearm and calf pods are authored gimballed verniers. They follow resolved
	# bones, not controller targets, and represent commanded acceleration only.
	var force := effect_strength
	var exhaust_direction := -effect_acceleration.normalized() if force>.2 else -orientation.y
	for i in 4:
		jet(i+3,limb_nozzles[i],exhaust_direction,force,.32 if i%2==0 else .48,2.6 if i%2==0 else 3.8)
	for i in 2:
		jet_lights[i].position = limb_nozzles[i*2]+exhaust_direction*.55
		jet_lights[i].visible = force>.2
		jet_lights[i].light_energy = minf(force/8.0,2.5)*1.5

func jet(index: int, origin: Vector3, direction: Vector3, force: float, width: float, maximum_length: float) -> void:
	var axis := direction.normalized() if direction.length_squared()>.001 else Vector3.DOWN
	link(nozzles[index],origin-axis*.48,origin,width*1.7)
	flames[index].visible = force>.2
	var length := .4+minf(force/4.0,maximum_length)
	link(flames[index],origin,origin+axis*length,width)

## Cockpit-local nozzle positions converted at query time, so callers can emit a
## wake into an independent world node without inheriting subsequent robot motion.
func world_exhaust_origins() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for origin in exhaust_origins: result.append(to_global(origin))
	return result

func link(node: MeshInstance3D, a: Vector3, b: Vector3, width: float) -> void:
	var delta := b-a
	var direction := delta.normalized() if delta.length()>.00001 else Vector3.UP
	node.position = (a+b)*.5
	node.basis = Basis.looking_at(direction,Vector3.UP if absf(direction.y)<.99 else Vector3.RIGHT)
	node.scale = Vector3(width,width,maxf(delta.length(),.001))
