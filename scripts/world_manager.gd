extends Node

@export var npc_template_path: NodePath = NodePath("../CharacterBody3D")
@export var player_path: NodePath = NodePath("../Player")
@export var spawn_npc_count: int = 2
@export var spawn_spacing: float = 2.5
@export var decision_log_interval: float = 3.0
@export var day_night_cycle_seconds: float = 20.0

var npcs: Array[CharacterBody3D] = []
var npc_ai_states: Dictionary = {}
var relationships: Dictionary = {}
var time_of_day: String = "day"
var _log_timer: float = 0.0
var _day_night_timer: float = 0.0
var _player: Node3D

func _ready() -> void:
	randomize()
	_player = get_node_or_null(player_path) as Node3D
	_register_existing_npc()
	_spawn_npcs()
	_init_relationships()
	_emit_global_event("player_enters_town", {"player": _player})
	print("[WorldManager] Ready with NPC count: ", npcs.size())

func _process(delta: float) -> void:
	_log_timer += delta
	_day_night_timer += delta

	if _log_timer >= decision_log_interval:
		_log_timer = 0.0
		_update_ai_state_cache()
		_log_npc_decisions()
		_share_random_gossip()

	if _day_night_timer >= day_night_cycle_seconds:
		_day_night_timer = 0.0
		_toggle_time_of_day()

func _register_existing_npc() -> void:
	var template := get_node_or_null(npc_template_path) as CharacterBody3D
	if template == null:
		push_warning("[WorldManager] NPC template not found at path: %s" % npc_template_path)
		return
	_register_npc(template)

func _spawn_npcs() -> void:
	var template := get_node_or_null(npc_template_path) as CharacterBody3D
	if template == null:
		return

	for i in spawn_npc_count:
		var clone := template.duplicate() as CharacterBody3D
		clone.name = "NPC_%d" % (i + 1)
		clone.global_position = template.global_position + Vector3((i + 1) * spawn_spacing, 0.0, 0.0)
		template.get_parent().add_child(clone)
		_register_npc(clone)

func _register_npc(npc: CharacterBody3D) -> void:
	if npc == null or npcs.has(npc):
		return
	npcs.append(npc)
	npc_ai_states[npc.name] = _safe_get_ai_state(npc)
	if not relationships.has(npc.name):
		relationships[npc.name] = {}
	_apply_time_of_day_to_npc(npc)

func _update_ai_state_cache() -> void:
	for npc in npcs:
		if is_instance_valid(npc):
			npc_ai_states[npc.name] = _safe_get_ai_state(npc)

func _log_npc_decisions() -> void:
	for npc in npcs:
		if not is_instance_valid(npc):
			continue
		var state := npc_ai_states.get(npc.name, "Unknown")
		var target_name := "none"
		if npc.has_method("get_target_node"):
			var target := npc.call("get_target_node") as Node3D
			if target != null:
				target_name = target.name
		print("[WorldManager] NPC=%s state=%s time=%s target=%s" % [npc.name, state, time_of_day, target_name])

func _emit_global_event(event_name: String, payload: Dictionary = {}) -> void:
	for npc in npcs:
		if is_instance_valid(npc) and npc.has_method("on_world_event"):
			npc.call("on_world_event", event_name, payload)

func _toggle_time_of_day() -> void:
	time_of_day = "night" if time_of_day == "day" else "day"
	print("[WorldManager] Time changed to: ", time_of_day)
	for npc in npcs:
		if is_instance_valid(npc):
			_apply_time_of_day_to_npc(npc)

func _apply_time_of_day_to_npc(npc: CharacterBody3D) -> void:
	if npc.has_method("set_schedule_mode"):
		npc.call("set_schedule_mode", time_of_day)

func _init_relationships() -> void:
	for a in npcs:
		if not is_instance_valid(a):
			continue
		if not relationships.has(a.name):
			relationships[a.name] = {}
		for b in npcs:
			if not is_instance_valid(b) or a == b:
				continue
			relationships[a.name][b.name] = randi_range(-20, 20)

func _share_random_gossip() -> void:
	if npcs.size() < 2:
		return
	var a := npcs[randi() % npcs.size()]
	var b := npcs[randi() % npcs.size()]
	if a == b or not is_instance_valid(a) or not is_instance_valid(b):
		return
	var topic := "rumor_%d" % randi_range(1, 5)
	var relation_score: int = relationships.get(a.name, {}).get(b.name, 0)
	if relation_score < -10:
		topic = "complaint_about_%s" % b.name
	if a.has_method("receive_gossip"):
		a.call("receive_gossip", b.name, topic)
	print("[WorldManager] Gossip: %s heard '%s' about %s" % [a.name, topic, b.name])

func _safe_get_ai_state(npc: CharacterBody3D) -> String:
	if npc != null and npc.has_method("get_ai_state"):
		return str(npc.call("get_ai_state"))
	return "Unknown"
