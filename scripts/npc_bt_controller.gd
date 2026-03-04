extends CharacterBody3D

@export var move_speed: float = 3.0
@export var patrol_radius: float = 9.0
@export var arrive_threshold: float = 0.6
@export var sense_distance: float = 6.0
@export var max_pick_attempts: int = 8
@export var player_path: NodePath
@export var behavior_tree: BehaviorTree

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var blackboard: Dictionary = {}
var player: Node3D

func _ready() -> void:
	randomize()
	if player_path != NodePath():
		player = get_node_or_null(player_path) as Node3D
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		player = get_parent().get_node_or_null("Camera3D") as Node3D
	if behavior_tree == null:
		push_warning("[BT NPC] No behavior tree assigned.")

func _physics_process(delta: float) -> void:
	if behavior_tree == null:
		return
	var result := behavior_tree.tick(self, blackboard, delta)
	if result == BTNode.FAILURE:
		velocity = Vector3.ZERO
		move_and_slide()

func can_see_player() -> bool:
	if player == null:
		return false
	return global_position.distance_to(player.global_position) <= sense_distance

func bt_idle(delta: float, bb: Dictionary, min_idle: float, max_idle: float) -> int:
	velocity = Vector3.ZERO
	move_and_slide()

	if not bb.has("idle_time_left"):
		bb["idle_time_left"] = randf_range(min_idle, max_idle)
		print("[BT NPC] Idle for %.2fs" % bb["idle_time_left"])

	bb["idle_time_left"] -= delta
	if bb["idle_time_left"] <= 0.0:
		bb.erase("idle_time_left")
		return BTNode.SUCCESS
	return BTNode.RUNNING

func bt_patrol(delta: float, bb: Dictionary) -> int:
	if not bb.has("patrol_target"):
		var target := _pick_random_nav_point()
		if target == null:
			return BTNode.FAILURE
		bb["patrol_target"] = target
		nav_agent.target_position = target
		print("[BT NPC] New patrol target: ", target)

	_move_along_path(delta)
	if nav_agent.is_navigation_finished() or global_position.distance_to(bb["patrol_target"]) <= arrive_threshold:
		bb.erase("patrol_target")
		return BTNode.SUCCESS
	return BTNode.RUNNING

func bt_chase(delta: float, bb: Dictionary) -> int:
	if not bb.has("target"):
		return BTNode.FAILURE

	var target_node := bb["target"] as Node3D
	if target_node == null:
		bb.erase("target")
		return BTNode.FAILURE

	nav_agent.target_position = target_node.global_position
	bb["last_known_position"] = target_node.global_position
	_move_along_path(delta)
	print("[BT NPC] Chasing target at: ", target_node.global_position)
	return BTNode.RUNNING

func _pick_random_nav_point() -> Variant:
	var nav_map: RID = nav_agent.get_navigation_map()
	if not nav_map.is_valid():
		push_warning("[BT NPC] Navigation map invalid.")
		return null

	for _i in max_pick_attempts:
		var candidate := global_position + Vector3(
			randf_range(-patrol_radius, patrol_radius),
			0.0,
			randf_range(-patrol_radius, patrol_radius)
		)
		var nav_point := NavigationServer3D.map_get_closest_point(nav_map, candidate)
		if nav_point.distance_to(global_position) > 0.5:
			return nav_point

	return global_position

func _move_along_path(_delta: float) -> void:
	if nav_agent.is_navigation_finished():
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var next_path_position := nav_agent.get_next_path_position()
	var direction := next_path_position - global_position
	direction.y = 0.0

	if direction.length() < 0.001:
		velocity = Vector3.ZERO
	else:
		velocity = direction.normalized() * move_speed
	move_and_slide()
