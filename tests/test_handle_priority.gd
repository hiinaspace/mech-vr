extends SceneTree
const Pilot = preload("res://scripts/pilot_controls.gd")
const Handles = preload("res://scripts/cockpit_handles.gd")
const Motor = preload("res://scripts/control_model.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var pilot := Pilot.new()
	var handles := Handles.new()
	var motor := Motor.new()
	# Park right arm control directly on the spring-return pilot joystick.
	handles.handles[1].origin = Pilot.STICK_HOME
	var raw := {"left":Transform3D(Basis.IDENTITY,Vector3(-.28,-.3,-.42)),"right":Transform3D(Basis.IDENTITY,Pilot.STICK_HOME),"left_grip":0.0,"right_grip":0.0,"valid_left":true,"valid_right":true,"focused":true}
	var status := pilot.step(raw,handles.pilot_reservations(raw))
	handles.step(status.sample,motor,1.0/90)
	raw.right_grip = 1.0
	status = pilot.step(raw,handles.pilot_reservations(raw))
	handles.step(status.sample,motor,1.0/90)
	check(handles.grabbed[1] and pilot.stick_owner == -1, "fresh movable arm handle wins overlapping stick")
	# Moving and releasing the arm handle clears access to the underlying stick.
	raw.right.origin.x += .3
	status = pilot.step(raw,handles.pilot_reservations(raw))
	handles.step(status.sample,motor,1.0/90)
	raw.right_grip = 0.0
	status = pilot.step(raw,handles.pilot_reservations(raw))
	handles.step(status.sample,motor,1.0/90)
	raw.right.origin = Pilot.STICK_HOME
	status = pilot.step(raw,handles.pilot_reservations(raw))
	handles.step(status.sample,motor,1.0/90)
	raw.right_grip = 1.0
	status = pilot.step(raw,handles.pilot_reservations(raw))
	handles.step(status.sample,motor,1.0/90)
	check(pilot.stick_owner == 1 and not handles.grabbed[1], "pilot acquires after parked arm moves away")
	# Existing pilot ownership is not stolen by passing a parked arm handle.
	raw.right.origin.x += .3
	status = pilot.step(raw,handles.pilot_reservations(raw))
	handles.step(status.sample,motor,1.0/90)
	check(pilot.stick_owner == 1 and not handles.grabbed[1], "held pilot does not transfer when passing arm control")
	raw.paused = true
	status = pilot.step(raw,handles.pilot_reservations(raw))
	handles.step(status.sample,motor,1.0/90)
	raw.paused = false
	status = pilot.step(raw,handles.pilot_reservations(raw))
	handles.step(status.sample,motor,1.0/90)
	check(pilot.stick_owner == -1 and not handles.grabbed[1], "pause demands fresh release for either owner")
	print("HANDLE_PRIORITY_TEST failures=%d" % failures)
	quit(1 if failures else 0)
