extends SceneTree
## Shared exterior/hologram contract, independent of headset rendering.
const Mech = preload("res://scripts/control_model.gd")
var checks := 0
var failures := 0
var scene
var endpoint_ok := true
var length_ok := true
var mirror_ok := true
var equipment_ok := true
var cockpit_ok := true
var jets_ok := true
var expected_equipment: Array[Transform3D] = []
var expected_body := Transform3D.IDENTITY
var expected_camera := Transform3D.IDENTITY

func check(value: bool, caption: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(caption)

func _initialize() -> void:
	call_deferred("run")

func remember() -> void:
	expected_equipment.clear()
	for arm in scene.arms: expected_equipment.append(arm.global_transform)
	expected_body = scene.body.global_transform
	expected_camera = scene.adapter.camera.global_transform

func audit(acceleration: Vector3, paused := false) -> void:
	for i in 2:
		endpoint_ok = endpoint_ok and scene.robot.endpoints[i].distance_to(scene.arms[i].position)<.0001
		equipment_ok = equipment_ok and scene.arms[i].global_transform.is_equal_approx(expected_equipment[i])
	for link in scene.robot.links:
		length_ok = length_ok and absf(link.basis.z.length()-scene.robot.ARM_LENGTH)<.0001
	for i in scene.hologram.sources.size():
		var source: Node3D = scene.hologram.sources[i]
		var copy: Node3D = scene.hologram.copies[i]
		mirror_ok = mirror_ok and copy.transform.is_equal_approx(source.transform) and copy.visible==source.visible
		if source is MeshInstance3D:
			mirror_ok = mirror_ok and copy is MeshInstance3D and copy.mesh==source.mesh
		var parent_index: int = scene.hologram.sources.find(source.get_parent())
		if parent_index>=0:
			mirror_ok = mirror_ok and copy.get_parent()==scene.hologram.copies[parent_index]
		else:
			mirror_ok = mirror_ok and copy.get_parent()==scene.hologram.content
	cockpit_ok = cockpit_ok and scene.body.global_transform.is_equal_approx(expected_body) and scene.adapter.camera.global_transform.is_equal_approx(expected_camera)
	var represented: Vector3 = scene.robot.torso.basis.y*scene.robot.flight.main_acceleration+scene.robot.flight.residual_acceleration
	jets_ok = jets_ok and represented.distance_to(Vector3.ZERO if paused else acceleration)<.0001

func simulate(hz: int, seconds: float, velocity: Vector3, acceleration: Vector3, paused := false) -> void:
	for _i in int(round(seconds*hz)):
		scene.robot.update_pose(1.0/hz,velocity,acceleration,scene.arms,Basis.IDENTITY,paused)
		scene.hologram.sync()
		audit(acceleration,paused)

func count_spatial(node: Node) -> int:
	var count := 1 if node is Node3D else 0
	for child in node.get_children(): count += count_spatial(child)
	return count

func add_probe_bolt(at: Vector3, velocity: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	scene.world.add_child(mesh)
	scene.world.bolts.append({"position":at,"velocity":velocity,"age":0.0,"mesh":mesh})

func check_animated_hurtbox(hz: int) -> void:
	scene.body.transform = Transform3D.IDENTITY
	scene.model.reset()
	for i in 2: scene.arms[i].transform = scene.model.arm_actual[i]
	for _i in hz*4:
		scene.robot.update_pose(1.0/hz,Vector3.FORWARD*20,Vector3.FORWARD*12,scene.arms,Basis.IDENTITY)
	scene.paused = false
	scene.resume_delay = 0.0
	scene.adapter._window_focused = true
	scene.world.reset()
	var chest_center: Vector3 = scene.robot.chest.global_position
	add_probe_bolt(chest_center,Vector3.RIGHT)
	scene._physics_process(1.0/hz)
	check(scene.world.hits==1,"%dHz main loop registers a bolt inside animated exterior chest" % hz)
	scene.world.reset()
	add_probe_bolt(scene.body.global_position,Vector3.RIGHT)
	scene._physics_process(1.0/hz)
	check(scene.world.hits==0 and scene.world.bolts.size()==1,"%dHz main loop does not retain obsolete upright torso hurtbox" % hz)

func run() -> void:
	var settled: Array[Basis] = []
	for hz in [30,90]:
		scene = load("res://main.tscn").instantiate()
		root.add_child(scene)
		scene.set_physics_process(false)
		scene.set_process(false)
		scene.adapter.set_process(false)
		scene.robot.posture_enabled = true
		scene.body.transform = Transform3D(Basis.from_euler(Vector3(.2,.7,0)),Vector3(13,-8,27))
		for i in 2:
			scene.arms[i].transform = Transform3D(Basis.from_euler(Vector3(.2,-.3 if i==0 else .4,.1)),Mech.NEUTRALS[i])
		remember()
		endpoint_ok = true
		length_ok = true
		mirror_ok = true
		equipment_ok = true
		cockpit_ok = true
		jets_ok = true
		var expected_count: int = count_spatial(scene.robot)+count_spatial(scene.arms[0])+count_spatial(scene.arms[1])
		check(scene.hologram.sources.size()==expected_count,"%dHz mirror includes every exterior and equipment child" % hz)
		simulate(hz,3,Vector3.FORWARD*20,Vector3.FORWARD*12)
		check(scene.robot.torso.basis.y.dot(Vector3.FORWARD)>.85,"%dHz sustained forward thrust adopts flight posture" % hz)
		settled.append(scene.robot.torso.basis)
		var forward: Basis = scene.robot.torso.basis
		simulate(hz,1,Vector3.FORWARD*20,Vector3.BACK*30)
		check(scene.robot.flight.mode=="BRAKE" and scene.robot.torso.basis.y.dot(Vector3.FORWARD)>.85,"%dHz braking retains forward posture without flipping" % hz)
		var biggest_change := 0.0
		for pulse in 20:
			simulate(hz,.1,Vector3.FORWARD*20,Vector3.RIGHT*12*(1 if pulse%2==0 else -1))
			biggest_change = maxf(biggest_change,forward.get_rotation_quaternion().angle_to(scene.robot.torso.basis.get_rotation_quaternion()))
		check(biggest_change<deg_to_rad(4),"%dHz brief alternating commands do not flap settled posture" % hz)
		simulate(hz,3,Vector3.RIGHT*20,Vector3.RIGHT*12)
		check(scene.robot.torso.basis.y.dot(Vector3.RIGHT)>.8,"%dHz sustained strafe eventually changes posture" % hz)
		var held: Transform3D = scene.robot.torso.transform
		simulate(hz,.5,Vector3.RIGHT*20,Vector3.FORWARD*12,true)
		check(scene.robot.torso.transform.is_equal_approx(held),"%dHz pause freezes chest pose" % hz)
		check(not scene.robot.flames[0].visible and not scene.robot.flames[1].visible and not scene.robot.flames[2].visible,"%dHz pause extinguishes all jets" % hz)
		simulate(hz,1,Vector3.RIGHT*20,Vector3.ZERO)
		check(not scene.robot.flames[0].visible and not scene.robot.flames[1].visible and not scene.robot.flames[2].visible,"%dHz coast extinguishes all jets" % hz)
		simulate(hz,8,Vector3.ZERO,Vector3.ZERO)
		check(scene.robot.torso.basis.y.dot(Vector3.UP)>.999,"%dHz settled idle returns upright" % hz)
		check(endpoint_ok and equipment_ok,"%dHz gun/shield and connected wrists stay fixed across every flight phase" % hz)
		check(length_ok,"%dHz arm bones retain authored lengths across flight phases" % hz)
		check(mirror_ok,"%dHz complete hologram hierarchy matches exterior mesh transforms and visibility" % hz)
		check(cockpit_ok,"%dHz body motor and tracked camera never inherit procedural posture" % hz)
		check(jets_ok,"%dHz torso-oriented main and residual thrust reconstruct commanded acceleration" % hz)
		# Sample all 26 axis/edge/corner directions on each legal workspace sphere.
		endpoint_ok = true
		length_ok = true
		for x in [-1,0,1]:
			for y in [-1,0,1]:
				for z in [-1,0,1]:
					var offset := Vector3(x,y,z).normalized()*Mech.ARM_REACH
					for i in 2: scene.arms[i].position = Mech.NEUTRALS[i]+offset*(1 if i==0 else -1)
					remember()
					simulate(hz,.1,Vector3.FORWARD*20,Vector3.FORWARD*12)
		check(endpoint_ok,"%dHz wrists meet endpoints at neutral and extreme legal workspace samples" % hz)
		check(length_ok,"%dHz fixed arm lengths hold at extreme legal workspace samples" % hz)
		# A completely folded arm is legal too; it must not leave a gap at the wrist.
		for i in 2:
			var side := -1.0 if i==0 else 1.0
			scene.arms[i].position = scene.robot.torso.position+scene.robot.torso.basis*Vector3(side*3,4,0)
		remember()
		endpoint_ok = true
		length_ok = true
		simulate(hz,1.0/hz,Vector3.ZERO,Vector3.ZERO,true)
		check(endpoint_ok and length_ok,"%dHz coincident shoulder/wrist has exact endpoint and fixed folded bones" % hz)
		check_animated_hurtbox(hz)
		scene.queue_free()
		await process_frame
	check(settled[0].get_rotation_quaternion().angle_to(settled[1].get_rotation_quaternion())<deg_to_rad(1),"30Hz and 90Hz settled flight posture agree within one degree")
	print("SHARED_POSE checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
