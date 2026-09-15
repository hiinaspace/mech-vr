extends SceneTree
const View = preload("res://scripts/melee_view.gd")
var checks := 0
var failures := 0
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var view := View.new()
	world.add_child(view)
	view.setup()
	view.setup_puppet(world)
	var frame := Transform3D(Basis.from_euler(Vector3(.2,.8,.1)),Vector3(30,12,-6))
	var foe := frame*Transform3D(Basis(Vector3.UP,PI),Vector3(0,0,-13))
	var rigs: Array = []
	for pose in [frame,foe]:
		rigs.append({"body":pose,"grips":[pose*Transform3D(Basis.IDENTITY,Vector3(-3,0,-5)),pose*Transform3D(Basis.IDENTITY,Vector3(3,1,-5))]})
	view.update_snapshot({"rigs":rigs},.016)
	check(view.robots[0].chest.global_position.distance_to(frame.origin)<.001,"Authored chest aligns with physical torso COM")
	for i in 2:
		for side in 2:
			check(view.equipment[i][side].global_transform.is_equal_approx(rigs[i].grips[side]),"Equipment preserves actual world frame")
	var recorded := view.capture_visuals()
	var puppet_record: Array[Transform3D] = []
	for leaf in view.puppet_leaves: puppet_record.append(leaf.transform)
	view.suits[0].position += Vector3(100,0,0)
	view.suits[1].rotate_y(1.0)
	view.apply_visuals(recorded)
	var restored := view.capture_visuals()
	for i in recorded.size(): check(recorded[i].is_equal_approx(restored[i]),"Replay restores resolved visual transform/visibility")
	for i in puppet_record.size(): check(puppet_record[i].is_equal_approx(view.puppet_leaves[i].transform),"Replay puppet copies original resolved pose")
	# A replay frame can hide a mesh which is normally visible during live play.
	var hidden := recorded.duplicate()
	hidden[2] = Transform3D(Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO),Vector3.ZERO)
	view.apply_visuals(hidden)
	check(not view.leaves[0].visible,"Replay hidden leaf applies")
	view.update_snapshot({"rigs":rigs},.016)
	check(view.leaves[0].visible,"Live update restores mesh hidden by replay")
	for robot in view.robots:
		for flame in robot.flames: check(not flame.visible,"Inactive live engine flame remains hidden")
	for leaf in view.puppet_leaves:
		if not leaf.visible: continue
		for corner in 8:
			var point: Vector3 = leaf.transform*leaf.get_aabb().get_endpoint(corner)
			check(absf(point.x)<=.17001 and absf(point.y)<=.15001 and absf(point.z)<=.17001,"Both full poses fit common miniature footprint")
	world.queue_free()
	print("MELEE_VIEW_TESTS checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
