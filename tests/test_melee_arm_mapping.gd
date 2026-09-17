extends SceneTree
const Mapping = preload("res://scripts/melee_arm_mapping.gd")
var checks := 0
var failures := 0
func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(caption)
func _initialize() -> void:
	var mapping := Mapping.new()
	var sample := {"focused":true,"paused":false,"left":mapping.handle_poses[0],"right":mapping.handle_poses[1],"left_trigger":0.0,"right_trigger":0.0,"head":Transform3D.IDENTITY}
	var held: Array[bool] = [true,true]
	mapping.step(sample,held)
	sample.left.origin += Vector3(.1,.1,-.1)
	sample.left.basis = Basis(Vector3.UP,.3)
	mapping.step(sample,held)
	check(mapping.targets[0].origin.distance_to(Mapping.NEUTRALS[0]+Vector3(.8,.8,-.8)) < .001,"Grabbed arm uses calibrated translation gain")
	check(mapping.targets[0].basis.is_equal_approx(sample.left.basis),"Grabbed arm follows calibrated orientation")
	var parked: Transform3D = mapping.targets[0]
	held[0] = false
	for i in 1000:
		sample.head.origin = Vector3(i*.1,sin(i),-i*.2)
		sample.left.origin = Vector3(30,-40,50)
		mapping.step(sample,held)
	check(mapping.targets[0].is_equal_approx(parked),"Parked command stays fixed through head/hand motion; no actual-feedback drift path")
	sample.left = mapping.handle_poses[0]
	sample.left.origin += Vector3(.05,0,0)
	sample.left.basis = Basis(Vector3.UP,.9)
	held[0] = true
	mapping.step(sample,held)
	check(mapping.targets[0].is_equal_approx(parked),"Regrab near parked handle preserves target and saved absolute mapping")
	mapping.begin_calibration()
	mapping.step(sample,held)
	sample.left_trigger = 1.0
	mapping.step(sample,held)
	var frozen: Transform3D = mapping.targets[0]
	sample.left.origin += Vector3(.12,-.08,.14)
	sample.left.basis = Basis(Vector3.RIGHT,.5)*sample.left.basis
	mapping.step(sample,held)
	check(mapping.adjusting[0] and mapping.targets[0].is_equal_approx(frozen),"Calibration trigger freezes arm target while handle translates and rotates")
	check(mapping.map_pose(0,mapping.handle_poses[0]).is_equal_approx(frozen),"Calibration updates both offsets to match frozen target")
	check(mapping.inverse_map(0,frozen).is_equal_approx(mapping.handle_poses[0]),"Inverse mapping places actual-arm ghost in cockpit coordinates")
	sample.left_trigger = 0.0
	sample.left.origin.z += .07
	mapping.step(sample,held)
	check(not mapping.adjusting[0] and mapping.targets[0].is_equal_approx(frozen),"Trigger release retains pose without jump")
	sample.left.origin.x += .1
	mapping.step(sample,held)
	check(mapping.targets[0].origin.distance_to(frozen.origin+Vector3(.8,0,0)) < .001,"After clutch release arm follows new translation offset")
	var before_pause: Transform3D = mapping.targets[0]
	sample.paused = true
	mapping.step(sample,held)
	sample.left.origin.x += 1
	mapping.step(sample,held)
	sample.paused = false
	mapping.step(sample,held)
	check(mapping.targets[0].is_equal_approx(before_pause),"Pause/reacquire prevents inherited hand motion")
	var path := "user://test-melee-arm-mapping-%s.cfg" % OS.get_process_id()
	check(mapping.finish_calibration(path)==OK,"Explicit finish saves calibration")
	var restored := Mapping.new()
	check(restored.load_calibration(path)==OK and restored.targets[0].is_equal_approx(mapping.targets[0]) and restored.offsets[0].is_equal_approx(mapping.offsets[0]),"Persistent calibration round-trips translation, rotation and parked handles")
	var stable_config := restored.capture_configuration()
	var bad := stable_config.duplicate(true)
	bad.gain = Vector3.ZERO
	check(restored.restore_configuration(bad)==ERR_INVALID_DATA and restored.offsets[0].is_equal_approx(stable_config.offsets[0]),"Invalid calibration cannot partially mutate mapping")
	restored.reset_targets()
	check(restored.targets[0].origin.is_equal_approx(Mapping.NEUTRALS[0]) and restored.offsets[0].is_equal_approx(stable_config.offsets[0]),"Scenario reset retains calibration while resetting robot targets")
	mapping.begin_calibration()
	mapping.step(sample,held)
	sample.left_trigger = 1
	mapping.step(sample,held)
	sample.left.origin.y += .2
	mapping.step(sample,held)
	var before_cancel: Transform3D = mapping.targets[0]
	mapping.cancel_calibration()
	check(mapping.targets[0].is_equal_approx(before_cancel) and mapping.offsets[0].is_equal_approx(stable_config.offsets[0]),"Cancel restores mapping without jumping robot command")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("MELEE_ARM_MAPPING_CHECKS %d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
