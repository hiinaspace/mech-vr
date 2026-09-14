extends SceneTree
## Real scene integration with deterministic adapter samples. No OpenXR session.

class ReplayAdapter:
	extends "res://scripts/input_adapter.gd"
	var current: Dictionary = {}
	func sample() -> Dictionary:
		return current.duplicate()

var scene
var input: ReplayAdapter
var checks := 0
var failures := 0
var previous_settings: PackedByteArray
var had_settings := false
var settings_path := "user://m0a.cfg"

func check(condition: bool, caption: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(caption)

func _initialize() -> void:
	call_deferred("run")

func step(dt: float = 1.0 / 90.0) -> void:
	scene._physics_process(dt)

func aim_row(row: int) -> void:
	input.current.right = scene.panel.transform * Transform3D(Basis.IDENTITY, Vector3(0, .24-(row+.5)*.08, .5))

func release() -> void:
	input.current.right_trigger = 0.0
	step()

func press() -> void:
	input.current.right_trigger = 1.0
	step()

func run() -> void:
	had_settings = FileAccess.file_exists(settings_path)
	if had_settings:
		previous_settings = FileAccess.get_file_as_bytes(settings_path)
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.set_physics_process(false)
	var original = scene.adapter
	input = ReplayAdapter.new()
	input.current = original.sample()
	input.current.focused = true
	input.camera = original.camera
	input.controllers = original.controllers
	input.origin = original.origin
	scene.add_child(input)
	scene.adapter = input
	original.queue_free()
	await physics_frame
	check(not input.xr_active and not root.use_xr, "Integration adapter remains desktop with no live OpenXR")
	check(scene.paused, "Actual scene starts in calibration pause")
	for row in range(6):
		aim_row(row)
		var uv: Vector2 = scene.panel_hit(input.current.right)
		check(absf(uv.x-400) < .01 and absf(uv.y-(row+.5)*100) < .01, "Panel ray maps exact row %d" % row)
	var misses := Transform3D(Basis.IDENTITY, Vector3(4, 0, 0))
	check(scene.panel_hit(misses).x < 0, "Ray outside panel bounds misses")
	check(scene.panel_hit(Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)).x < 0, "Backward pointer cannot click panel")
	aim_row(0)
	release()
	press()
	check(scene.paused, "Paused title row is inert")
	scene.body.position = Vector3(10, 5, 2)
	scene.world.hits = 9
	scene.world.target_hits = 4
	aim_row(2)
	release()
	press()
	check(scene.paused and scene.body.position.is_zero_approx() and scene.world.hits == 0 and scene.world.target_hits == 0, "Exact reset row restores body/range while paused")
	check(scene.reset_blend > 0 and scene.resume_delay > 0, "Reset blends arms and inhibits gameplay during calibration")
	aim_row(4)
	release()
	press()
	check(scene.slow_turn and is_equal_approx(scene.model.yaw_speed, deg_to_rad(15)), "Turn row changes actual model tuning")
	aim_row(5)
	release()
	press()
	check(scene.snap and scene.model.snap_yaw, "Snap row changes actual model mode")
	for i in range(70):
		release()
	aim_row(3)
	release()
	press()
	check(not scene.paused, "Exact resume row resumes actual scene")
	release()
	scene.world.cadence = 2.5
	# A held combat trigger cannot become a UI click across explicit handoff.
	press()
	input.current.ui_right = true
	step()
	check(scene.model.owners[1] == "UI" and is_equal_approx(scene.world.cadence, 2.5), "Held trigger entering UI cannot click cadence")
	var held: Transform3D = scene.model.arm_actual[1]
	input.current.ui_right = false
	aim_row(3)
	for i in range(8):
		step()
	check(scene.model.arm_actual[1].is_equal_approx(held), "Live right hand panel pointing holds actual rifle pose")
	release()
	press()
	check(is_equal_approx(scene.world.cadence, 4), "Fresh live UI click changes emitter cadence")
	for i in range(8):
		step()
	check(is_equal_approx(scene.world.cadence, 4), "Held live click produces only one cadence change")
	# Returning to ARM with a held trigger must not fire immediately.
	input.current.ui_right = true
	scene.world.last_shot_kind = "integration_sentinel"
	scene.cooldown = 0
	step()
	check(scene.model.owners[1] == "ARM" and scene.world.last_shot_kind == "integration_sentinel", "Held UI trigger returning to arm cannot fire")
	input.current.ui_right = false
	release()
	press()
	check(scene.world.last_shot_kind != "integration_sentinel", "Fresh press after reattachment fires actual range weapon")
	var muzzle: Transform3D = scene.arms[1].global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0, -2.7))
	var shield: Transform3D = scene.arms[0].global_transform
	var fired: Vector3 = scene.world.fire(muzzle, shield)
	check(fired.distance_to(scene.reticle.global_position) < .001, "Scene reticle agrees with actual muzzle fire result")
	release()
	var timer: float = scene.world._until_shot
	var position: Vector3 = scene.body.position
	input.current.focused = false
	input.current.move = Vector3.FORWARD
	input.current.right_trigger = 1.0
	scene.world.last_shot_kind = "focus_sentinel"
	for i in range(30):
		step()
	check(is_equal_approx(scene.world._until_shot, timer) and scene.body.position.is_equal_approx(position), "Lost focus freezes world timer and body movement")
	check(scene.world.last_shot_kind == "focus_sentinel", "Lost focus suppresses firing")
	input.current.focused = true
	input.current.move = Vector3.ZERO
	release()
	# Traverse toward the real range wall using actual CharacterBody collision.
	scene.model.set_turn_options(false, false)
	scene.body.position = Vector3(0, 0, -239)
	scene.model.velocity = Vector3(0, 0, -12)
	input.current.move = Vector3.FORWARD
	await physics_frame
	for i in range(45):
		step(1.0 / 90.0)
		await physics_frame
	check(scene.body.position.z >= -241.51 and scene.body.position.z < -240.0, "Actual body collider stops at far wall with torso clearance")
	print("WALL_INTEGRATION position=",scene.body.position," model_velocity=",scene.model.velocity," body_velocity=",scene.body.velocity," collisions=",scene.body.get_slide_collision_count())
	check(absf(scene.model.velocity.z) < .01, "Wall collision feeds blocked velocity back into model")
	input.current.move = Vector3.ZERO
	# Reset is not an unannounced live recenter.
	position = scene.body.position
	scene._reset()
	check(scene.body.position.is_equal_approx(position), "Live reset request cannot recenter unpaused suit")
	scene.queue_free()
	await process_frame
	if had_settings:
		var settings_file := FileAccess.open(settings_path, FileAccess.WRITE)
		settings_file.store_buffer(previous_settings)
		settings_file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	print("INTEGRATION_TESTS %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
