extends Node3D
## Reduced physics has torso and equipment bodies. Limbs here are authored visual
## links to their actual poses, never extra simulated joints or command targets.
const RobotRig = preload("res://scripts/robot_rig.gd")
const Sword = preload("res://scripts/weapon_switch.gd")
const HeatPaint = preload("res://scripts/melee_heat_paint.gd")
var heat_painters: Dictionary = {}
const METAL_SHADER = preload("res://shaders/melee_metal.gdshader")
const OUTLINE_SHADER = preload("res://shaders/melee_outline.gdshader")
var heat_marks: Dictionary = {}
var arm_efforts: Array = [[0.0,0.0],[0.0,0.0]]
var metal_materials: Dictionary = {}
var miniature_arm_indices: Dictionary = {}
const PUPPET_SCALE := .013
const PUPPET_VIEW := Basis(Vector3.UP, deg_to_rad(145.0))
var suits: Array[Node3D] = []
var robots: Array[Node3D] = []
var equipment: Array = []
var leaves: Array[MeshInstance3D] = []
var rest_leaf_transforms: Array[Transform3D] = []
var sword_visuals: Array[Node3D] = []
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
		sword_visuals.append(sword.visual_root)
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

	for leaf in leaves: rest_leaf_transforms.append(leaf.transform)
	_setup_metal()

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
	puppet.scale = Vector3.ONE*.72
	for source in leaves:
		var miniature := MeshInstance3D.new()
		miniature.mesh = source.mesh
		var flat := StandardMaterial3D.new()
		flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var own := suits[0].is_ancestor_of(source)
		flat.albedo_color = Color("31889e") if own else Color("b8784f")
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE_SHADER
		flat.next_pass = outline
		miniature.material_override = flat
		for rig_index in 2:
			for side in 2:
				if source in [robots[rig_index].rails[side],robots[rig_index].links[side*2],robots[rig_index].links[side*2+1]]:
					miniature_arm_indices[puppet_leaves.size()] = Vector2i(rig_index,side)
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
	for i in leaves.size():
		leaves[i].visible = true
		leaves[i].transform = rest_leaf_transforms[i]
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
		_set_blade_fraction(i,float(rigs[i].get("blade_fraction",1.0)))
	_update_appearance(snapshot,_dt)
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

## Generated once with Image.set_pixel and ImageTexture.create_from_image.
## Contact heat uses DrawableTexture2D face-atlas painting; the compact stamp
## history is retained for exact replay reconstruction without GPU readback.
func _setup_metal() -> void:
	var image := Image.create(128,128,false,Image.FORMAT_RGB8)
	var random := RandomNumberGenerator.new()
	random.seed = 71523
	for y in 128:
		var brush := random.randf_range(.3,.8)
		for x in 128:
			var grain := clampf(brush+random.randf_range(-.09,.09),0,1)
			image.set_pixel(x,y,Color(grain,grain,grain))
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	for i in leaves.size():
		var old := leaves[i].material_override as StandardMaterial3D
		if not old or old.emission_enabled: continue
		var material := ShaderMaterial.new()
		material.shader = METAL_SHADER
		material.set_shader_parameter("grain_texture",texture)
		material.set_shader_parameter("metal_color",old.albedo_color.lerp(Color("d7dde1"),.64))
		leaves[i].material_override = material
		metal_materials[i] = material
	_refresh_materials()

func _update_appearance(snapshot: Dictionary, dt: float) -> void:
	for index in heat_marks.keys():
		var retained: Array = []
		for mark in heat_marks[index]:
			mark.w = maxf(0,mark.w-maxf(dt,0)*.22)
			if mark.w > .001: retained.append(mark)
		heat_marks[index] = retained
	for i in 2:
		var loads: Array = snapshot.rigs[i].get("loads",[])
		for side in 2:
			arm_efforts[i][side] = clampf(float(loads[side].get("effort",0)),0,1) if loads.size()>side else 0.0
	var heated_sabers: Dictionary = {}
	for contact in (snapshot.get("beam_contacts",[]) if dt>0 else []):
		if not contact.has("saber_rig") or heated_sabers.has(contact.saber_rig): continue
		heated_sabers[contact.saber_rig] = true
		var rig_index := int(contact.get("target_rig",-1))
		if rig_index < 0 or rig_index >= 2: continue
		var part: String = contact.get("target_part","")
		var target: MeshInstance3D
		if part == "torso": target = robots[rig_index].chest
		elif part == "shield": target = equipment[rig_index][0].get_child(0)
		else: continue
		var index := leaves.find(target)
		var local: Vector3 = target.to_local(contact.position)
		var marks: Array = heat_marks.get(index,[])
		var merged := false
		for m in marks.size():
			if Vector3(marks[m].x,marks[m].y,marks[m].z).distance_to(local) < .45:
				marks[m].w = minf(1,marks[m].w+dt*2.5)
				merged = true
				break
		if not merged:
			if marks.size() >= 8: marks.pop_front()
			marks.append(Vector4(local.x,local.y,local.z,minf(1,dt*2.5)))
		heat_marks[index] = marks
	_refresh_materials()

func _refresh_materials() -> void:
	for index in metal_materials:
		var stored: Array = heat_marks.get(index,[])
		if not stored.is_empty() and not heat_painters.has(index):
			heat_painters[index] = HeatPaint.new()
			metal_materials[index].set_shader_parameter("heat_texture",heat_painters[index].texture)
			metal_materials[index].set_shader_parameter("half_size",leaves[index].get_aabb().size*.5)
		if heat_painters.has(index): heat_painters[index].paint(leaves[index],stored)
		metal_materials[index].set_shader_parameter("has_heat",not stored.is_empty())
	for index in miniature_arm_indices:
		var arm: Vector2i = miniature_arm_indices[index]
		var effort: float = arm_efforts[arm.x][arm.y]
		var material := puppet_leaves[index].material_override as StandardMaterial3D
		material.albedo_color = Color("26a87a").lerp(Color("e9b839"),minf(effort*2,1)).lerp(Color("ef3439"),maxf(0,effort*2-1))

## Root records this beside visuals; replay restores it after apply_visuals.
## No heat/damage physics is affected, and playback never integrates cooling.
func capture_appearance() -> Dictionary:
	var serialized: Array = []
	for index in heat_marks:
		for mark in heat_marks[index]:
			serialized.append({"leaf":index,"position":Vector3(mark.x,mark.y,mark.z),"heat":mark.w})
	return {"heat_marks":serialized,"arm_efforts":arm_efforts.duplicate(true)}

func apply_appearance(appearance: Dictionary) -> void:
	if not valid_appearance(appearance): return
	heat_marks.clear()
	for mark in appearance.get("heat_marks",[]):
		var index := int(mark.leaf)
		if not metal_materials.has(index): continue
		var marks: Array = heat_marks.get(index,[])
		var position: Vector3 = mark.position
		marks.append(Vector4(position.x,position.y,position.z,float(mark.heat)))
		heat_marks[index] = marks
	arm_efforts = appearance.get("arm_efforts",[[0.0,0.0],[0.0,0.0]]).duplicate(true)
	_refresh_materials()

func reset_appearance() -> void:
	apply_appearance({})

func valid_appearance(appearance: Dictionary) -> bool:
	var marks = appearance.get("heat_marks",[])
	var efforts = appearance.get("arm_efforts",[[0.0,0.0],[0.0,0.0]])
	if not marks is Array or marks.size()>leaves.size()*8: return false
	if not efforts is Array or efforts.size()!=2: return false
	for pair in efforts:
		if not pair is Array or pair.size()!=2: return false
		for value in pair:
			if not (value is float or value is int) or not is_finite(float(value)) or value<0 or value>1: return false
	var counts: Dictionary = {}
	for mark in marks:
		if not mark is Dictionary: return false
		var index = mark.get("leaf")
		var position = mark.get("position")
		var heat = mark.get("heat")
		if not (index is int or index is float) or not is_finite(float(index)) or int(index)!=index or not metal_materials.has(int(index)): return false
		if not position is Vector3 or not position.is_finite(): return false
		if not (heat is float or heat is int) or not is_finite(float(heat)) or heat<0 or heat>1: return false
		counts[index] = int(counts.get(index,0))+1
		if counts[index]>8: return false
	return true

## Beam-shell meshes terminate at the first armor entry. The solver/query blade
## remains full length; these are exclusively rendered geometry transforms.
func _set_blade_fraction(rig_index: int, fraction: float) -> void:
	var end := .65+5.7*clampf(fraction,0,1)
	for part in 2:
		var mesh := sword_visuals[rig_index].get_child(part+2) as MeshInstance3D
		var base := .65 if part==0 else .75
		var full := 5.7 if part==0 else 5.5
		var length := clampf(end-base,0,full)
		mesh.visible = length>.001
		mesh.position = Vector3(0,base+length*.5,-.15)
		mesh.scale = Vector3(1,maxf(.0001,length/full),1)
