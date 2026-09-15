extends SceneTree
class ReplayAdapter:
	extends "res://scripts/input_adapter.gd"
	var current: Dictionary = {}
	func sample() -> Dictionary: return current.duplicate()
var scene
var input: ReplayAdapter
var checks := 0
var failures := 0
var previous: PackedByteArray
var had_settings := false
var shots_before := 0
func check(value: bool, caption: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(caption)
func _initialize() -> void: call_deferred("run")
func step(count := 1) -> void:
	for _i in count: scene._physics_process(1.0/90.0)
func trigger(value: float) -> void:
	input.current.right_trigger = value
	step()
func dock() -> void:
	input.current.right = Transform3D(Basis.IDENTITY,input.current.head.origin+Vector3(.3,.1,.3))
func capture() -> void:
	input.current.right = scene.handles.handles[1]
	input.current.left = scene.handles.handles[0]
	input.current.left_grip = 0.0
	input.current.right_grip = 0.0
	input.current.right_trigger = 0.0
	step(2)
	input.current.left_grip = 1.0
	input.current.right_grip = 1.0
	step(2)
func no_shot(caption: String) -> void:
	check(scene.world.shots_fired == shots_before,caption)
func run() -> void:
	had_settings = FileAccess.file_exists("user://m0a.cfg")
	if had_settings: previous = FileAccess.get_file_as_bytes("user://m0a.cfg")
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.set_process(false)
	var original = scene.adapter
	input = ReplayAdapter.new()
	input.current = original.sample()
	input.current.focused = true
	input.current.head = Transform3D.IDENTITY
	input.camera = original.camera
	input.origin = original.origin
	input.controllers = original.controllers
	scene.add_child(input)
	scene.adapter = input
	original.queue_free()
	scene.handles.enabled = true
	scene.handles.set_mode("free")
	scene.handles.reset()
	await physics_frame
	scene.paused = false
	capture()
	check(scene.handles.grabbed[0] and scene.handles.grabbed[1],"Both physical grips capture")
	scene.world.last_shot_kind = "sentinel"
	shots_before = scene.world.shots_fired
	dock()
	trigger(0.0)
	check(scene.weapon_status.dock_ready,"Physical controller reaches behind-head dock")
	check(scene.model.arm_actual[1].origin.z < 0.0,"Dock uses physical controller while servo arm still in front")
	trigger(1.0)
	check(scene.weapon.sword,"Fresh dock press swaps rifle to sword")
	no_shot("Swap press never fires rifle")
	check(scene.weapon.visual_root.visible and not scene.gun_visuals[0].visible,"Sword visible and rifle hidden outside")
	var sword_index: int = scene.hologram.sources.find(scene.weapon.visual_root)
	var gun_index: int = scene.hologram.sources.find(scene.gun_visuals[0])
	check(sword_index >= 0 and gun_index >= 0,"Hologram includes both weapon groups")
	check(scene.hologram.copies[sword_index].visible and not scene.hologram.copies[gun_index].visible,"Hologram matches sword selection")
	input.current.right.origin = Vector3(.3,-.2,-.5)
	step(60)
	no_shot("Holding swap press while bringing sword forward cannot fire")
	trigger(0.0)
	trigger(1.0)
	check(scene.weapon.sword,"Normal forward trigger leaves sword selected")
	no_shot("Fresh forward sword press cannot fire hidden rifle")
	var blade: Dictionary = scene.weapon.blade_segment()
	check((blade.tip-blade.base).normalized().dot(scene.arms[1].global_basis.y.normalized())>.99,"Sword extends from fist grip axis instead of rifle bore")

	dock()
	trigger(0.0)
	trigger(1.0)
	check(not scene.weapon.sword,"Second fresh dock press returns to rifle")
	no_shot("Returning to rifle cannot fire swap press")
	check(not scene.weapon.visual_root.visible and scene.gun_visuals[0].visible,"Exterior rifle restored")
	check(not scene.hologram.copies[sword_index].visible and scene.hologram.copies[gun_index].visible,"Hologram rifle restored")
	input.current.right.origin = Vector3(.3,-.2,-.5)
	step(40)
	no_shot("Rifle stays inhibited until swap press released")
	trigger(0.0)
	scene.cooldown = 0.0
	trigger(1.0)
	check(scene.world.last_shot_kind != "sentinel","Fresh forward rifle press fires after real release")
	scene.world.last_shot_kind = "sentinel"
	shots_before = scene.world.shots_fired
	for state in ["released_grip", "tracking", "paused"]:
		trigger(0.0)
		dock()
		if state == "released_grip": input.current.right_grip = 0.0
		elif state == "tracking": input.current.valid_right = false
		else: scene.paused = true
		step()
		trigger(1.0)
		check(not scene.weapon.sword,state+" cannot swap weapon")
		no_shot(state+" cannot fire")
		input.current.valid_right = true
		scene.paused = false
		step(3)
		check(not scene.weapon.sword,state+" held trigger after recovery cannot swap")
		capture()
	# Calibrated recovery must not turn a dock press into a swap before the
	# actual rifle has aligned and the real trigger has been released.
	scene.handles.set_mode("calibrated")
	input.current.right = scene.handles.handles[1]
	input.current.right.basis = Basis(Vector3.UP,.7)
	input.current.right_grip = 0.0
	trigger(0.0)
	input.current.right_grip = 1.0
	trigger(1.0)
	check(scene.handles.action_inhibited(1),"Calibrated acquisition inhibits action")
	dock()
	step(150)
	check(not scene.weapon.sword,"Held dock trigger cannot bypass calibrated recovery")
	no_shot("Calibrated recovery cannot shoot")
	trigger(0.0)
	step(3)
	trigger(1.0)
	check(scene.weapon.sword,"Released trigger after calibration permits fresh dock swap")
	# A swap press handed to UI must not click the cadence row.
	input.current.right_grip = 0.0
	input.current.right = scene.panel.transform*Transform3D(Basis.IDENTITY,Vector3(0,.04,.5))
	var cadence: float = scene.world.cadence
	step(3)
	check(is_equal_approx(scene.world.cadence,cadence),"Swap trigger carried onto MFD cannot click")
	scene.paused = true
	scene._reset()
	step()
	check(not scene.weapon.sword and not scene.weapon.visual_root.visible,"Cockpit reset restores rifle state")
	check(scene.gun_visuals[0].visible,"Reset restores gun mesh")
	scene.queue_free()
	await process_frame
	if had_settings:
		var file := FileAccess.open("user://m0a.cfg",FileAccess.WRITE)
		file.store_buffer(previous)
		file.close()
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path("user://m0a.cfg"))
	print("WEAPON_INTEGRATION checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
