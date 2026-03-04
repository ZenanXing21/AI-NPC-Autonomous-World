extends Node3D

@export var enabled_in_game: bool = true
@export var target_root_path: NodePath = NodePath(".")
@export var line_height_offset: float = 0.15
@export var label_height: float = 2.3
@export var show_nav_paths: bool = true
@export var show_patrol_targets: bool = true
@export var show_state_labels: bool = true

var _line_mesh_instance: MeshInstance3D
var _line_mesh: ImmediateMesh
var _line_material: StandardMaterial3D
var _label_by_npc: Dictionary = {}

func _ready() -> void:
	visible = enabled_in_game
	_line_mesh_instance = MeshInstance3D.new()
	_line_mesh = ImmediateMesh.new()
	_line_material = StandardMaterial3D.new()
	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_material.vertex_color_use_as_albedo = true
	_line_material.no_depth_test = true
	_line_mesh_instance.mesh = _line_mesh
	_line_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line_mesh_instance)

func _process(_delta: float) -> void:
	if not enabled_in_game:
		_clear_lines()
		return
	_draw_debug()
	_update_labels()

func _draw_debug() -> void:
	_clear_lines()
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _line_material)

	for npc in _iter_npcs():
		if show_nav_paths:
			_draw_nav_path_for_npc(npc)
		if show_patrol_targets:
			_draw_patrol_target_for_npc(npc)

	_line_mesh.surface_end()

func _draw_nav_path_for_npc(npc: Node3D) -> void:
	var nav_agent := _get_nav_agent(npc)
	if nav_agent == null:
		return
	var path: PackedVector3Array = nav_agent.get_current_navigation_path()
	if path.size() < 2:
		return

	for i in range(path.size() - 1):
		var from := path[i] + Vector3(0.0, line_height_offset, 0.0)
		var to := path[i + 1] + Vector3(0.0, line_height_offset, 0.0)
		_add_line(from, to, Color(0.2, 1.0, 1.0, 1.0))

func _draw_patrol_target_for_npc(npc: Node3D) -> void:
	var target := _extract_patrol_target(npc)
	if target == null:
		return
	var center: Vector3 = target + Vector3(0.0, line_height_offset, 0.0)
	var r := 0.35
	_add_line(center + Vector3(-r, 0, 0), center + Vector3(r, 0, 0), Color(1.0, 0.8, 0.0, 1.0))
	_add_line(center + Vector3(0, 0, -r), center + Vector3(0, 0, r), Color(1.0, 0.8, 0.0, 1.0))
	_add_line(center + Vector3(0, -r, 0), center + Vector3(0, r, 0), Color(1.0, 0.8, 0.0, 1.0))

func _add_line(from: Vector3, to: Vector3, color: Color) -> void:
	_line_mesh.surface_set_color(color)
	_line_mesh.surface_add_vertex(from)
	_line_mesh.surface_set_color(color)
	_line_mesh.surface_add_vertex(to)

func _extract_patrol_target(npc: Node) -> Variant:
	if npc.has_method("get"):
		var direct_target = npc.get("patrol_target")
		if direct_target is Vector3:
			return direct_target

	if npc.has_method("get"):
		var bb = npc.get("blackboard")
		if bb is Dictionary:
			var bb_target = bb.get("patrol_target")
			if bb_target is Vector3:
				return bb_target
	return null

func _update_labels() -> void:
	if not show_state_labels:
		for label in _label_by_npc.values():
			if is_instance_valid(label):
				label.queue_free()
		_label_by_npc.clear()
		return

	var alive: Dictionary = {}
	for npc in _iter_npcs():
		var label := _label_by_npc.get(npc)
		if label == null or not is_instance_valid(label):
			label = Label3D.new()
			label.no_depth_test = true
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.modulate = Color(0.9, 1.0, 0.9, 1.0)
			add_child(label)
			_label_by_npc[npc] = label

		label.position = npc.global_position + Vector3(0.0, label_height, 0.0)
		label.text = _build_state_text(npc)
		alive[npc] = true

	for npc in _label_by_npc.keys():
		if not alive.has(npc):
			var old_label: Label3D = _label_by_npc[npc]
			if is_instance_valid(old_label):
				old_label.queue_free()
			_label_by_npc.erase(npc)

func _build_state_text(npc: Node) -> String:
	var state_text := "Unknown"
	if npc.has_method("get_ai_state"):
		state_text = str(npc.call("get_ai_state"))
	elif npc.get("behavior_tree") != null:
		state_text = "BT Active"

	var bt_info := ""
	var bb = npc.get("blackboard") if npc.has_method("get") else null
	if bb is Dictionary:
		if bb.has("target"):
			var target := bb.get("target") as Node3D
			if target != null:
				bt_info = " | BT target=" + target.name
		elif bb.has("current_target"):
			var current_target := bb.get("current_target") as Node3D
			if current_target != null:
				bt_info = " | target=" + current_target.name
	return "%s: %s%s" % [npc.name, state_text, bt_info]

func _get_nav_agent(npc: Node) -> NavigationAgent3D:
	if npc == null:
		return null
	if npc.has_node("NavigationAgent3D"):
		return npc.get_node("NavigationAgent3D") as NavigationAgent3D
	return null

func _iter_npcs() -> Array:
	var root := get_node_or_null(target_root_path)
	if root == null:
		return []
	var result: Array = []
	for child in root.get_children():
		if child is CharacterBody3D and (child.has_method("get_ai_state") or child.has_method("bt_patrol") or child.has_method("bt_chase")):
			result.append(child)
	return result

func _clear_lines() -> void:
	if _line_mesh != null:
		_line_mesh.clear_surfaces()
