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
func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(caption)
func _initialize() -> void: call_deferred("run")
func step(count := 1) -> void:
	for _i in count: scene._physics_process(1.0/90.0)
func capture() -> void:
	input.current.right = scene.handles.handles[1]
	input.current.right_grip = 0.0
	input.current.right_trigger = 0.0
	step(3)
	input.current.right_grip = 1.0
	step(3)
func place_target(at: Vector3) -> void:
	scene.world.targets[0].center = at
	for part in scene.world.targets[0].parts:
		part.local = Vector3.ZERO
		part.half = Vector3.ONE * .16
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
	input.current.left_grip = 0.0
	input.current.right_grip = 0.0
	input.current.valid_left = true
	input.current.valid_right = true
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
	for target in scene.world.targets:
		target.motion = Vector3.ZERO
		target.center = Vector3(1000,1000,1000)
	capture()
	check(scene.handles.grabbed[1],"Actual right grip captures rifle handle")
	step(100)
	check(not scene.scope.active,"Normal parked-rest pose does not open scope")
	input.current.right.origin = Vector3(.14,-.10,-.26)
	step(100)
	check(scene.scope.active,"Held controller near head opens actual-scene scope")
	check(scene.scope.camera.global_transform.is_equal_approx(scene.rifle.muzzle_transform()),"Actual scope camera uses rifle muzzle")
	scene.weapon.sword = true
	step()
	check(not scene.scope.active,"Sword hides actual scope")
	scene.weapon.sword = false
	step()
	input.current.right_grip = 0.0
	step()
	check(not scene.scope.active,"Releasing near-head controller hides scope")
	input.current.right = Transform3D(Basis.IDENTITY,scene.pilot.STICK_HOME)
	step(3)
	input.current.right_grip = 1.0
	step(3)
	check(scene.pilot.stick_owner == 1 and not scene.scope.active,"Pilot stick ownership cannot open rifle scope")
	input.current.right_grip = 0.0
	step(3)
	capture()
	input.current.right.origin = Vector3(.3,-.20,-.45)
	step(100)
	# Determine a reachable blade endpoint with the actual servo, then sweep
	# back into a small target there from a different physical hand position.
	scene.weapon.sword = true
	input.current.right.origin.x = .52
	step(100)
	var destination: Dictionary = scene.weapon.blade_segment()
	var contact: Vector3 = destination.tip.lerp(destination.base,.10)
	input.current.right.origin.x = .20
	step(100)
	var before: Dictionary = scene.weapon.blade_segment()
	check(before.tip.distance_to(destination.tip) > .8,"Physical hand displacement moves real servo blade")
	place_target(contact)
	step(2)
	var hits: int = scene.world.target_hits
	input.current.right.origin.x = .52
	step(100)
	check(scene.world.target_hits == hits+1,"Real servo sword crossing produces one target hit")
	check(scene.world._flashes.size() > 0 or scene.world.targets[0].hits > 0,"Sword contact generates hit confirmation")
	step(100)
	check(scene.world.target_hits == hits+1,"Stationary blade contact does not repeatedly score")
	for gate in ["pause","tracking","sword_off"]:
		if gate == "pause": scene.paused = true
		elif gate == "tracking": input.current.valid_right = false
		else: scene.weapon.sword = false
		step()
		check(not scene.world._sword_valid,gate+" clears actual-scene sweep history")
		check(scene.world.target_hits == hits+1,gate+" cannot score stationary sword contact")
		scene.paused = false
		input.current.valid_right = true
		scene.weapon.sword = true
		step()
		# First resumed pose seeds history; do not count a teleport from stale pose.
		check(scene.world.target_hits == hits+1,gate+" recovery seeds without stale slash")
		# Clear eligibility again before testing the next gate.
	# Rifle pulse starts at visible muzzle; target cannot score until time of flight.
	scene.weapon.sword = false
	capture()
	input.current.right = Transform3D(Basis.IDENTITY,Vector3(.3,-.2,-.5))
	step(100)
	var muzzle: Transform3D = scene.rifle.muzzle_transform()
	place_target(muzzle.origin-muzzle.basis.z*70.0)
	step(2)
	var rifle_hits: int = scene.world.target_hits
	var shots: int = scene.world.shots_fired
	scene.cooldown = 0.0
	input.current.right_trigger = 1.0
	step()
	check(scene.world.shots_fired == shots+1,"Fresh actual rifle trigger emits one pulse")
	check(scene.world.pulses.size() == 1,"Actual rifle emission creates traveling pulse")
	if scene.world.pulses.size() > 0:
		check(scene.world.pulses[0].position.is_equal_approx(scene.rifle.muzzle_transform().origin),"New pulse starts at visible large-rifle bore")
	check(scene.world.target_hits == rifle_hits,"Trigger does not apply immediate hitscan damage")
	input.current.right_trigger = 0.0
	step(5)
	check(scene.world.target_hits == rifle_hits,"Distant target remains unhit before pulse arrival")
	step(100)
	check(scene.world.target_hits == rifle_hits+1,"Traveling rifle pulse eventually confirms target hit")
	scene.queue_free()
	await process_frame
	if had_settings:
		var file := FileAccess.open("user://m0a.cfg",FileAccess.WRITE)
		file.store_buffer(previous)
		file.close()
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path("user://m0a.cfg"))
	print("COMBAT_INTEGRATION checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
