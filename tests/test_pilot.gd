extends SceneTree
const Pilot = preload("res://scripts/pilot_controls.gd")
const Motor = preload("res://scripts/control_model.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func sample() -> Dictionary:
	return {"left":Transform3D(Basis.IDENTITY,Pilot.THROTTLE_HOME), "right":Transform3D(Basis.IDENTITY,Pilot.STICK_HOME), "left_grip":0.0,"right_grip":0.0,"valid_left":true,"valid_right":true,"focused":true}
func _initialize() -> void:
	var p := Pilot.new()
	var s := sample()
	s.right_grip = 1.0
	check(p.step(s).owners[1] == "", "held grip at startup cannot grab")
	s.right_grip = 0.0
	p.step(s)
	s.right_grip = 1.0
	var out := p.step(s)
	check(out.owners[1] == "PILOT", "fresh right stick grab")
	check(not out.sample.valid_right and out.sample.right_grip == 1.0, "exclusive reservation retains physical grip")
	check(out.pilot_move == Vector3.ZERO and out.pilot_rotation == Vector3.ZERO, "acquisition has zero demand")
	s.right.origin += Vector3(.2,.2,-.2)
	s.right.basis = Basis.from_euler(Vector3(.4,-.4,.4))
	out = p.step(s)
	check(out.pilot_move.x > 0 and out.pilot_move.y > 0 and out.pilot_move.z < 0, "translation all axes")
	check(out.pilot_rotation.x > 0 and out.pilot_rotation.y < 0 and out.pilot_rotation.z > 0, "rotation all axes")
	check(out.pilot_move.length() <= 1.001 and out.pilot_rotation.length() <= 1.001, "bounded demands")
	s.right_grip = 0.0
	out = p.step(s)
	check(out.owners[1] == "" and out.pilot_move == Vector3.ZERO and out.pilot_rotation == Vector3.ZERO, "spring return release")
	check(p.stick_pose.origin == Pilot.STICK_HOME and p.stick_pose.basis == Basis.IDENTITY, "visual returns home")
	s = sample()
	p.step(s)
	s.left_grip = 1.0
	check(p.step(s).owners[0] == "THROTTLE", "left throttle grab")
	s.left.origin.z -= .3
	check(p.step(s).main_throttle > .99, "forward throttle full")
	s.left_grip = 0.0
	check(p.step(s).main_throttle > .99, "throttle persists after release")
	s.brake = true
	check(p.step(s).main_throttle == 0.0, "brake closes persistent throttle")
	s.brake = false
	check(p.step(s).main_throttle == 0.0, "brake release does not relaunch")
	p.reset()
	s = sample()
	s.left = s.right
	p.step(s)
	s.left_grip = 1.0
	s.right_grip = 1.0
	out = p.step(s)
	check(out.owners[0] == "PILOT" and out.owners[1] == "", "either hand with deterministic sole owner")
	s.paused = true
	check(p.step(s).owners[0] == "", "pause releases pilot")
	s.paused = false
	check(p.step(s).owners[0] == "", "pause held grip cannot regrab")
	p.reset()
	s = sample()
	p.step(s)
	s.right_grip = 1.0
	check(p.step(s,[false,true]).owners[1] == "", "arm already held wins")
	check(p.step(s,[false,false]).owners[1] == "", "handoff requires fresh release")
	s.right_grip = 0.0
	p.step(s)
	s.right_grip = 1.0
	p.step(s)
	s.valid_right = false
	check(p.step(s).owners[1] == "", "tracking loss releases")
	s.valid_right = true
	check(p.step(s).owners[1] == "", "tracking recovery requires fresh grip")
	p.throttle = 1.0
	s.valid_left = false
	check(p.step(s).main_throttle == 0.0, "left tracking loss closes even released throttle")
	for dt in [1.0/30,1.0/60,1.0/120]:
		var c := Motor.new()
		var input := sample()
		input.main_throttle = 1.0
		input.head = Transform3D(Basis.from_euler(Vector3(0,1,0)),Vector3.ZERO)
		for i in int(5/dt): c.step(input,dt)
		check(c.velocity.z < -89 and absf(c.velocity.x) < .001, "robot heading ignores gaze")
		input.yaw = 1.0
		for i in int(1/dt): c.step(input,dt)
		check(c.velocity.x < -5.0, "persistent throttle follows changing robot heading")
		input.brake = true
		check(c.step(input,dt).main_throttle == 0.0, "motor brake wins over requested main thrust")
		c.reset()
		input = sample()
		input.pilot_rotation = Vector3(.7,.7,.7)
		for i in int(12/dt): c.step(input,dt)
		check(absf(c.body_basis.determinant()-1) < .0001 and c.body_basis.is_finite(), "full attitude stable through poles")
		input.pilot_rotation = Vector3.ZERO
		for i in int(1/dt): c.step(input,dt)
		check(absf(c.roll_rate)+absf(c.pitch_rate)+absf(c.yaw_rate) < .00001, "released angular control stops rates")
		var parked := c.body_basis
		for i in int(1/dt): c.step(input,dt)
		check(c.body_basis.is_equal_approx(parked), "attitude remains parked")
	var visual_parent := Node3D.new()
	root.add_child(visual_parent)
	p.reset()
	p.setup_visual(visual_parent)
	s = sample()
	p.step(s)
	s.right_grip = 1.0
	p.step(s)
	s.right.origin += Vector3(.10,.06,-.12)
	s.right.basis = Basis.from_euler(Vector3(.22,-.15,.18))
	out = p.step(s)
	check(p.move_input.is_equal_approx(out.pilot_move) and p.rotation_input.is_equal_approx(out.pilot_rotation), "visual demands match actual deadzoned motor commands")
	check(p.origin_axes.position == Pilot.STICK_HOME, "ghost tripod remains at joystick origin")
	check(p.origin_tether.visible and p.origin_tether.position.is_equal_approx(Pilot.STICK_HOME + out.pilot_move * Pilot.TRAVEL * .5), "origin tether shows actual translation vector")
	check(is_equal_approx(p.origin_tether.basis.z.length(),out.pilot_move.length()*Pilot.TRAVEL), "origin tether length matches bounded input")
	check(p.rotation_vector.visible and p.rotation_tip.position.is_equal_approx(Pilot.STICK_HOME+Vector3(0,.12,0)+out.pilot_rotation*.12), "rotation vector shows actual signed angular demand")
	check(p.current_axes.transform.is_equal_approx(p.stick_pose), "moving tripod follows displayed command pose")
	check(p.rotation_bars[0].visible and p.rotation_bars[1].visible and p.rotation_bars[2].visible, "pitch yaw roll indicators respond independently")
	var move_before: Vector3 = out.pilot_move
	var rotation_before: Vector3 = out.pilot_rotation
	s.head = Transform3D(Basis.from_euler(Vector3(.5,1.2,-.3)),Vector3(2,1,-3))
	out = p.step(s)
	check(out.pilot_move.is_equal_approx(move_before) and out.pilot_rotation.is_equal_approx(rotation_before), "virtual sixDOF joystick ignores HMD rotation and translation")
	s.right_grip = 0.0
	p.step(s)
	check(not p.origin_tether.visible and not p.rotation_vector.visible and not p.rotation_tip.visible, "release clears demand indicators")
	p.reset()
	check(p.current_axes.position == Pilot.STICK_HOME and p.current_axes.basis == Basis.IDENTITY, "reset returns visual axes to neutral")
	visual_parent.free()
	print("PILOT_TESTS checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
