extends SceneTree
const Rig = preload("res://scripts/robot_rig.gd")
const Trail = preload("res://scripts/exhaust_trail.gd")
var checks := 0
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		push_error(description)
		quit(1)
		assert(false,description)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var rig := Rig.new()
	root.add_child(rig)
	rig.setup()
	var left := Node3D.new()
	var right := Node3D.new()
	left.position = Vector3(-5,-2,-5)
	right.position = Vector3(5,-2,-5)
	var hands: Array[Node3D] = [left,right]
	rig.update_pose(.02,Vector3(0,0,-5),Vector3(0,0,-12),hands,Basis.IDENTITY)
	check(rig.flames.size()==7,"Seven shared flames")
	check(rig.jet_lights.size()==2,"Two shadowless local lights")
	check(rig.flames[3].visible and rig.flames[6].visible,"Limb jets fire during command")
	check(rig.world_exhaust_origins().size()==2,"Two trail origins")
	rig.update_pose(.02,Vector3(0,0,-5),Vector3.ZERO,hands,Basis.IDENTITY)
	for flame in rig.flames: check(not flame.visible,"Coast flame hidden")
	for light in rig.jet_lights: check(not light.visible,"Coast light hidden")
	rig.update_pose(.02,Vector3(0,0,-5),Vector3(0,0,-12),hands,Basis.IDENTITY,true)
	for flame in rig.flames: check(not flame.visible,"Pause suppresses commanded flame")
	for light in rig.jet_lights: check(not light.visible,"Pause suppresses local light")
	rig.update_pose(.02,Vector3(0,0,-30),Vector3.ZERO,hands,Basis.IDENTITY,false,true)
	check(rig.flames[3].visible and rig.jet_lights[0].visible,"Speed-limited boost retains exhaust and local light")
	check(is_equal_approx(rig.effect_strength,6.0),"Boost-only visual floor available to wake")
	check(rig.flight.main_acceleration==0 and rig.flight.residual_acceleration==Vector3.ZERO,"Boost visual floor does not fabricate physical acceleration")
	rig.update_pose(.02,Vector3(0,0,-30),Vector3.ZERO,hands,Basis.IDENTITY,false,false)
	check(rig.effect_strength==0 and not rig.flames[3].visible and not rig.jet_lights[0].visible,"Release boost restores true coasting effects")
	rig.update_pose(.02,Vector3(0,0,-30),Vector3.ZERO,hands,Basis.IDENTITY,true,true)
	check(rig.effect_strength==0 and not rig.flames[3].visible,"Pause overrides held boost visual floor")
	var trail := Trail.new()
	root.add_child(trail)
	trail.setup()
	var points: Array[Vector3] = [Vector3(-1,0,0),Vector3(1,0,0)]
	for i in 120:
		points[0].z = -i*.2
		points[1].z = -i*.2
		trail.update_trail(.08,points,Vector3(0,0,-2.5),12,false)
	check(trail.active_count()>0 and trail.active_count()<=96,"Trail bounded and visible")
	var saved := trail.pieces[0].global_position
	# Moving/turning the source rig and head must not drag already emitted wake.
	rig.position = Vector3(8,3,5)
	rig.rotation = Vector3(.1,.8,0)
	rig.update_pose(.02,Vector3.ZERO,Vector3.ZERO,hands,Basis(Vector3.UP,.7))
	check(trail.pieces[0].global_position==saved,"Head and source movement cannot move old wake")
	points[0].z-=2
	points[1].z-=2
	trail.update_trail(.01,points,Vector3(0,0,-2.5),0,false)
	check(trail.pieces[0].global_position==saved,"Old wake stays in world frame")
	trail.update_trail(3,points,Vector3.ZERO,0,true)
	check(trail.active_count()==0,"Paused wake expires")
	points[0].z-=.5
	points[1].z-=.5
	trail.update_trail(.1,points,Vector3(0,0,-5),12,false)
	check(trail.active_count()==2,"Fresh emission resumes")
	points[0].z-=100
	points[1].z-=100
	trail.update_trail(.1,points,Vector3(0,0,-5),12,false)
	check(trail.active_count()==0,"Teleport flushes history")
	trail.reset()
	check(trail.active_count()==0,"Reset clears wake")
	left.free()
	right.free()
	print("EXHAUST checks=%d" % checks)
	quit()
