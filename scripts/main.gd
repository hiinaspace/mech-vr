extends Node3D

const ControlModel = preload("res://scripts/control_model.gd")
const InputAdapter = preload("res://scripts/input_adapter.gd")
const RangeWorld = preload("res://scripts/range_world.gd")
var model = ControlModel.new()
var adapter = InputAdapter.new()
var world = RangeWorld.new()
var body := CharacterBody3D.new()
var panel := Node3D.new()
var display := Label.new()
var menu_labels: Array[Label] = []
var viewport := SubViewport.new()
var arms: Array[Node3D] = []
var segments: Array[MeshInstance3D] = []
var hands: Array[MeshInstance3D] = []
var pointers: Array[MeshInstance3D] = []
var reticle: MeshInstance3D
var pose_geometry: Array[Node3D] = []
var hologram = preload("res://scripts/pose_hologram.gd").new()
var paused := true
var cooldown := 0.0
var elapsed := 0.0
var frames := 0
var menu_down := [true, true]
var ring: Array[Dictionary] = []
var last_owners := ""
var trace: FileAccess
var replay := false
var replay_checks := {}
var settings := ConfigFile.new()
var hovered := -1
var resume_delay := 0.0
var reset_from: Array[Transform3D] = []
var reset_blend := 0.0
var slow_turn := false
var snap := false
var frame_total := 0.0
var frame_max := 0.0
var frame_count := 0
var render_cpu_sum := 0.0
var render_gpu_sum := 0.0
var render_cpu_max := 0.0
var render_gpu_max := 0.0
var physics_cpu_max := 0.0
var last_counts := Vector3i.ZERO

func _ready() -> void:
	replay = "--replay" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	trace = FileAccess.open("res://artifacts/latest-run.jsonl", FileAccess.WRITE)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	settings.load("user://m0a.cfg")
	add_child(world)
	world.setup()
	add_child(body)
	body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3,6,3)
	collider.shape = shape
	body.add_child(collider)
	add_child(adapter)
	adapter.setup(body)
	if not adapter.xr_active:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 90
	adapter.pause_requested.connect(_toggle_pause)
	adapter.reset_requested.connect(_reset)
	adapter.mark_requested.connect(_mark)
	_build_cockpit()
	_build_panel()
	body.add_child(hologram)
	hologram.setup(body,pose_geometry)
	world.cadence = float(settings.get_value("range", "cadence", 2.5))
	slow_turn = bool(settings.get_value("control","slow_turn",false))
	snap = bool(settings.get_value("control","snap_yaw",false))
	_apply_turn_settings()
	if replay:
		paused = false
		world.cadence = 2.5
		slow_turn = false
		snap = false
		_apply_turn_settings()
	log_event("startup", {"engine": Engine.get_version_info().string, "renderer": "gl_compatibility", "replay": replay, "world_scale": XRServer.world_scale,"physics_hz":Engine.physics_ticks_per_second,"cadence":world.cadence,"gain":str(model.position_gain),"arm_speed":model.arm_speed,"arm_acceleration":model.arm_acceleration,"arm_angular_speed":model.arm_angular_speed,"yaw_speed":model.yaw_speed,"pitch_speed":model.pitch_speed,"snap":snap,"fixed_fps":OS.get_cmdline_args().has("--fixed-fps")})
	print("M0A_READY desktop=%s replay=%s; start paused, R calibrates, Esc resumes" % [not adapter.xr_active, replay])

func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	node.material_override = mat
	parent.add_child(node)
	node.position = pos
	return node

func _build_cockpit() -> void:
	box(body, Vector3(.52,.12,.5), Vector3(0,-.65,.08), Color("3c5262"))
	box(body, Vector3(.52,.7,.09), Vector3(0,-.3,.34), Color("3c5262"))
	for side in [-1,1]:
		box(body, Vector3(.06,.06,1.3), Vector3(side*.65,-.45,-.4), Color("647b8c"))
		box(body, Vector3(.05,1.2,.05), Vector3(side*.65,.05,-1), Color("647b8c"))
		box(body, Vector3(.12,.08,.35), Vector3(side*.35,-.35,-.3), Color("a7bac8"))
	pose_geometry.append(box(body, Vector3(1.35,.05,.05), Vector3(0,.65,-1), Color("647b8c")))
	# Torso sits below the human canopy, never wraps/occludes the camera.
	pose_geometry.append(box(body, Vector3(6,16,3), Vector3(0,-9.35,1), Color("28394b")))
	for i in range(2):
		var arm := Node3D.new()
		body.add_child(arm)
		arms.append(arm)
		if i == 0:
			box(arm, Vector3(4,6,.4), Vector3.ZERO, Color("247994"))
			box(arm, Vector3(3.5,.12,.43), Vector3(0,0,0), Color("75dfff"))
		else:
			box(arm, Vector3(.6,.8,2), Vector3(0,0,-.7), Color("b3a387"))
			box(arm, Vector3(.22,.22,1.2), Vector3(0,0,-2.1), Color("dfbd6c"))
		segments.append(box(body, Vector3(.6,.6,1), Vector3.ZERO, Color("526475")))
		segments.append(box(body, Vector3(.5,.5,1), Vector3.ZERO, Color("768693")))
		hands.append(box(body, Vector3(.06,.06,.14), Vector3.ZERO, Color("fcce74") if i else Color("71d6ee")))
		pointers.append(box(body, Vector3(.005,.005,1), Vector3.ZERO, Color("6dffd9")))
	pose_geometry.append_array(arms)
	pose_geometry.append_array(segments)
	reticle = box(self, Vector3(.15,.15,.15), Vector3(0,0,-50), Color("ffef78"))

func _build_panel() -> void:
	body.add_child(panel)
	panel.position = Vector3(0,-.65,-.85)
	panel.rotation_degrees.x = -45
	viewport.size = Vector2i(800,600)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var bg := ColorRect.new()
	bg.color = Color("081d2b")
	bg.size = Vector2(800,600)
	viewport.add_child(bg)
	display.position = Vector2(24,18)
	display.size = Vector2(752,564)
	display.add_theme_font_size_override("font_size",26)
	viewport.add_child(display)
	for row in range(6):
		var label := Label.new()
		label.position = Vector2(24,row*100+18)
		label.add_theme_font_size_override("font_size",26)
		viewport.add_child(label)
		menu_labels.append(label)
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(.64,.48)
	quad.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = viewport.get_texture()
	quad.material_override = mat
	panel.add_child(quad)

func _physics_process(dt: float) -> void:
	elapsed += dt
	frames += 1
	var sample: Dictionary = adapter.sample()
	if replay:
		sample = replay_sample(elapsed)
		adapter.camera.transform = sample.head
	sample.paused = paused or resume_delay > 0.0
	resume_delay = maxf(0.0, resume_delay-dt)
	var result: Dictionary = model.step(sample,dt)
	body.basis = result.body_basis
	body.velocity = model.velocity
	if not result.paused:
		body.move_and_slide()
		for collision_index in body.get_slide_collision_count():
			var normal := body.get_slide_collision(collision_index).get_normal()
			if body.velocity.dot(normal) < 0:
				body.velocity = body.velocity.slide(normal)
		model.velocity = body.velocity
	for i in range(2):
		arms[i].transform = model.arm_actual[i]
		if reset_blend > 0 and reset_from.size() == 2:
			arms[i].transform = reset_from[i].interpolate_with(model.arm_actual[i],1.0-reset_blend/.6)
		var hand_pose: Transform3D = sample.left if i == 0 else sample.right
		hands[i].transform = hand_pose
		hands[i].visible = sample.get("valid_left" if i == 0 else "valid_right",true)
		var shoulder := Vector3(-3.5 if i == 0 else 3.5,-2,1)
		var end := arms[i].position
		var elbow := (shoulder+end)*.5 + Vector3(-1.5 if i == 0 else 1.5,-1.5,0)
		_segment(segments[i*2],shoulder,elbow,.6)
		_segment(segments[i*2+1],elbow,end,.5)
	hologram.sync()
	reset_blend = maxf(0,reset_blend-dt)
	var muzzle := arms[1].global_transform * Transform3D(Basis.IDENTITY,Vector3(0,0,-2.7))
	var shield := arms[0].global_transform
	cooldown = maxf(0,cooldown-dt)
	if not result.paused:
		world.tick(dt,body.global_transform,shield)
		if result.fire and cooldown <= 0:
			world.fire(muzzle,shield)
			cooldown = .15
			log_event("fire", {"muzzle": str(muzzle)})
	reticle.global_position = world.aim_point(muzzle,shield)
	reticle.scale = Vector3.ONE * maxf(1.0,muzzle.origin.distance_to(reticle.global_position)*.015)
	var counts := Vector3i(world.target_hits,world.blocks,world.hits)
	if counts != last_counts:
		log_event("combat_result",{"targets":counts.x,"blocks":counts.y,"torso_hits":counts.z})
		last_counts = counts
	var owner_text := str(model.owners)
	if owner_text != last_owners:
		log_event("ownership", {"owners":model.owners})
		last_owners = owner_text
	_panel_input(sample,result)
	_update_display(result,muzzle)
	if frames % 9 == 0:
		var row := {"t":elapsed,"position":str(body.position),"velocity":str(model.velocity),"head":str(sample.head),"left":str(sample.left),"right":str(sample.right),"owners":model.owners.duplicate(),"actual":str(model.arm_actual),"desired":str(model.arm_targets),"boost":model.boost,"brake":sample.brake,"hits":world.hits,"blocks":world.blocks,"target_hits":world.target_hits}
		ring.append(row)
		if ring.size() > 300: ring.pop_front()
		if replay: trace.store_line(JSON.stringify(row))
	if replay and elapsed >= 12:
		log_event("replay_end",{"checks":replay_checks,"position":str(body.position),"blocks":world.blocks,"hits":world.hits})
		print("M0A_REPLAY_COMPLETE checks=",replay_checks)
		trace.flush()
		get_tree().quit(0 if replay_checks.size() >= 4 and not false in replay_checks.values() else 1)

func _segment(mesh: MeshInstance3D, a: Vector3, b: Vector3, width: float) -> void:
	mesh.position = (a+b)*.5
	mesh.scale = Vector3(1,1,a.distance_to(b))
	if a.distance_to(b) > .001:
		mesh.look_at(body.to_global(b),body.basis.y)

func panel_hit(pose: Transform3D) -> Vector2:
	var local := panel.transform.affine_inverse() * pose
	var direction := -local.basis.z
	if direction.z >= -.001: return Vector2(-1,-1)
	var distance := -local.origin.z / direction.z
	if distance < 0 or distance > 4: return Vector2(-1,-1)
	var point := local.origin+direction*distance
	if absf(point.x) > .32 or absf(point.y) > .24: return Vector2(-1,-1)
	return Vector2((point.x/.64+.5)*800,(.5-point.y/.48)*600)

func _panel_input(sample: Dictionary, result: Dictionary) -> void:
	hovered = -1
	for i in range(2):
		var pose: Transform3D = sample.left if i == 0 else sample.right
		var valid: bool = sample.get("valid_left" if i == 0 else "valid_right",true) and sample.focused
		var active: bool = valid and (paused or model.owners[i] == "UI")
		pointers[i].visible = active
		pointers[i].transform = pose * Transform3D(Basis.IDENTITY,Vector3(0,0,-.45))
		var uv := panel_hit(pose) if active else Vector2(-1,-1)
		var trigger: float = sample.left_trigger if i == 0 else sample.right_trigger
		var fresh: bool = trigger > .55 and not menu_down[i]
		menu_down[i] = trigger > .55 or not valid
		if uv.x < 0: continue
		hovered = int(uv.y/100)
		var clicked: bool = fresh if paused else (result.click_left if i == 0 else result.click_right)
		if not clicked: continue
		if paused:
			if uv.y >= 200 and uv.y < 300: _reset()
			elif uv.y >= 300 and uv.y < 400: _toggle_pause()
			elif uv.y >= 400 and uv.y < 500:
				slow_turn = not slow_turn
				_apply_turn_settings()
			elif uv.y >= 500:
				snap = not snap
				_apply_turn_settings()
		else:
			world.cadence = 4.0 if world.cadence < 3 else 2.5
			settings.set_value("range","cadence",world.cadence)
			if not replay: settings.save("user://m0a.cfg")
			log_event("mfd_click",{"hand":i,"cadence":world.cadence})

func _apply_turn_settings() -> void:
	# Tunables are kept in the single control model.
	model.set_turn_options(slow_turn,snap)
	settings.set_value("control","slow_turn",slow_turn)
	settings.set_value("control","snap_yaw",snap)
	if not replay: settings.save("user://m0a.cfg")

func _update_display(result: Dictionary, muzzle: Transform3D) -> void:
	display.visible = not paused
	var rows := ["M0a / PAUSED — PRESET A", "Aim either hand + fresh trigger", "RESET / SEATED CALIBRATE [R]", "RESUME [Esc / right stick click]", "TURN: %s (click)" % ("LOW 15 / 10" if slow_turn else "30 / 20 deg/s"), "SNAP YAW: %s (click)" % ("ON" if snap else "OFF")]
	for row in range(6):
		menu_labels[row].visible = paused
		menu_labels[row].text = rows[row]
		menu_labels[row].modulate = Color("7cffe0") if hovered == row and row >= 2 else Color.WHITE
	if paused:
		pass
	else:
		var velocity: Vector3 = body.basis.inverse()*model.velocity
		display.text = "M0a / A — TRACKED ARMS\nSPEED %4.1f  BOOST %3.0f%%\nVEL %+.1f %+.1f %+.1f\nR STICK: %s%s\nLEFT: %s\nRIGHT: %s\nRANGE %3.0fm  STOP %.1fm\nTARGET %s BLOCK %s HIT %s\n\nEMITTER %.1fs — CLICK TO CHANGE\nB/Y: ARM <> UI; release trigger\nX brake  /  A vertical-pitch\nEsc/menu pause; F8 mark issue" % [model.velocity.length(),model.boost*100,velocity.x,velocity.y,velocity.z,"PITCH" if result.attitude_mode else "VERTICAL"," / NEUTRAL!" if result.mode_neutral_required or result.movement_neutral_required else "",_owner_label(0),_owner_label(1),muzzle.origin.distance_to(reticle.global_position),model.velocity.length_squared()/90.0,str(world.target_hits),str(world.blocks),str(world.hits),world.cadence]

func _owner_label(index: int) -> String:
	if model.owners[index] == "UI": return "ARM HOLD / HAND UI"
	if model.owners[index] == "HOLD": return "HOLD — TRACKING / PAUSE"
	return "ARM CONTROL"

func _toggle_pause() -> void:
	paused = not paused
	menu_down = [true,true]
	log_event("pause",{"paused":paused})

func _reset() -> void:
	if not paused: return
	reset_from = model.arm_actual.duplicate()
	adapter.recenter()
	model.reset()
	body.transform = Transform3D.IDENTITY
	world.reset()
	reset_blend = .6
	resume_delay = .6
	_apply_turn_settings()
	log_event("reset",{})

func _mark() -> void:
	var file := FileAccess.open("res://artifacts/issue-%d.json" % Time.get_ticks_msec(),FileAccess.WRITE)
	file.store_string(JSON.stringify(ring,"\t"))
	log_event("issue_mark",{"samples":ring.size()})

func log_event(kind: String, data: Dictionary) -> void:
	if trace:
		trace.store_line(JSON.stringify({"event":kind,"t":elapsed,"data":data}))
		trace.flush()

func _process(dt: float) -> void:
	if "--capture" in OS.get_cmdline_user_args() and frame_count == 100 and DisplayServer.get_name() != "headless":
		get_viewport().get_texture().get_image().save_png("res://artifacts/cockpit.png")
	var cpu := RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid())
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
	render_cpu_sum += cpu
	render_gpu_sum += gpu
	render_cpu_max = maxf(render_cpu_max,cpu)
	render_gpu_max = maxf(render_gpu_max,gpu)
	physics_cpu_max = maxf(physics_cpu_max,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
	frame_total += dt
	frame_max = maxf(frame_max,dt)
	frame_count += 1

func _exit_tree() -> void:
	log_event("frame_summary",{"frames":frame_count,"mean_frame_ms":frame_total/maxi(frame_count,1)*1000,"max_frame_ms":frame_max*1000,"render_cpu_mean_ms":render_cpu_sum/maxi(frame_count,1),"render_gpu_mean_ms":render_gpu_sum/maxi(frame_count,1),"render_cpu_max_ms":render_cpu_max,"render_gpu_max_ms":render_gpu_max,"physics_cpu_max_ms":physics_cpu_max,"note":"Godot viewport timing; zero may mean unsupported. No compositor missed/reprojected frame or physical latency measurement."})

func replay_sample(t: float) -> Dictionary:
	var left := Transform3D(Basis.IDENTITY,Vector3(-.25,-.25,-.4))
	var right := Transform3D(Basis.IDENTITY,Vector3(.25,-.25,-.4))
	var head := Transform3D(Basis.from_euler(Vector3(0,sin(t)*.4,0)),Vector3.ZERO)
	if t > 3: left.origin.x += .6
	if t > 4: right.basis = Basis.from_euler(Vector3(0,.12*sin(t),0))
	if t > 5 and t < 6.1:
		right.basis = Basis.looking_at(panel.position-right.origin,Vector3.UP)
	var s := {"head":head,"left":left,"right":right,"valid_left":true,"valid_right":true,"focused":true,"move":Vector3.RIGHT if t < 1 else Vector3.ZERO,"yaw":0.0,"vertical":0.0,"mode_toggle":false,"ui_left":false,"ui_right":t > 5 and t < 5.1 or t > 6 and t < 6.1,"left_trigger":0.0,"right_trigger":1.0 if t > 2 else 0.0,"brake":t > 1 and t < 2}
	if t > 5.25 and t < 5.4 or t > 6.5 and t < 6.65:
		s.right_trigger = 0.0
	if t > 5.5 and t < 5.6: replay_checks.live_mfd_clicked = is_equal_approx(world.cadence,4.0)
	if t > 9: replay_checks.shield_blocks = world.blocks > 0
	if t > 1.9 and t < 2: replay_checks.brake_stopped = model.velocity.length() < .01
	if t > 5.2 and t < 5.3: replay_checks.ui_holds = model.owners[1] == "UI"
	if t > 6.2 and t < 6.3: replay_checks.reattached = model.owners[1] == "ARM"
	if t > 7: replay_checks.no_head_steering = absf(model.yaw) < .001 and absf(model.pitch) < .001
	return s
