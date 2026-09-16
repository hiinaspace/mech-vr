extends SceneTree
var failures := 0
var checks := 0
func check(value: bool, caption: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(caption)
func aim(scene: Node3D, row: int, fraction: float) -> Transform3D:
	var point: Vector3 = scene.panel.transform*Vector3((fraction-.5)*scene.PANEL_WIDTH*.8,(4-row)*scene.ROW_HEIGHT,0)
	var origin := Vector3(.25,-.3,-.4)
	return Transform3D(Basis.looking_at(point-origin,Vector3.UP),origin)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene = load("res://melee.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.paused = false
	scene._action(8)
	check(scene.tuning_page and not scene.paused,"tuning page opens without pausing")
	var sample := {"focused":true,"valid_left":false,"valid_right":true,"left":Transform3D.IDENTITY,"right":aim(scene,1,.25),"right_trigger":0.0}
	scene._panel_input(sample)
	check(scene.hovered==1,"scaled tilted panel ray selects arm force")
	sample.right_trigger = 1.0
	scene._panel_input(sample)
	check(is_equal_approx(scene.physics.arm_force_limit,lerpf(1000,180000,.25)),"fresh trigger sets slider from ray position")
	sample.right = aim(scene,2,.8)
	scene._panel_input(sample)
	check(is_equal_approx(scene.physics.arm_force_limit,lerpf(1000,180000,.8)),"held drag stays captured to original slider across rows")
	check(scene.physics.arm_torque_limit==18000,"drag cannot activate adjacent slider")
	sample.right_trigger = 0.0
	scene._panel_input(sample)
	check(scene.slider_capture[1]<0,"trigger release drops capture")
	sample.right = aim(scene,7,.5)
	sample.right_trigger = 1.0
	scene._panel_input(sample)
	check(scene.rtt_ms==200 and not scene.paused,"RTT slider drag changes live ping")
	sample.valid_right = false
	scene._panel_input(sample)
	check(scene.slider_capture[1]<0,"tracking loss drops capture")
	sample.valid_right = true
	scene._panel_input(sample)
	check(scene.slider_capture[1]<0,"held trigger cannot reacquire after tracking return")
	sample.right_trigger = 0.0
	scene._panel_input(sample)
	scene.pilot_status.owners[1] = "PILOT"
	sample.right_trigger = 1.0
	scene._panel_input(sample)
	check(scene.slider_capture[1]<0 and not scene.pointers[1].visible,"pilot-owned hand cannot operate panel")
	scene.queue_free()
	await process_frame
	print("MELEE_PANEL_TEST checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
