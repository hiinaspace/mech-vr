extends SceneTree
const Weapon = preload("res://scripts/weapon_switch.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func sample() -> Dictionary:
	return {"head": Transform3D.IDENTITY, "right": Transform3D(Basis.IDENTITY, Vector3(.3,.1,.3)),
		"right_trigger": 0.0, "focused": true, "paused": false, "valid_right": true}

func _initialize() -> void:
	var w := Weapon.new()
	var s := sample()
	s.right_trigger = 1.0
	check(not w.step(s,true).changed, "Initial held trigger cannot swap")
	s.right_trigger = 0.0
	check(w.step(s,true).dock_ready, "Real eligible release arms dock")
	s.right_trigger = 1.0
	check(w.step(s,true).changed and w.sword, "Behind-head fresh trigger selects sword")
	check(not w.step(s,true).changed, "Held press cannot swap twice")
	s.right.origin.z = -0.4
	check(w.step(s,true).consume_trigger, "Swap press remains consumed after exiting dock")
	s.right_trigger = 0.0
	check(not w.step(s,true).consume_trigger, "Real release clears consumption outside dock")
	s.right_trigger = 1.0
	check(not w.step(s,true).changed and w.sword, "Normal sword trigger does not switch back")
	s.right.origin.z = 0.3
	check(not w.step(s,true).changed, "Entering dock with held trigger cannot switch")
	s.right_trigger = 0.0
	w.step(s,true)
	s.right_trigger = 1.0
	check(w.step(s,true).changed and not w.sword, "Dock fresh trigger returns to rifle")
	for invalid in ["focused", "valid_right", "paused"]:
		w.reset()
		s = sample()
		w.step(s,true)
		s[invalid] = invalid == "paused"
		w.step(s,true)
		s[invalid] = invalid != "paused"
		s.right_trigger = 1.0
		check(not w.step(s,true).changed, invalid + " recovery requires new release")
		s.right_trigger = 0.0
		w.step(s,true)
		s.right_trigger = 1.0
		check(w.step(s,true).changed, invalid + " recovery fresh release works")
	w.reset()
	s = sample()
	w.step(s,true)
	w.step(s,false)
	s.right_trigger = 1.0
	check(not w.step(s,true).changed, "Ownership handoff cannot inherit armed trigger")
	s.right_trigger = 0.0
	w.step(s,false)
	s.right_trigger = 1.0
	check(not w.step(s,true).changed, "Unowned release cannot arm later acquisition")
	check(w.step(s,false).consume_trigger, "Dock consumes trigger even if UI owned")
	w.reset()
	s = sample()
	w.step(s,true)
	s.right_trigger = .4
	check(not w.step(s,true).changed, "Partial trigger does not switch")
	s.right_trigger = .6
	check(w.step(s,true).changed, "Trigger crosses press threshold")
	s.right_trigger = .4
	w.step(s,true)
	s.right_trigger = 1.0
	check(not w.step(s,true).changed, "Partial release does not rearm")
	w.return_anywhere = true
	s.right.origin.z = -.4
	s.right_trigger = 0.0
	w.step(s,true)
	s.right_trigger = 1.0
	check(w.step(s,true).changed and not w.sword, "Optional anywhere return supported")
	w.reset()
	for pos in [Vector3(.64,.54,.69), Vector3(-.64,-.39,.06)]:
		check(w.dock_contains(Transform3D.IDENTITY, Transform3D(Basis.IDENTITY,pos)), "Generous dock extent")
	for pos in [Vector3(.66,0,.3), Vector3(0,.56,.3), Vector3(0,-.41,.3), Vector3(0,0,.71), Vector3(0,0,.04)]:
		check(not w.dock_contains(Transform3D.IDENTITY, Transform3D(Basis.IDENTITY,pos)), "Outside dock rejected")
	var head := Transform3D(Basis(Vector3.UP,PI/2), Vector3(.2,.1,-.2))
	var right := Transform3D(Basis.IDENTITY, head.origin+Vector3(.3,.1,-.2))
	check(w.dock_contains(head,right), "Dock follows headset yaw and translation")
	head.basis = head.basis * Basis(Vector3.RIGHT, PI/2)
	check(w.dock_contains(head,right), "Looking vertically preserves last usable dock heading")
	var parent := Node3D.new()
	root.add_child(parent)
	var visual := w.setup_visual(parent)
	check(not visual.visible and visual.get_child_count() == 5, "Sword builds hidden geometry and local light")
	for child in visual.get_children():
		check(not child is CollisionObject3D, "Sword contains no collision or damage bodies")
	w.sword = true
	w.step(sample(),true)
	check(visual.visible, "Sword state exposes visual group")
	w.reset()
	check(not visual.visible, "Reset returns to gun")
	parent.free()
	print("WEAPON_SWITCH_TESTS %s checks=%s failures=%s" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(1 if failures else 0)
