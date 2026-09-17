extends SceneTree
const Model = preload("res://scripts/control_model.gd")
var checks := 0
var failures := 0
func check(value: bool, caption: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(caption)
func sample() -> Dictionary:
	return {"left":Transform3D.IDENTITY,"right":Transform3D.IDENTITY,"head":Transform3D.IDENTITY,"focused":true,"valid_left":true,"valid_right":true,"thumbstick_basis":Basis(Vector3.UP,PI/2)}
func _initialize() -> void:
	var model := Model.new()
	var s := sample()
	model.step(s,.01)
	s.move = Vector3.FORWARD
	model.step(s,.1)
	check(model.velocity.x< -1.1 and absf(model.velocity.z)<.001,"real thumbstick forward follows head direction")
	model.velocity = Vector3.ZERO
	s.thumbstick_basis = Basis.IDENTITY
	model.step(s,.1)
	check(model.velocity.z< -1.1 and absf(model.velocity.x)<.001,"head direction updates continuously")
	model.velocity = Vector3.ZERO
	s.move = Vector3.ZERO
	s.pilot_move = Vector3.FORWARD
	s.thumbstick_basis = Basis(Vector3.UP,PI/2)
	s.head.origin = Vector3(3,4,5)
	model.step(s,.1)
	check(model.velocity.z< -1.1 and absf(model.velocity.x)<.001,"virtual stick remains cockpit-relative despite head pose")
	model = Model.new()
	s = sample()
	model.step(s,.01)
	model.attitude_mode = true
	s.vertical = 1.0
	model.step(s,.1)
	check(model.roll_rate<0 and absf(model.pitch_rate)<.001,"physical stick pitch uses current head-right axis")
	check(model.body_basis.is_finite(),"head-relative pitch produces finite orientation")
	print("MELEE_HEAD_FRAME_TEST checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
