extends SceneTree

const RangeScript = preload("res://scripts/range_world.gd")
var checks := 0
var failures := 0

func check(condition: bool, caption: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(caption)

func _initialize() -> void:
	var shield := Transform3D(Basis.IDENTITY, Vector3(0, 0, -4))
	var from := Vector3(0, 0, -80)
	var to := Vector3(0, 0, 10)
	var shield_hit := RangeScript.segment_box(from, to, shield, RangeScript.SHIELD_HALF)
	var torso_hit := RangeScript.segment_box(from, to, Transform3D.IDENTITY, RangeScript.TORSO_HALF)
	check(shield_hit >= 0 and shield_hit < torso_hit, "Swept shield intersects before torso")
	check(is_equal_approx(shield_hit, 75.8 / 90.0), "Intersection fraction represents actual slab front")
	check(RangeScript.segment_box(from, to, Transform3D(Basis.IDENTITY, Vector3(6, 0, -4)), RangeScript.SHIELD_HALF) < 0, "Shield beside torso provides no protection")
	var angled := Transform3D(Basis(Vector3.UP, PI / 4), Vector3(0, 0, -4))
	check(RangeScript.segment_box(from, to, angled, RangeScript.SHIELD_HALF) >= 0, "Angled shield intercepts")
	check(RangeScript.segment_box(Vector3(0, 4, -80), Vector3(0, 4, 10), angled, RangeScript.SHIELD_HALF) < 0, "Finite height permits shot above shield")
	check(RangeScript.segment_box(Vector3(0, 0, -4), Vector3(0, 0, -5), shield, RangeScript.SHIELD_HALF) == 0, "Muzzle inside slab stops immediately")
	check(RangeScript.segment_box(Vector3(0, 0, 0), Vector3(0, 0, 2), shield, RangeScript.SHIELD_HALF) < 0, "Shield behind beam does not intercept")
	var world := RangeScript.new()
	root.add_child(world)
	world.setup()
	var muzzle := Transform3D(Basis.IDENTITY, Vector3(-18, -7, 0))
	var far_shield := Transform3D(Basis.IDENTITY, Vector3(100, 0, 0))
	var aim := world.aim_point(muzzle, far_shield)
	check(aim.distance_to(Vector3(-18, -7, -59.5)) < 0.01, "Actual offset muzzle hits 60 m target torso")
	var result := world.fire(muzzle, far_shield)
	check(result.distance_to(aim) < 0.001 and world.target_hits == 1, "Reticle and fired beam agree")
	var head_aim := world.aim_point(Transform3D.IDENTITY, far_shield)
	check(head_aim.distance_to(aim) > 10, "Head ray differs from independently offset muzzle")
	var blocking_shield := Transform3D(Basis.IDENTITY, Vector3(-18, -7, -4))
	world.fire(muzzle, blocking_shield)
	check(world.last_shot_kind == "shield" and world.target_hits == 1, "Player fire respects crossing shield")
	# Fire starts inside the wall: actual muzzle clearance wins over target.
	world.fire(Transform3D(Basis.IDENTITY, Vector3(0, 0, -245)), far_shield)
	check(world.last_shot_kind == "world", "World muzzle obstruction")
	world.reset()
	world._spawn_bolt(Vector3.ZERO)
	world.tick(2.0, Transform3D.IDENTITY, shield)
	check(world.blocks == 1 and world.hits == 0, "Single 80 m sweep cannot tunnel through shield")
	world.reset()
	world._spawn_bolt(Vector3.ZERO)
	world.tick(2.0, Transform3D.IDENTITY, far_shield)
	check(world.blocks == 0 and world.hits == 1, "Unprotected torso receives swept bolt")
	world.reset()
	world._spawn_bolt(Vector3.ZERO)
	world.tick(2.0, Transform3D.IDENTITY, Transform3D(Basis.IDENTITY, Vector3(0, 0, 4)))
	check(world.hits == 1 and world.blocks == 0, "Shield behind torso cannot steal earlier torso hit")
	for step in [1.0 / 30.0, 1.0 / 90.0, 1.0 / 144.0]:
		world.reset()
		world._spawn_bolt(Vector3.ZERO)
		for index in range(ceili(1.8 / step)):
			world.tick(step, Transform3D.IDENTITY, angled)
		check(world.blocks == 1 and world.hits == 0, "Angled sweep invariant at step %f" % step)
	world.reset()
	world.tick(2.0, Transform3D.IDENTITY, far_shield)
	check(world.telegraphing and world.bolts.is_empty(), "Emitter telegraphs half second before launch")
	world.tick(0.6, Transform3D.IDENTITY, far_shield)
	check(world.bolts.size() == 1 and world.bolts[0].position.distance_to(Vector3(0, 0, -56)) < 0.001, "Spawned bolt advances only post-emission time")
	world.reset()
	check(world.hits == 0 and world.blocks == 0 and world.target_hits == 0 and world.bolts.is_empty(), "Reset restores counters and active bolts")
	world.queue_free()
	print("RANGE_TESTS %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
