extends SceneTree
const View = preload("res://scripts/melee_view.gd")
const Replay = preload("res://scripts/melee_replay.gd")
const Paint = preload("res://scripts/melee_heat_paint.gd")
var failures := 0
func check(ok: bool, why: String) -> void:
	if not ok:
		failures += 1
		push_error(why)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var view := View.new()
	world.add_child(view)
	view.setup()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(16,8,22)
	camera.look_at(Vector3(0,-1,-5))
	view.setup_puppet(camera)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("223345")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("bccfe0")
	settings.ambient_light_energy = .65
	environment.environment = settings
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	world.add_child(sun)
	sun.rotation_degrees = Vector3(-40,-30,0)
	sun.light_energy = 2.0
	var rigs: Array = []
	for body in [Transform3D.IDENTITY,Transform3D(Basis(Vector3.UP,PI),Vector3(0,0,-13))]:
		rigs.append({"body":body,"grips":[body*Transform3D(Basis.IDENTITY,Vector3(-5,2.9,-6)),body*Transform3D(Basis.IDENTITY,Vector3(5,2.9,-6))],"loads":[{"effort":.25},{"effort":1.0}]})
	var snapshot := {"rigs":rigs,"contacts":[{"saber_rig":1,"target_rig":0,"target_part":"torso","position":Vector3(0,0,1.25)}]}
	for i in 40: view.update_snapshot(snapshot,1.0/90)
	var hot: Dictionary = view.capture_appearance()
	check(hot.heat_marks.size()==1,"Repeated contact merges localized heat")
	check(hot.heat_marks[0].heat > .95,"Maintained contact heats patch")
	var chest_index: int = view.leaves.find(view.robots[0].chest)
	check(view.heat_painters[chest_index].texture is DrawableTexture2D,"Contact paint uses actual DrawableTexture2D")
	for index in view.miniature_arm_indices:
		var arm: Vector2i = view.miniature_arm_indices[index]
		if arm.y==1:
			check(view.puppet_leaves[index].material_override.albedo_color.is_equal_approx(Color("ef3439")),"Loaded miniature arm turns red")
	var replay := Replay.new()
	replay.record(.1,{"appearance":hot})
	check(replay.begin_replay(),"Appearance recorded in replay")
	check(replay.save_file("/tmp/melee-appearance-replay.json")==OK,"Appearance is replay-file serializable")
	snapshot.contacts = []
	view.update_snapshot(snapshot,2.0)
	check(view.capture_appearance().heat_marks[0].heat < hot.heat_marks[0].heat,"Contact heat fades")
	view.apply_appearance(hot)
	check(view.capture_appearance()==hot,"Seeking restores exact heat and arm loads")
	check(Paint.project(Vector3(0,0,.2),Vector3(2,3,.2)).z==4,"Shield front maps to its own face atlas tile")
	check(Paint.project(Vector3(0,0,-.2),Vector3(2,3,.2)).z==5,"Shield back stays separate")
	if "--render" in OS.get_cmdline_user_args():
		for i in 60: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/melee-appearance.png")
		var painted: Image = view.heat_painters[chest_index].texture.get_image()
		var front := painted.get_pixel(144,144).r
		check(front>.8,"GPU atlas contains hot front-face center")
		check(painted.get_pixel(240,144).r<.01,"GPU atlas opposite face is unpainted")
		view.update_snapshot(snapshot,1.0)
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		painted = view.heat_painters[chest_index].texture.get_image()
		check(painted.get_pixel(144,144).r<front-.1,"GPU painted heat fades with elapsed simulation time")
	check(not view.valid_appearance({"heat_marks":[{"leaf":999,"position":Vector3.ZERO,"heat":1}]}),"Malformed imported heat is rejected")
	check(not view.valid_appearance({"arm_efforts":[[NAN,0],[0,0]]}),"Nonfinite imported effort is rejected")
	view.reset_appearance()
	check(view.capture_appearance().heat_marks.is_empty(),"Reset clears previous encounter heat")
	snapshot.contacts = [{"saber_rig":1,"target_rig":0,"target_part":"torso","position":Vector3(0,0,1.25)}]
	view.update_snapshot(snapshot,0.0)
	check(view.capture_appearance().heat_marks.is_empty(),"Repeated paused snapshot cannot create new heat")
	world.queue_free()
	print("MELEE_APPEARANCE_TESTS failures=",failures)
	quit(1 if failures else 0)
