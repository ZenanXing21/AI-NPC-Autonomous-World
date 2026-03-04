extends CharacterBody3D

@export var move_speed: float = 3.0
@export var patrol_radius: float = 9.0
@export var arrive_threshold: float = 0.6
@export var wait_time_min: float = 1.0
@export var wait_time_max: float = 4.0
@export var max_pick_attempts: int = 8

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

enum PatrolState {
	MOVING,
	WAITING,
}

var patrol_state: PatrolState = PatrolState.MOVING
var wait_time_left: float = 0.0

func _ready() -> void:
	randomize()
	pick_new_patrol_target()

func _physics_process(delta: float) -> void:
	handle_state(delta)

func pick_new_patrol_target() -> void:
	var nav_map: RID = nav_agent.get_navigation_map()
	if not nav_map.is_valid():
		push_warning("[NPC Patrol] Navigation map is not valid yet; retrying next frame.")
		return

	var chosen_target := global_position
	for i in max_pick_attempts:
		var candidate := global_position + Vector3(
			randf_range(-patrol_radius, patrol_radius),
			0.0,
			randf_range(-patrol_radius, patrol_radius)
		)
		var nav_point := NavigationServer3D.map_get_closest_point(nav_map, candidate)
		if nav_point.distance_to(global_position) > 0.5:
			chosen_target = nav_point
			break

	nav_agent.target_position = chosen_target
	patrol_state = PatrolState.MOVING
	print("[NPC Patrol] New patrol target: ", chosen_target)

func move_along_path(delta: float) -> void:
	_ = delta
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

func handle_state(delta: float) -> void:
	match patrol_state:
		PatrolState.MOVING:
			move_along_path(delta)
			if nav_agent.is_navigation_finished() or global_position.distance_to(nav_agent.target_position) <= arrive_threshold:
				patrol_state = PatrolState.WAITING
				wait_time_left = randf_range(wait_time_min, wait_time_max)
				velocity = Vector3.ZERO
				print("[NPC Patrol] Reached patrol point. Waiting %.2fs" % wait_time_left)
		PatrolState.WAITING:
			wait_time_left -= delta
			if wait_time_left <= 0.0:
				pick_new_patrol_target()
