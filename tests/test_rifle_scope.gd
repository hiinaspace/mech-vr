extends SceneTree
const Rifle = preload("res://scripts/rifle_visual.gd")
const Scope = preload("res://scripts/rifle_scope.gd")
const Weapon = preload("res://scripts/weapon_switch.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var suit := Node3D.new()
	root.add_child(suit)
	suit.transform = Transform3D(Basis(Vector3.UP,.7),Vector3(12,3,8))
	var rifle := Rifle.new()
	rifle.setup(suit)
	var muzzle: Transform3D = rifle.muzzle_transform()
	check(muzzle.origin.is_equal_approx(suit.global_transform * Rifle.MUZZLE), "Muzzle follows transformed rifle barrel")
	check(muzzle.basis.is_equal_approx(suit.global_basis), "Rifle visual and physical bore retain hand aim basis")
	check(rifle.visual_root.get_node("Bore").global_position.is_equal_approx(muzzle.origin), "Shots originate at visible bore")
	var sword := Weapon.new()
	sword.setup_visual(suit)
	var blade: Dictionary = sword.blade_segment()
	check((blade.tip-blade.base).normalized().is_equal_approx(suit.global_basis.y), "Blade extends upward out of fist")
	check(is_equal_approx(blade.base.distance_to(blade.tip),5.7), "Sweep endpoints span full blade")
	check(blade.base.is_equal_approx(suit.global_transform * Weapon.BLADE_BASE), "Sword sweep includes suit and hand transforms")
	var cockpit := Node3D.new()
	root.add_child(cockpit)
	var scope := Scope.new()
	scope.setup(cockpit,root.world_3d)
	var head := Transform3D.IDENTITY
	var hand := Transform3D(Basis.IDENTITY,Vector3(.12,-.12,-.30))
	check(scope.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Hidden scope starts with no rendering")
	scope.update_scope(head,hand,true,true,muzzle)
	check(scope.active and scope.visible, "Held nearby gun handle opens optic")
	check(scope.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Visible optic renders")
	check(scope.camera.global_transform.is_equal_approx(muzzle), "Scope follows actual muzzle including parallax")
	check(is_equal_approx(tan(deg_to_rad(75.0)*.5)/tan(deg_to_rad(scope.camera.fov)*.5),4.0), "Optic angular magnification is fourfold")
	check(scope.position.is_equal_approx(hand.origin+Vector3.UP*.18), "Scope screen sits above diegetic handle")
	hand.origin = Vector3(0,0,-.46)
	scope.update_scope(head,hand,true,true,muzzle)
	check(scope.active, "Near-head hysteresis retains active screen")
	hand.origin.z = -.58
	scope.update_scope(head,hand,true,true,muzzle)
	check(not scope.active, "Moving away hides optic")
	hand.origin.z = -.46
	scope.update_scope(head,hand,true,true,muzzle)
	check(not scope.active, "Outer hysteresis band cannot activate optic")
	hand.origin.z = -.30
	scope.update_scope(head,hand,false,true,muzzle)
	check(not scope.active, "Parked released handle cannot render scope")
	scope.update_scope(head,hand,true,false,muzzle)
	check(not scope.active, "Sword mode disables optic")
	scope.update_scope(head,hand,true,true,muzzle,false)
	check(not scope.active, "Pause or invalid tracking disables optic")
	hand.origin.z = .20
	scope.update_scope(head,hand,true,true,muzzle)
	check(not scope.active, "Behind-head dock cannot open optic")
	hand.origin.z = -.08
	scope.update_scope(head,hand,true,true,muzzle)
	check(not scope.active, "Screen avoids activation inside head")
	check(scope.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Hidden optic stops viewport updates")
	Scope.exclude_tree(suit)
	check(rifle.visual_root.get_node("Bore").layers == Scope.OWN_LAYER, "Own equipment is excluded recursively")
	check(scope.camera.cull_mask & scope.screen.layers == 0, "Scope camera cannot see its own screen")
	check(scope.viewport.world_3d == root.world_3d, "Optic observes same target world")
	suit.free()
	cockpit.free()
	print("RIFLE_SCOPE_TESTS %s checks=%s failures=%s" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(1 if failures else 0)
