extends Node3D
## Reduced physics has torso and equipment bodies. Limbs here are authored visual
## links to their actual poses, never extra simulated joints or command targets.
const RobotRig = preload("res://scripts/robot_rig.gd")
const Sword = preload("res://scripts/weapon_switch.gd")
const PUPPET_SCALE := .013
const PUPPET_VIEW := Basis(Vector3.UP, deg_to_rad(145.0))
var suits: Array[Node3D] = []
var robots: Array[Node3D] = []
var equipment: Array = []
var leaves: Array[MeshInstance3D] = []
var puppet_leaves: Array[MeshInstance3D] = []
var puppet: Node3D

func setup() -> void:
	if not suits.is_empty(): return
	for i in 2:
		var suit := Node3D.new()
		suit.name = "PlayerExterior" if i == 0 else "OpponentExterior"
		add_child(suit)
		suits.append(suit)
		var robot := RobotRig.new()
		suit.add_child(robot)
		robot.setup()
		# Existing authored chest is (0,-4.9,1) from its cockpit frame.
		robot.position = Vector3(0,4.9,-1)
		robot.posture_enabled = false
		robots.append(robot)
		var grips: Array[Node3D] = []
		for side in 2:
			var grip := Node3D.new()
			robot.add_child(grip)
			grips.append(grip)
		robot.box(grips[0],Vector3(4,6,.4),Vector3.ZERO,Color("247994") if i == 0 else Color("a54d30"))
		robot.box(grips[0],Vector3(3.5,.12,.43),Vector3.ZERO,Color("75dfff") if i == 0 else Color("ffd275"))
		var sword := Sword.new()
		sword.sword = true
		sword.setup_visual(grips[1])
		# Mesh emission survives exact pose replay; transient lighting is owned by
		# the lab contact effects, outside this mesh-only replay representation.
		sword.visual_root.get_node("SwordGlow").visible = false
		equipment.append(grips)
		_collect_meshes(suit)
		if i == 1:
			# Keep the existing silhouette, but make the opposing armor unambiguous.
			var armor: Array[MeshInstance3D] = []
			_find_meshes(robot,armor)
			for mesh in armor:
				var material := mesh.material_override as StandardMaterial3D
				if material and not material.emission_enabled:
					material = material.duplicate()
					material.albedo_color = Color("b76b45") if material.albedo_color.v > .3 else Color("613d36")
					mesh.material_override = material

func _collect_meshes(node: Node) -> void:
	_find_meshes(node,leaves)

func _find_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D: result.append(node)
	for child in node.get_children(): _find_meshes(child,result)

func setup_puppet(parent: Node3D) -> void:
	if is_instance_valid(puppet): return
	puppet = Node3D.new()
	puppet.name = "MeleePoseDisplay"
	parent.add_child(puppet)
	puppet.position = Vector3(.48,-.45,-1.3)
	for source in leaves:
		var miniature := MeshInstance3D.new()
		miniature.mesh = source.mesh
		miniature.material_override = source.material_override
		miniature.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puppet.add_child(miniature)
		puppet_leaves.append(miniature)
	robots[0].box(puppet,Vector3(.38,.008,.30),Vector3(0,-.16,0),Color("163747"))
	_label("PLAYER",Vector3(-.10,-.185,.10),Color("75dfff"))
	_label("OPPONENT",Vector3(.10,-.185,.10),Color("ffa46f"))
	_label("RELATIVE POSES",Vector3(0,.19,0),Color("bac9d7"))
	_update_puppet()

func _label(text: String, at: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 24
	label.pixel_size = .00033
	label.modulate = color
	label.outline_size = 4
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	puppet.add_child(label)
	label.position = at

func update_snapshot(snapshot: Dictionary, _dt: float) -> void:
	var rigs: Array = snapshot.get("rigs",[])
	if rigs.size() < 2: return
	# Replay may hide arbitrary leaves. Restore baseline, then let the visual
	# rig set its conditional rails/flames from this live pose again.
	for leaf in leaves: leaf.visible = true
	suits[0].visible = true
	suits[1].visible = bool(snapshot.get("opponent_visible",true))
	for i in 2:
		suits[i].global_transform = rigs[i].body
		var grips: Array = rigs[i].grips
		for side in 2: equipment[i][side].global_transform = grips[side]
		# Disable pose smoothing and authored flight lean: actual rigid body is the
		# reference frame. Solve visual elbows once, then copy them into the HUD.
		robots[i].reset()
		robots[i].update_pose(0.0,Vector3.ZERO,Vector3.ZERO,equipment[i],Basis.IDENTITY)
	_update_puppet()

## Stable layout: two suit-root world frames followed by all mesh world frames.
## A zero basis marks a hidden leaf, preserving visibility during replay without
## re-solving the arm IK or losing the frame used by the cockpit miniature.
func capture_visuals() -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for suit in suits: result.append(suit.global_transform)
	for leaf in leaves:
		var pose := leaf.global_transform
		if not leaf.is_visible_in_tree(): pose.basis = Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO)
		result.append(pose)
	return result

func apply_visuals(poses: Array) -> void:
	if poses.size() != suits.size()+leaves.size(): return
	for i in suits.size():
		suits[i].visible = true
		suits[i].global_transform = poses[i]
	for i in leaves.size():
		var pose: Transform3D = poses[i+suits.size()]
		leaves[i].visible = absf(pose.basis.determinant()) > .000000001
		if leaves[i].visible: leaves[i].global_transform = pose
	_update_puppet()

func _update_puppet() -> void:
	if not is_instance_valid(puppet) or suits.is_empty(): return
	var reference := suits[0].global_transform.affine_inverse()
	var close := suits[0].global_position.distance_to(suits[1].global_position) < 45.0
	var midpoint := (reference*suits[1].global_position)*.5 if close else Vector3.ZERO
	midpoint.y -= 2.8
	var frames: Array[Transform3D] = []
	var extent := Vector3.ONE
	for i in leaves.size():
		var source := leaves[i]
		var miniature := puppet_leaves[i]
		miniature.visible = source.is_visible_in_tree() and (close or suits[0].is_ancestor_of(source))
		var pose := reference*source.global_transform
		pose.origin = PUPPET_VIEW*(pose.origin-midpoint)
		pose.basis = PUPPET_VIEW*pose.basis
		frames.append(pose)
		if miniature.visible:
			var bounds := source.get_aabb()
			for corner in 8:
				var point := pose*bounds.get_endpoint(corner)
				extent = extent.max(point.abs())
	# One uniform scale for both full poses: fit the display without altering
	# blade/limb proportions or exaggerating distance between the combatants.
	var common_scale := minf(PUPPET_SCALE,minf(.17/extent.x,minf(.15/extent.y,.17/extent.z)))
	for i in frames.size():
		var pose := frames[i]
		pose.origin *= common_scale
		pose.basis = pose.basis.scaled(Vector3.ONE*common_scale)
		puppet_leaves[i].transform = pose
