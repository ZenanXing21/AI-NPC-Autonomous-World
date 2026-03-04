extends CharacterBody3D

@export var move_speed: float = 3.0
@export var patrol_radius: float = 9.0
@export var arrive_threshold: float = 0.6
@export var wait_time_min: float = 1.0
@export var wait_time_max: float = 4.0
@export var sense_distance: float = 6.0
@export var lose_player_after_seconds: float = 3.0
@export var chase_distance: float = 3.0
@export var max_pick_attempts: int = 8
@export var player_path: NodePath

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var perception_area: Area3D = $PerceptionArea
@onready var dialogue_memory: Node = $NPCDialogue

var current_state: State
var states: Dictionary = {}
var blackboard: Dictionary = {
	"seen_targets": [],
}

var wait_time_left: float = 0.0
var lost_player_timer: float = 0.0
var patrol_target: Vector3
var investigate_target: Vector3
var player: Node3D
var current_state_name: String = ""
var schedule_mode: String = "day"

class State:
	extends RefCounted
	func enter(npc) -> void:
		pass
	func physics_update(npc, delta: float) -> void:
		pass
	func exit(npc) -> void:
		pass

class IdleState:
	extends State
	func enter(npc) -> void:
		npc.velocity = Vector3.ZERO
		npc.move_and_slide()
		print("[FSM] Enter IdleState")
	func physics_update(npc, _delta: float) -> void:
		if npc.schedule_mode != "night":
			npc.change_state("PatrolState")

class PatrolState:
	extends State
	func enter(npc) -> void:
		npc.pick_new_patrol_target()
		print("[FSM] Enter PatrolState")
	func physics_update(npc, delta: float) -> void:
		if npc.can_sense_player():
			npc.investigate_target = npc.get_target_position()
			npc.change_state("InvestigateState")
			return

		npc.move_along_path(delta)
		if npc.nav_agent.is_navigation_finished() or npc.global_position.distance_to(npc.patrol_target) <= npc.arrive_threshold:
			npc.wait_time_left -= delta
			if npc.wait_time_left <= 0.0:
				npc.pick_new_patrol_target()

class InvestigateState:
	extends State
	func enter(npc) -> void:
		npc.set_navigation_target(npc.investigate_target)
		print("[FSM] Enter InvestigateState. Heading to: ", npc.investigate_target)
	func physics_update(npc, delta: float) -> void:
		if npc.can_sense_player():
			npc.change_state("ChaseState")
			return

		npc.move_along_path(delta)
		if npc.nav_agent.is_navigation_finished() or npc.global_position.distance_to(npc.investigate_target) <= npc.arrive_threshold:
			npc.change_state("PatrolState")

class ChaseState:
	extends State
	func enter(npc) -> void:
		npc.lost_player_timer = 0.0
		print("[FSM] Enter ChaseState")
	func physics_update(npc, delta: float) -> void:
		if npc.can_sense_player():
			npc.lost_player_timer = 0.0
			var target_pos := npc.get_target_position()
			npc.set_navigation_target(target_pos)
			npc.move_along_path(delta)
			if npc.global_position.distance_to(target_pos) <= npc.chase_distance:
				print("[FSM] Close to target while chasing")
		else:
			npc.lost_player_timer += delta
			if npc.lost_player_timer >= npc.lose_player_after_seconds:
				print("[FSM] Target lost. Returning to patrol")
				npc.change_state("PatrolState")
				return
			npc.move_along_path(delta)

func _ready() -> void:
	randomize()
	if player_path != NodePath():
		player = get_node_or_null(player_path) as Node3D
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		player = get_parent().get_node_or_null("Camera3D") as Node3D

	if perception_area != null:
		if perception_area.has_signal("target_seen") and not perception_area.is_connected("target_seen", Callable(self, "_on_target_seen")):
			perception_area.connect("target_seen", Callable(self, "_on_target_seen"))
		if perception_area.has_signal("target_lost") and not perception_area.is_connected("target_lost", Callable(self, "_on_target_lost")):
			perception_area.connect("target_lost", Callable(self, "_on_target_lost"))

	states = {
		"IdleState": IdleState.new(),
		"PatrolState": PatrolState.new(),
		"InvestigateState": InvestigateState.new(),
		"ChaseState": ChaseState.new(),
	}
	change_state("PatrolState")

func _physics_process(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(self, delta)

func change_state(state_name: String) -> void:
	var next_state: State = states.get(state_name)
	if next_state == null:
		push_warning("[FSM] Unknown state: " + state_name)
		return

	if current_state != null:
		current_state.exit(self)
	current_state = next_state
	current_state_name = state_name
	current_state.enter(self)

func can_sense_player() -> bool:
	var seen_targets: Array = blackboard.get("seen_targets", [])
	if not seen_targets.is_empty():
		return true
	if player == null:
		return false
	return global_position.distance_to(player.global_position) <= sense_distance

func get_target_node() -> Node3D:
	return blackboard.get("current_target") as Node3D

func get_target_position() -> Vector3:
	var target := blackboard.get("current_target") as Node3D
	if target != null:
		return target.global_position
	if player != null:
		return player.global_position
	return global_position

func pick_new_patrol_target() -> void:
	var nav_map: RID = nav_agent.get_navigation_map()
	if not nav_map.is_valid():
		push_warning("[FSM] Navigation map invalid; cannot pick patrol target.")
		return

	var chosen_target := global_position
	for _i in max_pick_attempts:
		var candidate := global_position + Vector3(
			randf_range(-patrol_radius, patrol_radius),
			0.0,
			randf_range(-patrol_radius, patrol_radius)
		)
		var nav_point := NavigationServer3D.map_get_closest_point(nav_map, candidate)
		if nav_point.distance_to(global_position) > 0.5:
			chosen_target = nav_point
			break

	patrol_target = chosen_target
	wait_time_left = randf_range(wait_time_min, wait_time_max)
	set_navigation_target(patrol_target)
	print("[FSM] New patrol target: ", patrol_target, " | wait: ", wait_time_left)

func set_navigation_target(target: Vector3) -> void:
	nav_agent.target_position = target

func move_along_path(_delta: float) -> void:
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


func get_ai_state() -> String:
	return current_state_name

func set_schedule_mode(mode: String) -> void:
	schedule_mode = mode
	if schedule_mode == "night":
		move_speed = 1.8
		if current_state_name == "PatrolState":
			change_state("IdleState")
	else:
		move_speed = 3.0
		if current_state_name == "IdleState":
			change_state("PatrolState")
	print("[FSM] Schedule set to: ", schedule_mode)

func on_world_event(event_name: String, payload: Dictionary) -> void:
	if event_name == "player_enters_town":
		var incoming_player := payload.get("player") as Node3D
		if incoming_player != null:
			player = incoming_player
			print("[FSM] World event: player entered town -> ", player.name)

func receive_gossip(from_npc_name: String, topic: String) -> void:
	if dialogue_memory != null and dialogue_memory.has_method("recall") and dialogue_memory.has_method("remember"):
		var topics: Array = dialogue_memory.call("recall", "topics")
		if topics == null:
			topics = []
		if not topics.has(topic):
			topics.append(topic)
			dialogue_memory.call("remember", "topics", topics)
	print("[FSM] Heard gossip from %s: %s" % [from_npc_name, topic])

func _get_actor_name(actor: Node3D) -> String:
	if actor == null:
		return ""
	if actor.has_meta("player_name"):
		return str(actor.get_meta("player_name"))
	return actor.name


func get_memory_status() -> String:
	if dialogue_memory != null and dialogue_memory.has_method("get_memory_status_text"):
		return str(dialogue_memory.call("get_memory_status_text"))
	return "memory unavailable"

func trigger_dialogue() -> void:
	if dialogue_memory == null or not dialogue_memory.has_method("trigger_dialogue"):
		push_warning("[FSM] Dialogue node missing trigger_dialogue()")
		return
	var speaker := "Traveler"
	var target := get_target_node()
	if target != null:
		speaker = _get_actor_name(target)
	elif player != null:
		speaker = _get_actor_name(player)
	dialogue_memory.call("trigger_dialogue", speaker)


func request_llm_dialogue(player_text: String) -> void:
	if dialogue_memory != null and dialogue_memory.has_method("request_llm_dialogue"):
		dialogue_memory.call("request_llm_dialogue", player_text)
	else:
		push_warning("[FSM] Dialogue node missing request_llm_dialogue()")

func get_last_llm_output() -> String:
	if dialogue_memory != null and dialogue_memory.has_method("get_last_llm_output"):
		return str(dialogue_memory.call("get_last_llm_output"))
	return ""

func _on_target_seen(target: Node3D) -> void:
	blackboard["current_target"] = target
	if dialogue_memory != null and dialogue_memory.has_method("recall"):
		var remembered_name := str(dialogue_memory.call("recall", "player_name"))
		var seen_name := _get_actor_name(target)
		if remembered_name != "" and remembered_name == seen_name:
			print("[FSM] Recognized familiar player: ", remembered_name)
	if current_state == states.get("PatrolState"):
		investigate_target = target.global_position
		change_state("InvestigateState")

func _on_target_lost(target: Node3D) -> void:
	if blackboard.get("current_target") == target:
		blackboard.erase("current_target")
