extends SceneTree
const Flight = preload("res://scripts/flight_pose.gd")
var checks := 0
var failures := 0
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)
func _initialize() -> void:
	for dt in [1.0/30,1.0/60,1.0/120]:
		var f := Flight.new()
		for _i in int(2.0/dt):
			f.step(dt,Vector3(0,0,-20),Vector3(0,0,-12))
		check(f.body_basis.y.dot(Vector3.FORWARD)>.98,"Forward acceleration puts spine into flight")
		check(f.body_basis.y.dot(Vector3.UP)>0.13,"Visual lean stays bounded")
		check((f.body_basis.y*f.main_acceleration+f.residual_acceleration).distance_to(Vector3(0,0,-12))<.001,"Jet acceleration components reconstruct requested thrust")
		for _i in int(1.0/dt):
			var previous: Quaternion = f.body_basis.get_rotation_quaternion()
			f.step(dt,Vector3(0,0,-10),Vector3(0,0,45))
			check(f.body_basis.is_finite(),"Brake reversal stays finite")
			check(previous.angle_to(f.body_basis.get_rotation_quaternion())<=Flight.TURN_RATE*dt+.001,"Reversal respects angular speed")
			check((f.body_basis.y*f.main_acceleration+f.residual_acceleration).distance_to(Vector3(0,0,45))<.001,"Reversal jets do not claim backwards force")
		for _i in int(3.0/dt):
			f.step(dt,Vector3(0,0,-12),Vector3.ZERO)
		check(f.body_basis.y.dot(Vector3.FORWARD)>.98,"Coast retains velocity-directed flight posture")
		check(f.main_acceleration==0 and f.residual_acceleration==Vector3.ZERO,"Coasting emits no thrust")
		var held: Basis = f.body_basis
		f.step(dt,Vector3.ZERO,Vector3(1,2,3),true)
		check(f.body_basis.is_equal_approx(held) and f.main_acceleration==0,"Pause freezes pose and suppresses jets")
		for _i in int(3.0/dt):
			f.step(dt,Vector3.ZERO,Vector3.ZERO)
		check(f.body_basis.is_equal_approx(Basis.IDENTITY),"Idle returns upright")
		f.step(dt,Vector3.ZERO,Vector3(0,-30,0))
		check(f.body_basis.is_finite() and f.residual_acceleration.y<0,"Vertical descent is stable and uses down-force vernier")
	var frame := Basis.from_euler(Vector3(.4,1.3,0))
	var local_acceleration := Vector3(4,3,-7)
	var world_acceleration := frame*local_acceleration
	var f := Flight.new()
	f.step(.1,Vector3.ZERO,frame.inverse()*world_acceleration)
	check((frame*(f.body_basis.y*f.main_acceleration+f.residual_acceleration)).distance_to(world_acceleration)<.001,"Cockpit-frame jet components reconstruct world acceleration")
	for target in [Vector3.ZERO,Vector3(1,2,-3),Vector3(100,0,0),Vector3(0,-100,0)]:
		var joints: Array[Vector3] = Flight.arm_points(Vector3.ZERO,target,Vector3.DOWN)
		check(joints[1].is_finite() and joints[2].is_finite(),"IK finite for coincident and pole-aligned targets")
		check(absf(joints[0].distance_to(joints[1])-4.5)<.001 and absf(joints[1].distance_to(joints[2])-4.5)<.001,"IK preserves both segment lengths")
		check(joints[2].length()<9.0,"Unreachable target caps wrist reach")
	print("FLIGHT_POSE_TESTS checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
