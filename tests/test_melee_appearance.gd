extends SceneTree
const View = preload("res://scripts/melee_view.gd")
const Replay = preload("res://scripts/melee_replay.gd")
const Physics = preload("res://scripts/melee_physics.gd")
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
	var snapshot := {"rigs":rigs,"beam_contacts":[{"saber_rig":1,"target_rig":0,"target_part":"torso","position":Vector3(0,0,1.25)}]}
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
	snapshot.beam_contacts = []
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
		var projected: Vector3 = Paint.project(hot.heat_marks[0].position,view.leaves[chest_index].get_aabb().size*.5)
		var hot_pixel := Vector2i(int(projected.x*96)+(int(projected.z)%3)*96,int(projected.y*96)+(int(projected.z)/3)*96)
		var front := painted.get_pixelv(hot_pixel).r
		check(front>.8,"GPU atlas contains hot front-face center")
		check(painted.get_pixel(240,144).r<.01,"GPU atlas opposite face is unpainted")
		view.update_snapshot(snapshot,1.0)
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		painted = view.heat_painters[chest_index].texture.get_image()
		check(painted.get_pixelv(hot_pixel).r<front-.1,"GPU painted heat fades with elapsed simulation time")
		var painter = view.heat_painters[chest_index]
		painter.paint(view.leaves[chest_index],[Vector4(0,0,1.25,.3),Vector4(0,0,1.25,.3)])
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		check(painter.texture.get_image().get_pixel(144,144).r>.55,"GPU additive paint sums overlapping heat instead of overwriting")
		await render_trail_diagnostic(view,snapshot,camera)
	check(not view.valid_appearance({"heat_marks":[{"leaf":999,"position":Vector3.ZERO,"heat":1}]}),"Malformed imported heat is rejected")
	check(not view.valid_appearance({"arm_efforts":[[NAN,0],[0,0]]}),"Nonfinite imported effort is rejected")
	view.reset_appearance()
	check(view.capture_appearance().heat_marks.is_empty(),"Reset clears previous encounter heat")
	snapshot.beam_contacts = [{"saber_rig":1,"target_rig":0,"target_part":"torso","position":Vector3(0,0,1.25)}]
	view.update_snapshot(snapshot,0.0)
	check(view.capture_appearance().heat_marks.is_empty(),"Repeated paused snapshot cannot create new heat")
	# Heating is a per-second budget, independent of how many records or new
	# spatial stamps a fast sweep produces. There is no impact flash injection.
	for hz in [60,120]:
		view.reset_appearance()
		for tick in int(.1*hz):
			var point := Vector3(-1.5+3.0*tick/(.1*hz),0,1.25)
			var contact := {"saber_rig":1,"target_rig":0,"target_part":"torso","position":point}
			snapshot.beam_contacts = [contact,contact.duplicate()]
			view.update_snapshot(snapshot,1.0/hz)
		var sum := 0.0
		for mark in view.capture_appearance().heat_marks: sum += float(mark.heat)
		check(sum<=.25001,"Fast swipe deposit is bounded by dwell seconds, not sample or duplicate count")
	view.reset_appearance()
	snapshot.beam_contacts = [{"saber_rig":1,"target_rig":0,"target_part":"torso","position":Vector3(0,0,1.25)}]
	view.update_snapshot(snapshot,.01)
	check(is_equal_approx(view.capture_appearance().heat_marks[0].heat,.025),"First contact deposits exactly ten milliseconds of heat")
	var anchored: Vector3 = view.capture_appearance().heat_marks[0].position
	snapshot.beam_contacts[0].position += Vector3(.3,0,0)
	view.update_snapshot(snapshot,.01)
	check(view.capture_appearance().heat_marks[0].position==anchored,"Moving contact cannot drag accumulated hot patch along surface")
	rigs[0].blade_fraction = .4
	view.update_snapshot(snapshot,0)
	var shell: MeshInstance3D = view.sword_visuals[0].get_child(2)
	check(is_equal_approx(shell.position.y+shell.scale.y*2.85,.65+5.7*.4),"Rendered beam ends at first armor entry")
	var clipped: Array = view.capture_visuals()
	rigs[0].blade_fraction = 1.0
	view.update_snapshot(snapshot,0)
	view.apply_visuals(clipped)
	var restored_clip: Array = view.capture_visuals()
	for index in clipped.size(): check(restored_clip[index].is_equal_approx(clipped[index]),"Replay retains clipped visual beam length")
	view.update_snapshot(snapshot,0)
	check(is_equal_approx(shell.position.y+shell.scale.y*2.85,6.35),"Live beam restores full geometry after clipped replay")
	rigs[0].blade_fraction = 0.0
	view.update_snapshot(snapshot,0)
	check(not shell.visible,"Blade beginning inside armor has no visible penetration")
	view.reset_appearance()
	# More than eight independently heated cells survive simultaneously.
	for cell in 12:
		snapshot.beam_contacts = [{"saber_rig":1,"target_rig":0,"target_part":"torso","position":Vector3(-2.1+cell*.35,0,1.25)}]
		view.update_snapshot(snapshot,.03)
	check(view.capture_appearance().heat_marks.size()>8,"Trail retains older hot cells beyond previous eight-stamp cap")
	var long_trail: Dictionary = view.capture_appearance()
	view.apply_appearance(long_trail)
	check(view.capture_appearance()==long_trail,"Persistent trail roundtrips appearance replay")
	# Query a different authoritative pose without moving delayed display.
	var displayed: Array = view.capture_visuals()
	var authoritative: Dictionary = snapshot.duplicate(true)
	authoritative.rigs[1].body.origin += Vector3(30,0,0)
	for side in 2: authoritative.rigs[1].grips[side].origin += Vector3(30,0,0)
	var surfaces: Array = view.get_armor_surfaces(authoritative)
	check(surfaces.size()>40,"All armor meshes included, rather than torso and shield only")
	check(view.geometry_query_view.metal_materials.is_empty(),"Authoritative geometry rig allocates no metal textures")
	var unchanged: Array = view.capture_visuals()
	for index in displayed.size(): check(displayed[index].is_equal_approx(unchanged[index]),"Authoritative armor query leaves delayed display unchanged")
	var leg: MeshInstance3D = view.robots[1].legs[0]
	var leg_index: int = view.leaves.find(leg)
	var leg_surface: Dictionary = {}
	for surface in surfaces:
		if surface.target_leaf==leg_index: leg_surface = surface
	check(not leg_surface.is_empty(),"Visible upper leg has an authoritative armor surface")
	check(leg_surface.transform.origin.distance_to(leg.global_position)>29,"Armor query uses authoritative limb pose despite displayed lag")
	var local_contact := Vector3(0,0,leg.get_aabb().size.z*.5)
	snapshot.beam_contacts = [{"saber_rig":0,"target_rig":1,"target_part":"armor","target_leaf":leg_index,"target_mesh_local":local_contact,"position":leg_surface.transform*local_contact}]
	view.reset_appearance()
	view.update_snapshot(snapshot,.1)
	check(view.capture_appearance().heat_marks[0].leaf==leg_index,"Limb hit paints the correct visible armor mesh")
	# Core receives all surfaces once from current physical poses; its nearest
	# query preserves stable leaf identity and the target mesh local entry point.
	var core := Physics.new()
	world.add_child(core)
	core.setup()
	core.set_physics_process(false)
	core.armor_provider = view.get_armor_surfaces
	var server_snapshot: Dictionary = core.snapshot()
	var server_surfaces: Array = view.get_armor_surfaces(server_snapshot)
	var chosen: Dictionary = {}
	for surface in server_surfaces:
		if surface.target_leaf==leg_index: chosen=surface
	var frame: Transform3D = chosen.transform
	var normal: Vector3 = frame.basis.x.normalized()
	var start: Vector3 = frame.origin+normal*(chosen.size.x*frame.basis.x.length()*.5+.4)
	var direction := -normal
	var basis := Basis.looking_at(direction,Vector3.UP if absf(direction.y)<.99 else Vector3.RIGHT)*Basis(Vector3.RIGHT,-PI/2)
	# Use an explicit orthonormal frame whose positive Y is the beam direction.
	var x_axis := direction.cross(Vector3.UP if absf(direction.y)<.99 else Vector3.RIGHT).normalized()
	basis = Basis(x_axis,direction,x_axis.cross(direction))
	core.rigs[0].weapons[1].global_transform = Transform3D(basis,start-basis*Physics.BLADE_BASE)
	var found_leg := false
	for hit in core.query_beam_contacts():
		if hit.saber_rig==0 and hit.get("target_leaf",-1)==leg_index:
			found_leg=true
			check(hit.target_mesh_local.is_finite(),"Authoritative limb query returns local heat coordinate")
	check(found_leg,"Core full-armor provider selects nearest upper-leg entry")
	core.queue_free()
	world.queue_free()
	print("MELEE_APPEARANCE_TESTS failures=",failures)
	quit(1 if failures else 0)

func render_trail_diagnostic(view: Node3D, original: Dictionary, camera: Camera3D) -> void:
	var sample: Dictionary = original.duplicate(true)
	sample.beam_contacts = []
	view.reset_appearance()
	view.update_snapshot(sample,0)
	var shield: MeshInstance3D = view.equipment[0][0].get_child(0)
	var shin: MeshInstance3D = view.robots[0].legs[1]
	var shield_index: int = view.leaves.find(shield)
	var shin_index: int = view.leaves.find(shin)
	# Two sweeps in sequence from the opposing saber, each carrying only the
	# normal per-second budget. Segment/box entry supplies true mesh-local hits.
	for target in [shield,shin]:
		for tick in 60:
			var fraction := tick/59.0
			var point := Vector3(lerpf(-1.65,1.65,fraction),1.3,.2) if target==shield else Vector3(0,.5,lerpf(-.40,.40,fraction))
			var outward := Vector3.BACK if target==shield else Vector3.UP
			var normal: Vector3 = (target.global_basis*outward).normalized()
			var world_point: Vector3 = target.to_global(point)
			var hit := Physics.segment_box_entry(world_point+normal*.3,world_point-normal*.3,target.global_transform,target.get_aabb().size)
			check(not hit.is_empty(),"Diagnostic sweep crosses its selected armor face")
			hit.merge({"saber_rig":1,"target_rig":0,"target_part":"armor","target_leaf":view.leaves.find(target),"target_mesh_local":hit.target_local_position})
			sample.beam_contacts = [hit]
			view.update_snapshot(sample,1.0/90)
	# Source has departed; no further heat input during captures or afterglow.
	sample.beam_contacts = []
	sample.rigs[1].grips[1].origin = Vector3(40,30,20)
	view.update_snapshot(sample,.25)
	var state: Dictionary = view.capture_appearance()
	var sum_before := 0.0
	var counts := {shield_index:0,shin_index:0}
	for mark in state.heat_marks:
		sum_before += float(mark.heat)
		counts[int(mark.leaf)] = int(counts.get(int(mark.leaf),0))+1
	check(counts[shield_index]>8 and counts[shin_index]>8,"Departed source leaves connected multi-cell shield and shin trails")
	view.puppet.visible = false
	camera.fov = 55
	camera.global_position = shield.global_position+Vector3(1,1.1,10)
	camera.look_at(shield.global_position+Vector3(0,.6,0))
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/melee-shield-trail.png")
	camera.fov = 40
	camera.global_position = shin.global_position+Vector3(4,1.5,7)
	camera.look_at(shin.global_position)
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/melee-limb-trail.png")
	view.update_snapshot(sample,log(2.0)/.4)
	var sum_after := 0.0
	for mark in view.capture_appearance().heat_marks: sum_after += float(mark.heat)
	check(absf(sum_after/sum_before-.5)<.001,"Trails retain exactly half their total heat after1.73 seconds without source")
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/melee-limb-trail-half-life.png")
	print("MELEE_TRAIL_DIAGNOSTIC cells=",counts," energy_before=",sum_before," energy_after_half_life=",sum_after)
	view.puppet.visible = true
	view.update_snapshot(original,0)
