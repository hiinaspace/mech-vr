extends Node3D
## Seated contact laboratory. Tracking, actuator commands and solved poses stay
## separate; replay restores visual samples while the live simulation is frozen.
const ControlModel = preload("res://scripts/control_model.gd")
const Adapter = preload("res://scripts/input_adapter.gd")
const Physics = preload("res://scripts/melee_physics.gd")
const Replay = preload("res://scripts/melee_replay.gd")
const View = preload("res://scripts/melee_view.gd")
const ROW_HEIGHT := .068
const PANEL_WIDTH := .64
const COCKPIT_OFFSET := Vector3(0,4.9,-1)
const MODE_NAMES := ["GUARD", "REPEATED CUT", "SLAB"]
var physics = Physics.new()
var recorder = Replay.new()
var view = View.new()
var model = ControlModel.new()
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
	_build_cockpit()
	view.setup_puppet(cockpit)
	_build_panel()
	_build_audio()
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
	view.update_snapshot(physics.snapshot(),0.0)
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
	print("MELEE_LAB_READY xr=%s; Esc resume, R calibrate; T replay; M scenario; F fixed/free" % adapter.xr_active)

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
	panel.position = Vector3(-.30,-.52,-1.22)
	panel.rotation_degrees.x = -18
	_box(panel,Vector3(PANEL_WIDTH+.025,ROW_HEIGHT*9+.025,.018),Vector3(0,0,.013),Color("081d2b"))
	for i in 9:
		rows.append(_label(panel,"",Vector3(0,(4-i)*ROW_HEIGHT,.028),.001))
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
		_log("focus_pause",{})
	if recorder.replaying:
		physics.set_paused(true)
		if sample.focused and not note_edit.visible:
			recorder.advance(dt)
		var replay_snapshot: Dictionary = recorder.sample()
		if not replay_snapshot.is_empty():
			view.apply_visuals(replay_snapshot.get("visuals",[]))
			if not free_replay:
				cockpit.global_transform = replay_snapshot.get("cockpit",live_cockpit)
			else:
				_fly_replay(sample,dt)
			_show_contacts(replay_snapshot,false,dt)
		_panel_input(sample)
		_update_display()
		return
	physics.set_paused(paused)
	var snapshot: Dictionary = physics.snapshot()
	last_snapshot = snapshot
	var player: Dictionary = snapshot.rigs[0]
	var actual_body: Transform3D = player.body
	cockpit.global_basis = actual_body.basis if physical_camera else model.body_basis
	cockpit.global_position = actual_body.origin + cockpit.global_basis*COCKPIT_OFFSET
	# Feed the latest solved endpoints back before ownership transitions. Parking
	# captures ACTUAL poses; it cannot store a spring command behind an obstacle.
	for i in 2:
		model.arm_actual[i] = cockpit.global_transform.affine_inverse()*player.grips[i]
	sample.paused = paused
	handles.enabled = grip_controls
	var adapted: Dictionary = handles.step(sample,model,dt)
	model.step(adapted,dt)
	var commands: Array[Transform3D] = []
	for i in 2:
		commands.append(actual_body.affine_inverse()*cockpit.global_transform*model.arm_targets[i])
	physics.command_player(commands,actual_body.basis.inverse()*model.velocity,actual_body.basis.inverse()*model.body_basis*Vector3(model.pitch_rate,model.yaw_rate,model.roll_rate))
	physics.desired_basis = model.body_basis
	if not paused: sim_time += dt
	view.update_snapshot(snapshot,dt if not paused else 0.0)
	for i in 2:
		handle_meshes[i].transform = handles.handles[i]
		hand_meshes[i].transform = sample.left if i==0 else sample.right
		hand_meshes[i].visible = sample.focused and sample.get("valid_left" if i==0 else "valid_right",false)
		var material := handle_meshes[i].material_override as StandardMaterial3D
		material.albedo_color = Color("79ffbd") if handles.grabbed[i] else (Color("64e4f0") if i==0 else Color("ffc777"))
		markers[i].global_position = (cockpit.global_transform*model.arm_targets[i]).origin
		markers[i].visible = not paused and markers[i].global_position.distance_to(player.grips[i].origin)>.25
	_show_contacts(snapshot,not paused,dt)
	if not paused:
		snapshot["visuals"] = view.capture_visuals()
		snapshot["cockpit"] = cockpit.global_transform
		snapshot["sim_time"] = sim_time
		snapshot["mode"] = MODE_NAMES[mode]
		snapshot["fixed"] = fixed_opponent
		snapshot["bracing"] = ["NORMAL","SOFT","COAST"][bracing]
		snapshot["events"] = snapshot.get("contacts",[]).duplicate(true)
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

func panel_hit(pose: Transform3D) -> int:
	var local := panel.transform.affine_inverse()*pose
	var direction := -local.basis.z
	if direction.z>=-.001: return -1
	var distance := -local.origin.z/direction.z
	if distance<0 or distance>4: return -1
	var hit := local.origin+direction*distance
	if absf(hit.x)>PANEL_WIDTH*.5 or absf(hit.y)>ROW_HEIGHT*4.5: return -1
	return clampi(int(floor(4.5-hit.y/ROW_HEIGHT)),0,8)

func _panel_input(sample: Dictionary) -> void:
	hovered = -1
	var consumed := false
	for i in 2:
		var valid: bool = sample.focused and sample.get("valid_left" if i==0 else "valid_right",false)
		var active: bool = valid and (paused or recorder.replaying or not handles.grabbed[i])
		var pose: Transform3D = sample.left if i==0 else sample.right
		pointers[i].visible = active
		pointers[i].transform = pose*Transform3D(Basis.IDENTITY,Vector3(0,0,-.45))
		var down: bool = sample.get("left_trigger" if i==0 else "right_trigger",0.0)>.55
		var fresh: bool = down and not trigger_down[i] and pointer_active[i]
		trigger_down[i] = down or not valid
		pointer_active[i] = active
		var row := panel_hit(pose) if active else -1
		if row>=0:
			hovered = row
			if fresh and not consumed:
				consumed = true
				_action(row)

func _action(row: int) -> void:
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
			7: _mark()
			8:
				bracing = (bracing+1)%3
				physics.thrusters_enabled = bracing!=2
				physics.thrust_limit = 15000.0 if bracing==1 else 90000.0
				physics.attitude_limit = 30000.0 if bracing==1 else 150000.0
				_reset()
	trigger_down = [true,true]
	pointer_active = [false,false]
	_update_display()

func _update_display() -> void:
	var texts: Array[String]
	if recorder.replaying:
		texts = ["RETURN TO LIVE (paused) [T]","%s  %.1f / %.1fs [P]" % ["PAUSE REPLAY" if recorder.playing else "PLAY REPLAY",recorder.cursor,recorder.duration()],"BACK 1 SECOND  [ [ ]","FORWARD 1 SECOND  [ ] ]","VIEW: %s [V]" % ("FREE FLIGHT" if free_replay else "RECORDED COCKPIT"),"MARK THIS MOMENT [F8]","EXPORT REPLAY + NOTES [F5]","ADD TEXT NOTE [N / desktop]","JUMP TO START"]
	else:
		texts = ["%s [Esc / stick click]" % ("RESUME" if paused else "PAUSE"),"RESET + CALIBRATE [R]","OPPONENT: %s [M]" % MODE_NAMES[mode],"BASE: %s [F]" % ("FIXED" if fixed_opponent else "FREE"),"REPLAY LAST 20 SECONDS [T]","COCKPIT: %s [C]" % ("PHYSICAL" if physical_camera else "STABILIZED"),"EXPORT CLIP + NOTES [F5]","MARK MOMENT [F8]","BRACING: %s [K]" % ["NORMAL","SOFT","COAST"][bracing]]
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
	status.text = "MELEE LAB / %s\n%s\nL %s   R %s  /  %.1f m/s\n%s\n%s" % ["REPLAY — LIVE FROZEN" if recorder.replaying else ("PAUSED" if paused else MODE_NAMES[mode]),"Amber dots: requested grips","HELD" if handles.grabbed[0] else "PARKED","HELD" if handles.grabbed[1] else "PARKED",speed,load_text,message]

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
	trigger_down = [true,true]
	message = "Release grips, then grab the nearby handles." if not paused else "Paused. Aim either hand at a row and use a fresh trigger."
	_log("pause",{"paused":paused})

func _reset() -> void:
	if recorder.replaying: _leave_replay()
	paused = true
	physics.set_paused(true)
	physics.reset()
	model.reset()
	handles.reset()
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
	if not recorder.begin_replay():
		message = "No clip yet — resume and make an exchange first."
		return
	live_cockpit = cockpit.global_transform
	_enter_replay_view()

func _enter_replay_view() -> void:
	paused = true
	physics.set_paused(true)
	free_replay = false
	for marker in markers: marker.visible = false
	message = "Replay: pause, scrub or switch to free flight. Live bodies are frozen."
	trigger_down = [true,true]
	load_audio.volume_db = -55
	_log("replay_begin",{"duration":recorder.duration()})

func _leave_replay() -> void:
	recorder.end_replay()
	cockpit.global_transform = live_cockpit
	view.update_snapshot(physics.snapshot(),0.0)
	paused = true
	handles.reset()
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
		KEY_K: if not recorder.replaying: _action(8)
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
		get_viewport().get_texture().get_image().save_png("res://artifacts/melee-cockpit.png")
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
