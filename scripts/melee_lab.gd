extends Node3D
## Seated contact laboratory. Tracking, actuator commands and solved poses stay
## separate; replay restores visual samples while the live simulation is frozen.
const ControlModel = preload("res://scripts/control_model.gd")
const Adapter = preload("res://scripts/input_adapter.gd")
const Physics = preload("res://scripts/melee_physics.gd")
const Replay = preload("res://scripts/melee_replay.gd")
const View = preload("res://scripts/melee_view.gd")
const ROW_HEIGHT := .065
const PANEL_WIDTH := .60
const COCKPIT_OFFSET := Vector3(0,4.9,-1)
const MODE_NAMES := ["GUARD", "REPEATED CUT", "SLAB"]
var physics = Physics.new()
var delay = preload("res://scripts/melee_delay.gd").new()
var appearance_time := 0.0
var recorder = Replay.new()
var view = View.new()
var model = ControlModel.new()
var arm_mapping = preload("res://scripts/melee_arm_mapping.gd").new()
var cockpit_feedback = preload("res://scripts/melee_cockpit_feedback.gd").new()
var calibration_path := "user://melee-arm-calibration.cfg"
var pilot = preload("res://scripts/pilot_controls.gd").new()
var pilot_status := {"owners":["",""]}
var handles = preload("res://scripts/cockpit_handles.gd").new()
var adapter = Adapter.new()
var cockpit := Node3D.new()
var panel := Node3D.new()
var rows: Array[Label3D] = []
var handle_meshes: Array[MeshInstance3D] = []
var hand_meshes: Array[MeshInstance3D] = []
var pointers: Array[MeshInstance3D] = []
var markers: Array[MeshInstance3D] = []
var contact_marker: MeshInstance3D
var plate_visual: MeshInstance3D
var thrust_visuals: Array[MeshInstance3D] = []
var status: Label3D
var note_edit := LineEdit.new()
var note_layer := CanvasLayer.new()
var contact_audio := AudioStreamPlayer3D.new()
var load_audio := AudioStreamPlayer.new()
var paused := true
var mode := 0
var fixed_opponent := true
var physical_camera := false
var free_replay := false
var grip_controls := true
var bracing := 0
var hovered := -1
var tuning_page := false
var slider_capture := [-1,-1]
var slider_tracks: Array[MeshInstance3D] = []
var slider_knobs: Array[MeshInstance3D] = []
const TUNING := [
	["ARM FORCE", "arm_force_limit", 1000.0, 180000.0, "kN"],
	["ARM TORQUE", "arm_torque_limit", 1000.0, 180000.0, "kNm"],
	["ARM RESPONSE", "arm_response", .25, 4.0, "x"],
	["THRUST", "thrust_limit", 0.0, 900000.0, "kN"],
	["ATTITUDE", "attitude_limit", 0.0, 1500000.0, "kNm"],
	["SLASH SPEED", "slash_speed", .5, 10.0, "rad/s"],
	["PING RTT", "rtt_ms", 0.0, 400.0, "ms"]
]
var rtt_ms := 0.0
var trigger_down := [true, true]
var pointer_active := [false, false]
var live_cockpit := Transform3D.IDENTITY
var last_snapshot: Dictionary = {}
var sim_time := 0.0
var contact_cooldown := 0.0
var contact_count := 0
var message := "Calibrate seated, then resume. Grip nearby handles to command arms."
var demo := false
var demo_time := 0.0
var recording_accum := 0.0
var frames := 0
var max_frame_ms := 0.0
var frame_total := 0.0
var trace: FileAccess

func _ready() -> void:
	process_physics_priority = 0
	demo = "--demo" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	trace = FileAccess.open("res://artifacts/melee-events.jsonl", FileAccess.WRITE)
	var world = preload("res://scripts/range_world.gd").new()
	add_child(world)
	world.setup()
	add_child(physics)
	physics.setup()
	physics.set_paused(true)
	add_child(view)
	view.setup()
	physics.armor_provider = view.get_armor_surfaces
	_setup_melee_lighting()
	add_child(cockpit)
	add_child(adapter)
	adapter.setup(cockpit)
	adapter.pause_requested.connect(_toggle_pause)
	adapter.reset_requested.connect(_reset)
	adapter.mark_requested.connect(_mark)
	if not adapter.xr_active:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 90
		if "--capture" in OS.get_cmdline_user_args():
			get_window().content_scale_size = Vector2i(1280,900)
			get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
			get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	if not demo and not "--script" in OS.get_cmdline_args():
		var config_error: Error = arm_mapping.load_calibration(calibration_path)
		if config_error not in [OK,ERR_FILE_NOT_FOUND]: message = "Saved arm calibration could not be loaded."
	arm_mapping.reset_targets()
	handles.handles.assign(arm_mapping.handle_poses)
	_build_cockpit()
	cockpit.add_child(cockpit_feedback)
	cockpit_feedback.setup()
	pilot.setup_visual(cockpit)
	view.setup_puppet(cockpit)
	_build_panel()
	_build_audio()
	if "--capture-tuning" in OS.get_cmdline_user_args():
		tuning_page = true
		adapter.camera.rotation.x = -.65
	for i in 2:
		var marker := _box(self,Vector3(.16,.16,.16),Vector3.ZERO,Color("ffcc65"))
		markers.append(marker)
	contact_marker = _box(self,Vector3(.28,.28,.28),Vector3.ZERO,Color("fff4bf"))
	contact_marker.visible = false
	plate_visual = _box(self,Vector3(7,10,.6),physics.fixture.global_position,Color("506b80"))
	plate_visual.visible = false
	_label(plate_visual,"CONTACT PLATE",Vector3(0,3.6,.34),.007)
	for i in 2:
		thrust_visuals.append(_box(self,Vector3.ONE,Vector3.ZERO,Color("6ffff0")))
	last_snapshot = physics.snapshot()
	delay.reset(_neutral_command(),last_snapshot)
	view.update_snapshot(last_snapshot,0.0)
	_update_display()
	if demo:
		message = "Scripted contact demonstration"
		paused = false
		physics.set_paused(false)
	var args := OS.get_cmdline_user_args()
	var replay_index := args.find("--replay-file")
	if replay_index >= 0 and replay_index + 1 < args.size():
		var error: Error = load_replay_file(args[replay_index+1])
		if error != OK:
			message = "Replay load failed: " + error_string(error)
	_log("startup",{"engine":Engine.get_version_info().string,"physics_hz":Engine.physics_ticks_per_second,"renderer":RenderingServer.get_current_rendering_method(),"demo":demo,"camera":"stabilized","scope":"contact and replay; no damage or multiplayer"})
	if "--capture-calibration" in OS.get_cmdline_user_args():
		_begin_arm_calibration()
		adapter.camera.rotation.x = -.65
	print("MELEE_LAB_READY xr=%s; Esc resume, R calibrate; T replay; M scenario; F fixed/free" % adapter.xr_active)

func _setup_melee_lighting() -> void:
	# A suit-mounted raking light gives the close fight a directional highlight.
	# It follows returned/recorded suit poses, never the predicted control frame.
	var lamp := SpotLight3D.new()
	lamp.name = "MeleeShoulderHeadlight"
	view.suits[0].add_child(lamp)
	lamp.position = Vector3(4,9,-2)
	lamp.basis = Basis.looking_at(Vector3(-4,-6,-14),Vector3.UP)
	lamp.light_color = Color("e0edff")
	lamp.light_energy = 5.0
	lamp.spot_range = 48.0
	lamp.spot_angle = 48.0
	lamp.spot_attenuation = .65
	lamp.shadow_enabled = true
	lamp.shadow_bias = .04

func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .65
	if color.a < 1:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.material_override = material
	parent.add_child(node)
	node.position = at
	return node

func _label(parent: Node3D, text: String, at: Vector3, size := .0008) -> Label3D:
	var node := Label3D.new()
	node.text = text
	node.font_size = 32
	node.pixel_size = size
	node.position = at
	node.modulate = Color("b6e8ed")
	parent.add_child(node)
	return node

func _build_cockpit() -> void:
	_box(cockpit,Vector3(.52,.12,.5),Vector3(0,-.65,.08),Color("3c5262"))
	_box(cockpit,Vector3(.52,.7,.09),Vector3(0,-.3,.34),Color("3c5262"))
	for side in [-1,1]:
		_box(cockpit,Vector3(.04,.04,1.3),Vector3(side*.68,-.45,-.4),Color("647b8c"))
		_box(cockpit,Vector3(.035,1.1,.035),Vector3(side*.68,.1,-1.15),Color("647b8c"))
	_box(cockpit,Vector3(1.4,.04,.04),Vector3(0,.64,-1.15),Color("647b8c"))
	for i in 2:
		handle_meshes.append(_box(cockpit,Vector3(.055,.10,.07),handles.handles[i].origin,Color("64e4f0") if i==0 else Color("ffc777")))
		hand_meshes.append(_box(cockpit,Vector3(.035,.035,.09),Vector3.ZERO,Color(.6,.95,1,.35)))
		pointers.append(_box(cockpit,Vector3(.003,.003,.9),Vector3.ZERO,Color("6dffd9")))
	status = _label(cockpit,"",Vector3(0,.49,-1.65),.001)

func _build_panel() -> void:
	cockpit.add_child(panel)
	panel.position = Vector3(-.30,-.77,-1.02)
	panel.rotation_degrees.x = -45
	panel.scale = Vector3.ONE*.8
	_box(panel,Vector3(PANEL_WIDTH+.025,ROW_HEIGHT*9+.025,.018),Vector3(0,0,.013),Color("081d2b"))
	for i in 9:
		rows.append(_label(panel,"",Vector3(0,(4-i)*ROW_HEIGHT,.028),.001))
	for i in TUNING.size():
		var y := (3-i)*ROW_HEIGHT-.022
		slider_tracks.append(_box(panel,Vector3(PANEL_WIDTH*.80,.005,.004),Vector3(0,y,.030),Color("567e89")))
		slider_knobs.append(_box(panel,Vector3(.014,.022,.006),Vector3(0,y,.034),Color("71ffd5")))
	add_child(note_layer)
	note_layer.layer = 20
	note_layer.add_child(note_edit)
	note_edit.position = Vector2(28,28)
	note_edit.size = Vector2(740,48)
	note_edit.placeholder_text = "Replay note at cursor time — Enter saves, Escape cancels"
	note_edit.max_length = 300
	note_edit.visible = false
	note_edit.text_submitted.connect(func(text: String):
		recorder.add_annotation(text)
		message = "Note added at %.2fs" % recorder.cursor
		note_edit.hide()
		note_edit.release_focus()
	)

func _build_audio() -> void:
	add_child(contact_audio)
	contact_audio.stream = _tone(false)
	contact_audio.volume_db = -12
	contact_audio.unit_size = 15
	contact_audio.max_distance = 100
	add_child(load_audio)
	load_audio.stream = _tone(true)
	load_audio.volume_db = -50
	if DisplayServer.get_name()!="headless": load_audio.play()

func _tone(looped: bool) -> AudioStreamWAV:
	var rate := 22050
	var count := 2205 if looped else 3307
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	for i in count:
		var t := float(i)/rate
		var envelope := 1.0 if looped else exp(-t*32.0)
		var value := (sin(TAU*180*t)*.5+sin(TAU*540*t)*.25) if looped else (sin(TAU*840*t)*.5+sin(TAU*1270*t)*.3)
		bytes.encode_s16(i*2,int(value*envelope*18000))
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = rate
	audio.data = bytes
	if looped:
		audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
		audio.loop_begin = 0
		audio.loop_end = count
	return audio

func _physics_process(dt: float) -> void:
	var sample: Dictionary = adapter.sample()
	if demo and not recorder.replaying:
		demo_time += dt
		sample = _demo_sample(demo_time,sample)
	if not sample.focused and not paused:
		paused = true
		message = "Session focus lost — resume explicitly after returning."
		_flush_delay()
		_log("focus_pause",{})
	if recorder.replaying:
		physics.set_paused(true)
		if sample.focused and not note_edit.visible:
			recorder.advance(dt)
		var replay_snapshot: Dictionary = recorder.sample()
		if not replay_snapshot.is_empty():
			view.apply_visuals(replay_snapshot.get("visuals",[]))
			view.apply_appearance(replay_snapshot.get("appearance",{}))
			var saved_error: Dictionary = replay_snapshot.get("cockpit_error",{})
			cockpit_feedback.visible = saved_error.has("actual") and saved_error.has("desired")
			if cockpit_feedback.visible: cockpit_feedback.show_poses(saved_error.actual,saved_error.desired)
			if not free_replay:
				cockpit.global_transform = replay_snapshot.get("cockpit",live_cockpit)
			else:
				_fly_replay(sample,dt)
			_show_contacts(replay_snapshot,false,dt)
		_panel_input(sample)
		_update_display()
		return
	physics.set_paused(paused)
	var committed: Dictionary = physics.snapshot()
	if not paused:
		delay.advance(dt)
		delay.send_snapshot(committed)
	var snapshot: Dictionary = delay.receive_snapshot()
	if snapshot.is_empty(): snapshot = committed
	last_snapshot = snapshot
	var player: Dictionary = snapshot.rigs[0]
	var actual_body: Transform3D = player.body
	cockpit.global_basis = actual_body.basis if physical_camera else player.get("commanded_basis",actual_body.basis)
	cockpit.global_position = actual_body.origin + cockpit.global_basis*COCKPIT_OFFSET
	# The legacy input model still manages action/flight ownership. Its arm
	# feedback is diagnostic only: arm_mapping exclusively owns actuator targets.
	for i in 2:
		model.arm_actual[i] = cockpit.global_transform.affine_inverse()*player.grips[i]
	sample.paused = paused
	handles.enabled = grip_controls
	pilot_status = pilot.step(sample,handles.pilot_reservations(sample))
	var adapted: Dictionary = handles.step(pilot_status.sample,model,dt)
	adapted["thumbstick_basis"] = sample.head.basis.orthonormalized()
	if arm_mapping.calibration_mode:
		adapted.move = Vector3.ZERO
		adapted.yaw = 0.0
		adapted.vertical = 0.0
		adapted.pilot_move = Vector3.ZERO
		adapted.pilot_rotation = Vector3.ZERO
		adapted.main_throttle = 0.0
		adapted.left_trigger = 0.0
		adapted.right_trigger = 0.0
		adapted.brake = true
	var motor_result: Dictionary = model.step(adapted,dt)
	var mapped_targets: Array[Transform3D] = arm_mapping.step(sample,handles.grabbed)
	handles.handles.assign(arm_mapping.handle_poses)
	var commands: Array[Transform3D] = []
	for i in 2:
		commands.append(Transform3D(Basis.IDENTITY,COCKPIT_OFFSET)*mapped_targets[i])
	if not paused:
		delay.send_input({"grips":commands,"velocity":actual_body.basis.inverse()*model.velocity,
			"angular_velocity":actual_body.basis.inverse()*model.body_basis*Vector3(model.pitch_rate,model.yaw_rate,model.roll_rate),
			"desired_basis":model.body_basis,"boost":motor_result.boost_active})
		physics.apply_command(delay.receive_input())
		sim_time += dt
	var displayed_time := float(snapshot.get("time",0.0))
	view.update_snapshot(snapshot,maxf(0,displayed_time-appearance_time) if not paused else 0.0)
	appearance_time = displayed_time

	for i in 2:
		handle_meshes[i].transform = handles.handles[i]
		hand_meshes[i].transform = sample.left if i==0 else sample.right
		hand_meshes[i].visible = sample.focused and sample.get("valid_left" if i==0 else "valid_right",false)
		var material := handle_meshes[i].material_override as StandardMaterial3D
		material.albedo_color = Color("79ffbd") if handles.grabbed[i] else (Color("64e4f0") if i==0 else Color("ffc777"))
		markers[i].global_position = player.commands[i].origin
		markers[i].visible = not paused and markers[i].global_position.distance_to(player.grips[i].origin)>.25
	var actual_cockpit: Array = []
	var desired_cockpit: Array = []
	for i in 2:
		var actual_ref: Transform3D = Transform3D(Basis.IDENTITY,-COCKPIT_OFFSET)*actual_body.affine_inverse()*player.grips[i]
		actual_cockpit.append(arm_mapping.inverse_map(i,actual_ref))
		desired_cockpit.append(arm_mapping.inverse_map(i,arm_mapping.targets[i]))
	cockpit_feedback.visible = true
	cockpit_feedback.show_poses(actual_cockpit,desired_cockpit)
	snapshot["cockpit_error"] = {"actual":actual_cockpit,"desired":desired_cockpit}
	_show_contacts(snapshot,not paused,dt)
	if not paused:
		snapshot["visuals"] = view.capture_visuals()
		snapshot["appearance"] = view.capture_appearance()
		snapshot["cockpit"] = cockpit.global_transform
		snapshot["sim_time"] = sim_time
		snapshot["mode"] = MODE_NAMES[mode]
		snapshot["fixed"] = fixed_opponent
		snapshot["bracing"] = _bracing_label()
		snapshot["events"] = snapshot.get("contacts",[]).duplicate(true)
		snapshot["events"].append_array(snapshot.get("beam_contacts",[]).duplicate(true))
		snapshot["rtt_ms"] = rtt_ms
		snapshot["cockpit_controls"] = {"boost_reserve":model.boost,"throttle":pilot.throttle}
		snapshot["delivered_input_sequence"] = delay.input_sequence
		snapshot["delivered_snapshot_sequence"] = delay.snapshot_sequence
		recorder.record(dt,snapshot)
	_panel_input(sample)
	_update_display()

func _show_contacts(snapshot: Dictionary, audible: bool, dt: float) -> void:
	contact_cooldown = maxf(0,contact_cooldown-dt)
	plate_visual.visible = snapshot.get("fixture_enabled",false)
	for i in 2:
		var thrust: Vector3 = snapshot.rigs[i].get("thrust",Vector3.ZERO)
		var body_pose: Transform3D = snapshot.rigs[i].body
		var active: bool = thrust.length()>500 and (i==0 or (not snapshot.get("opponent_fixed",true) and snapshot.get("opponent_visible",true)))
		thrust_visuals[i].visible = active
		if active:
			var length := clampf(thrust.length()/20000.0,.2,4.0)
			var direction := -thrust.normalized()
			thrust_visuals[i].global_transform = Transform3D(Basis.looking_at(direction,Vector3.RIGHT if absf(direction.dot(Vector3.UP))>.95 else Vector3.UP),body_pose.origin+body_pose.basis*Vector3(0,0,2)+direction*length*.5)
			thrust_visuals[i].scale = Vector3(.15,.15,length)
	var contacts: Array = snapshot.get("contacts",[])
	contact_marker.visible = not contacts.is_empty()
	if not contacts.is_empty():
		contact_marker.global_position = contacts[0].get("position",Vector3.ZERO)
		if audible and contact_cooldown<=0:
			contact_count += 1
			contact_audio.global_position = contact_marker.global_position
			if DisplayServer.get_name()!="headless": contact_audio.play()
			contact_cooldown = .22
			if adapter.xr_active:
				var active_hands := [false,false]
				for contact in contacts:
					if contact.get("rig",-1)==0: active_hands[int(contact.hand)] = true
				for i in 2:
					var controller: XRController3D = adapter.controllers[i]
					if active_hands[i] and controller.get_has_tracking_data(): controller.trigger_haptic_pulse("haptic",100,.25,.06,0)
			_log("contact",{"position":str(contact_marker.global_position),"count":contacts.size()})
	var load := 0.0
	if audible and snapshot.has("rigs"):
		for item in snapshot.rigs[0].get("loads",[]):
			load = maxf(load,float(item.get("effort",0.0)))
	load_audio.volume_db = lerpf(-55,-24,clampf(load,0,1))
	load_audio.pitch_scale = lerpf(.75,1.3,clampf(load,0,1))

func panel_point(pose: Transform3D) -> Vector3:
	var local := panel.transform.affine_inverse()*pose
	var direction := -local.basis.z
	if direction.z>=-.001: return Vector3(INF,INF,INF)
	var distance := -local.origin.z/direction.z
	if distance<0 or distance>5: return Vector3(INF,INF,INF)
	return local.origin+direction*distance

func panel_hit(pose: Transform3D) -> int:
	var hit := panel_point(pose)
	if not hit.is_finite() or absf(hit.x)>PANEL_WIDTH*.5 or absf(hit.y)>ROW_HEIGHT*4.5: return -1
	return clampi(int(floor(4.5-hit.y/ROW_HEIGHT)),0,8)

func _panel_input(sample: Dictionary) -> void:
	hovered = -1
	var consumed := false
	for i in 2:
		var valid: bool = sample.focused and sample.get("valid_left" if i==0 else "valid_right",false)
		var active: bool = valid and pilot_status.owners[i]=="" and (paused or recorder.replaying or not handles.grabbed[i])
		var pose: Transform3D = sample.left if i==0 else sample.right
		pointers[i].visible = active
		pointers[i].transform = pose*Transform3D(Basis.IDENTITY,Vector3(0,0,-.45))
		var down: bool = sample.get("left_trigger" if i==0 else "right_trigger",0.0)>.55
		var fresh: bool = down and not trigger_down[i] and pointer_active[i]
		trigger_down[i] = down or not valid
		pointer_active[i] = active
		if not active or not down or recorder.replaying or not tuning_page or arm_mapping.calibration_mode: slider_capture[i] = -1
		var row := panel_hit(pose) if active else -1
		if row>=0: hovered = row
		if tuning_page and not recorder.replaying and not arm_mapping.calibration_mode:
			if fresh and row>=1 and row<=7 and slider_capture[1-i]<0:
				slider_capture[i] = row-1
			if slider_capture[i]>=0:
				var point := panel_point(pose)
				if point.is_finite(): set_tuning_fraction(slider_capture[i],point.x/(PANEL_WIDTH*.8)+.5)
				consumed = true
		if row>=0 and fresh and not consumed:
			consumed = true
			_action(row)

func _neutral_command() -> Dictionary:
	var grips: Array[Transform3D] = []
	for target in physics.capture_command().get("grips",[]): grips.append(target)
	return {"grips":grips,"velocity":Vector3.ZERO,"angular_velocity":Vector3.ZERO,
		"desired_basis":physics.desired_basis,"boost":false}

func _flush_delay() -> void:
	delay.flush(_neutral_command(),last_snapshot)
	slider_capture = [-1,-1]

func _set_rtt(value: float) -> void:
	rtt_ms = clampf(value,0,400)
	delay.configure(rtt_ms,_neutral_command(),last_snapshot)
	message = "RTT %.0fms: half each way; queued commands cleared." % rtt_ms
	_log("rtt",{"milliseconds":rtt_ms})

func tuning_value(index: int) -> float:
	return rtt_ms if index==6 else float(physics.get(TUNING[index][1]))

func set_tuning_fraction(index: int, fraction: float) -> void:
	if index<0 or index>=TUNING.size(): return
	var value := lerpf(TUNING[index][2],TUNING[index][3],clampf(fraction,0,1))
	if index==6:
		value = roundf(value/10.0)*10.0
		if value!=rtt_ms: _set_rtt(value)
	else:
		physics.set(TUNING[index][1],value)
		if index in [3,4]:
			physics.thrusters_enabled = true
			bracing = 0
	_update_display()

func _bracing_label() -> String:
	if not physics.thrusters_enabled: return "COAST"
	if is_equal_approx(physics.thrust_limit,15000) and is_equal_approx(physics.attitude_limit,30000): return "SOFT"
	if is_equal_approx(physics.thrust_limit,90000) and is_equal_approx(physics.attitude_limit,150000): return "NORMAL"
	return "CUSTOM"

func _cycle_bracing() -> void:
	bracing = (bracing+1)%3
	physics.thrusters_enabled = bracing!=2
	physics.thrust_limit = 15000.0 if bracing==1 else 90000.0
	physics.attitude_limit = 30000.0 if bracing==1 else 150000.0
	_update_display()

func _action(row: int) -> void:
	if arm_mapping.calibration_mode and not recorder.replaying:
		match row:
			0: _finish_arm_calibration()
			1:
				var previous: Dictionary = arm_mapping._before_calibration.duplicate(true)
				arm_mapping.reset_calibration()
				arm_mapping.begin_calibration()
				arm_mapping._before_calibration = previous
				_release_arm_controls()
				message = "Default offsets. Finish saves; Cancel restores previous mapping."
			8:
				arm_mapping.cancel_calibration()
				_release_arm_controls()
				message = "Calibration cancelled."
		_update_display()
		return
	if tuning_page and not recorder.replaying:
		if row==0: tuning_page = false
		elif row==8: _cycle_bracing()
		_update_display()
		return
	if recorder.replaying:
		match row:
			0: _leave_replay()
			1: recorder.toggle_playing()
			2: recorder.scrub(recorder.cursor-1.0)
			3: recorder.scrub(recorder.cursor+1.0)
			4: _toggle_view()
			5: _mark()
			6: _save_replay()
			7: _annotate()
			8: recorder.scrub(0.0)
	else:
		match row:
			0: _toggle_pause()
			1: _reset()
			2:
				mode = (mode+1)%3
				_change_scenario()
			3:
				fixed_opponent = not fixed_opponent
				_change_scenario()
			4: _begin_replay()
			5:
				physical_camera = not physical_camera
				paused = true
				message = "Camera comparison changed; resume explicitly."
			6: _save_replay()
			7: _begin_arm_calibration()
			8: tuning_page = true
	trigger_down = [true,true]
	pointer_active = [false,false]
	_update_display()

func _update_display() -> void:
	var texts: Array[String]
	if recorder.replaying:
		texts = ["RETURN TO LIVE (paused) [T]","%s  %.1f / %.1fs [P]" % ["PAUSE REPLAY" if recorder.playing else "PLAY REPLAY",recorder.cursor,recorder.duration()],"BACK 1 SECOND  [ [ ]","FORWARD 1 SECOND  [ ] ]","VIEW: %s [V]" % ("FREE FLIGHT" if free_replay else "RECORDED COCKPIT"),"MARK THIS MOMENT [F8]","EXPORT REPLAY + NOTES [F5]","ADD TEXT NOTE [N / desktop]","JUMP TO START"]
	else:
		texts = ["%s [Esc / stick click]" % ("RESUME" if paused else "PAUSE"),"RESET + CALIBRATE [R]","OPPONENT: %s [M]" % MODE_NAMES[mode],"BASE: %s [F]" % ("FIXED" if fixed_opponent else "FREE"),"REPLAY LAST 20 SECONDS [T]","COCKPIT: %s [C]" % ("PHYSICAL" if physical_camera else "STABILIZED"),"EXPORT CLIP + NOTES [F5]","ARM CALIBRATION [F3]","TUNE FORCE / SPEED / LAG [F2]"]
	if tuning_page and not recorder.replaying:
		texts = ["BACK TO CONTROLS [F2]"]
		for i in TUNING.size():
			var value := tuning_value(i)
			if TUNING[i][4] in ["kN","kNm"]: value /= 1000.0
			texts.append("%s  %.1f %s" % [TUNING[i][0],value,TUNING[i][4]])
		texts.append("BRACING: %s [K]" % _bracing_label())
	if arm_mapping.calibration_mode and not recorder.replaying:
		texts = ["FINISH + SAVE OFFSETS [F3]","RESET OFFSETS TO DEFAULT","GRIP: POSITION ROBOT ARM","HOLD TRIGGER: HOLD ARM TARGET","MOVE HANDLE TO COMFORTABLE SPOT","RELEASE TRIGGER: KEEP OFFSET","LEFT: %s" % ("REPOSITIONING" if arm_mapping.adjusting[0] else "ARM CONTROL"),"RIGHT: %s" % ("REPOSITIONING" if arm_mapping.adjusting[1] else "ARM CONTROL"),"CANCEL / RESTORE OFFSETS"]
	for i in slider_tracks.size():
		slider_tracks[i].visible = tuning_page and not recorder.replaying and not arm_mapping.calibration_mode
		slider_knobs[i].visible = slider_tracks[i].visible
		if slider_tracks[i].visible:
			slider_knobs[i].position.x = (inverse_lerp(TUNING[i][2],TUNING[i][3],tuning_value(i))-.5)*PANEL_WIDTH*.8
	for i in rows.size():
		rows[i].text = texts[i]
		rows[i].modulate = Color("76ffd4") if hovered==i else Color("b6e8ed")
	var speed := 0.0
	var telemetry: Dictionary = recorder.sample() if recorder.replaying else last_snapshot
	var load_text := ""
	if not telemetry.is_empty():
		speed = telemetry.rigs[0].get("velocity",Vector3.ZERO).length()
		var loads: Array = telemetry.rigs[0].get("loads",[{},{}])
		load_text = "LOAD L %3.0f%% / R %3.0f%%" % [float(loads[0].get("effort",0))*100,float(loads[1].get("effort",0))*100]
	var shown_controls: Dictionary = telemetry.get("cockpit_controls",{"boost_reserve":model.boost,"throttle":pilot.throttle})
	status.text = "MELEE LAB / %s\n%s\nL %s   R %s  /  %.1f m/s\n%s\n%s" % ["REPLAY — LIVE FROZEN" if recorder.replaying else ("PAUSED" if paused else MODE_NAMES[mode]),"Beam clash resists / armor contact heats","HELD" if handles.grabbed[0] else "PARKED","HELD" if handles.grabbed[1] else "PARKED",speed,load_text,"BOOST %d%% / MAIN %d%% / RTT %dms\n%s" % [shown_controls.get("boost_reserve",1.0)*100,shown_controls.get("throttle",0.0)*100,telemetry.get("rtt_ms",rtt_ms),message]]

func _release_arm_controls() -> void:
	handles.reset()
	handles.handles.assign(arm_mapping.handle_poses)
	pilot.reset()
	pilot_status = {"owners":["",""]}
	model._trigger_ready.assign([false,false])
	model._trigger_down.assign([true,true])
	_flush_delay()

func _begin_arm_calibration() -> void:
	arm_mapping.begin_calibration()
	tuning_page = false
	_release_arm_controls()
	message = "Resume if paused. Grip moves arm; hold trigger to reposition handle."
	_update_display()

func _finish_arm_calibration() -> void:
	var error: Error = arm_mapping.finish_calibration(calibration_path)
	if error==OK:
		_release_arm_controls()
		message = "Arm offsets saved. Release controls, then regrab."
	else: message = "Could not save calibration: " + error_string(error)
	_update_display()

func _toggle_pause() -> void:
	if note_edit.visible:
		note_edit.hide()
		note_edit.release_focus()
		return
	if recorder.replaying:
		recorder.toggle_playing()
		return
	paused = not paused
	physics.set_paused(paused)
	_flush_delay()
	trigger_down = [true,true]
	message = "Release grips, then grab the nearby handles." if not paused else "Paused. Aim either hand at a row and use a fresh trigger."
	_log("pause",{"paused":paused})

func _reset() -> void:
	if arm_mapping.calibration_mode: arm_mapping.cancel_calibration()
	arm_mapping.reset_targets()
	if recorder.replaying: _leave_replay()
	paused = true
	physics.set_paused(true)
	physics.reset()
	view.reset_appearance()
	last_snapshot = physics.snapshot()
	delay.reset(_neutral_command(),last_snapshot)
	appearance_time = 0.0
	model.reset()
	handles.reset()
	handles.handles.assign(arm_mapping.handle_poses)
	pilot.reset()
	pilot_status = {"owners":["",""]}
	adapter.recenter()
	cockpit.transform = Transform3D.IDENTITY
	recorder = Replay.new()
	sim_time = 0
	contact_count = 0
	contact_cooldown = 0
	message = "Reset. Resume, release grips, then acquire handles."
	trigger_down = [true,true]
	pointer_active = [false,false]
	_log("reset",{})

func _change_scenario() -> void:
	physics.set_opponent_mode("cut" if mode==1 else "guard")
	physics.set_opponent_fixed(fixed_opponent)
	physics.set_fixture_enabled(mode==2)
	_reset()
	message = "%s / %s. Reset and paused for a repeatable comparison." % [MODE_NAMES[mode],"fixed" if fixed_opponent else "free"]

func _begin_replay() -> void:
	if arm_mapping.calibration_mode:
		arm_mapping.cancel_calibration()
		_release_arm_controls()
	if not recorder.begin_replay():
		message = "No clip yet — resume and make an exchange first."
		return
	live_cockpit = cockpit.global_transform
	_enter_replay_view()

func _enter_replay_view() -> void:
	paused = true
	physics.set_paused(true)
	free_replay = false
	slider_capture = [-1,-1]
	pilot.reset()
	pilot_status = {"owners":["",""]}
	_flush_delay()
	for marker in markers: marker.visible = false
	message = "Replay: pause, scrub or switch to free flight. Live bodies are frozen."
	trigger_down = [true,true]
	load_audio.volume_db = -55
	_log("replay_begin",{"duration":recorder.duration()})

func _leave_replay() -> void:
	recorder.end_replay()
	cockpit.global_transform = live_cockpit
	view.update_snapshot(last_snapshot,0.0)
	paused = true
	_flush_delay()
	handles.reset()
	handles.handles.assign(arm_mapping.handle_poses)
	pilot.reset()
	pilot_status = {"owners":["",""]}
	message = "Returned to live, paused. Resume and regrab handles."
	trigger_down = [true,true]
	_log("replay_end",{})

func _toggle_view() -> void:
	free_replay = not free_replay
	if free_replay:
		var state: Dictionary = recorder.sample()
		var frame: Transform3D = state.get("cockpit",Transform3D.IDENTITY)
		cockpit.global_transform = Transform3D(frame.basis,frame.origin+frame.basis*Vector3(13,7,14))
		cockpit.look_at(frame.origin+frame.basis*Vector3(2,-2,-7),Vector3.UP)
	message = "Fly: sticks / WASD, right Y / Q E height, right X / arrows yaw. Head look remains live."

func _fly_replay(sample: Dictionary,dt: float) -> void:
	if not sample.focused or note_edit.visible: return
	var move: Vector3 = sample.move
	move.y += float(sample.vertical)
	cockpit.global_position += cockpit.global_basis*move.limit_length(1.0)*dt*12.0
	cockpit.rotate_y(float(sample.yaw)*dt*.6)

func _mark() -> void:
	if note_edit.visible: return
	if not recorder.replaying: _begin_replay()
	if not recorder.replaying: return
	recorder.add_annotation("Marked exchange")
	message = "Moment marked. Export preserves the clip and notes."
	_log("mark",{"replay":recorder.replaying,"cursor":recorder.cursor})

func _annotate() -> void:
	if not recorder.replaying: return
	recorder.playing = false
	if adapter.xr_active:
		_mark()
		message = "Moment marked; add detailed text when reviewing on desktop."
	else:
		note_edit.text = ""
		note_edit.show()
		note_edit.grab_focus()

func _save_replay() -> void:
	if not recorder.replaying: _begin_replay()
	if not recorder.replaying: return
	var path := "res://artifacts/melee-%s.json" % Time.get_datetime_string_from_system().replace(":","-")
	var error: Error = recorder.save_file(path,{"engine":Engine.get_version_info().string,"scenario":MODE_NAMES[mode],"physics_hz":Engine.physics_ticks_per_second,"note":"Resolved visual and body states; no audio or microphone recording."})
	message = "Saved " + path.get_file() if error==OK else "Export failed: " + error_string(error)
	_log("export",{"path":path,"error":error})

func load_replay_file(path: String) -> Error:
	var candidate = Replay.new()
	var error: Error = candidate.load_file(path)
	if error != OK: return error
	# The reusable codec permits arbitrary dictionaries; this viewer needs its
	# own semantic validation before indexing rigs or restoring mesh transforms.
	var expected_visuals: int = view.capture_visuals().size()
	for frame in candidate._clip:
		var state: Dictionary = frame.state
		if state.has("appearance") and (not state.appearance is Dictionary or not view.valid_appearance(state.appearance)): return ERR_INVALID_DATA
		if state.has("cockpit_error"):
			if not state.cockpit_error is Dictionary: return ERR_INVALID_DATA
			for field in ["actual","desired"]:
				var poses = state.cockpit_error.get(field)
				if not poses is Array or poses.size()!=2: return ERR_INVALID_DATA
				for pose in poses:
					if not pose is Transform3D or not pose.is_finite() or absf(pose.basis.determinant())<.00001: return ERR_INVALID_DATA
		if not state.get("cockpit") is Transform3D or not state.get("visuals") is Array or not state.get("rigs") is Array or state.rigs.size()!=2 or state.visuals.size()!=expected_visuals: return ERR_INVALID_DATA
		for pose in state.visuals:
			if not pose is Transform3D: return ERR_INVALID_DATA
		for rig in state.rigs:
			if not rig is Dictionary or not rig.get("body") is Transform3D or not rig.get("velocity") is Vector3 or not rig.get("thrust") is Vector3 or not rig.get("loads") is Array or rig.loads.size()!=2: return ERR_INVALID_DATA
			for load in rig.loads:
				if not load is Dictionary or not (load.get("effort") is float or load.get("effort") is int): return ERR_INVALID_DATA
		if not state.get("contacts",[]) is Array: return ERR_INVALID_DATA
		for contact in state.get("contacts",[]):
			if not contact is Dictionary or not contact.get("position") is Vector3: return ERR_INVALID_DATA
	recorder = candidate
	live_cockpit = cockpit.global_transform
	_enter_replay_view()
	return OK

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if note_edit.visible:
		if event.physical_keycode==KEY_ESCAPE:
			note_edit.hide()
			note_edit.release_focus()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode in [KEY_F6,KEY_F7,KEY_F8]:
			get_viewport().set_input_as_handled()
		return
	var handled := true
	match event.physical_keycode:
		KEY_T:
			if recorder.replaying: _leave_replay()
			else: _begin_replay()
		KEY_M: if not recorder.replaying: _action(2)
		KEY_F: if not recorder.replaying: _action(3)
		KEY_C: if not recorder.replaying: _action(5)
		KEY_K: if not recorder.replaying: _cycle_bracing()
		KEY_F2:
			if not recorder.replaying and not arm_mapping.calibration_mode:
				tuning_page = not tuning_page
				slider_capture = [-1,-1]
				_update_display()
		KEY_F3:
			if not recorder.replaying:
				if arm_mapping.calibration_mode: _finish_arm_calibration()
				else: _begin_arm_calibration()
		KEY_F5: _save_replay()
		KEY_P: if recorder.replaying: recorder.toggle_playing()
		KEY_BRACKETLEFT: if recorder.replaying: recorder.scrub(recorder.cursor-1.0)
		KEY_BRACKETRIGHT: if recorder.replaying: recorder.scrub(recorder.cursor+1.0)
		KEY_V: if recorder.replaying: _toggle_view()
		KEY_N: _annotate()
		_: handled = false
	if handled: get_viewport().set_input_as_handled()

func _demo_sample(t: float, initial: Dictionary) -> Dictionary:
	var sample := initial.duplicate()
	sample.focused = true
	sample.valid_left = true
	sample.valid_right = true
	sample.left = Transform3D(Basis.IDENTITY,Vector3(-.28,-.30,-.42))
	sample.right = Transform3D(Basis.IDENTITY,Vector3(.28,-.30,-.42))
	sample.left_grip = 1.0 if t>.5 else 0.0
	sample.right_grip = 1.0 if t>.5 else 0.0
	sample.move = Vector3.ZERO
	sample.yaw = 0.0
	sample.vertical = 0.0
	sample.left_trigger = 0.0
	sample.right_trigger = 0.0
	if t>1:
		sample.right.origin.z -= minf((t-1)*.16,.55)
		sample.right.origin.x += sin((t-1)*1.4)*.12
		sample.right.basis = Basis(Vector3.FORWARD,sin((t-1)*.8)*.3)
	return sample

func _process(dt: float) -> void:
	frames += 1
	max_frame_ms = maxf(max_frame_ms,dt*1000)
	frame_total += dt
	if "--capture" in OS.get_cmdline_user_args() and frames==360 and DisplayServer.get_name()!="headless":
		get_viewport().get_texture().get_image().save_png("res://artifacts/melee-calibration.png" if "--capture-calibration" in OS.get_cmdline_user_args() else ("res://artifacts/melee-tuning.png" if "--capture-tuning" in OS.get_cmdline_user_args() else "res://artifacts/melee-cockpit.png"))
	if "--capture" in OS.get_cmdline_user_args() and frames==400:
		_begin_replay()
		if recorder.replaying:
			recorder.playing = false
			_toggle_view()
	if "--capture" in OS.get_cmdline_user_args() and frames==440 and DisplayServer.get_name()!="headless":
		get_viewport().get_texture().get_image().save_png("res://artifacts/melee-replay.png")

func _log(event: String, data: Dictionary) -> void:
	if trace:
		trace.store_line(JSON.stringify({"event":event,"time":sim_time,"data":data}))
		trace.flush()

func _exit_tree() -> void:
	contact_audio.stop()
	load_audio.stop()
	contact_audio.stream = null
	load_audio.stream = null
	_log("summary",{"frames":frames,"mean_ms":frame_total/maxi(frames,1)*1000,"max_ms":max_frame_ms,"contact_feedback_events":contact_count,"note":"Application frame timing; not compositor timing or subjective headset evidence."})
