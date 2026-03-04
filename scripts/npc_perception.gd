extends Area3D

signal target_seen(target: Node3D)
signal target_lost(target: Node3D)

@export var target_group: StringName = &"player"

var owner_npc: Node

func _ready() -> void:
	owner_npc = get_parent()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	_ensure_blackboard_keys()
	print("[Perception] Ready. Monitoring targets in group: ", target_group)

func _ensure_blackboard_keys() -> void:
	if owner_npc == null:
		return
	if owner_npc.get("blackboard") == null:
		owner_npc.set("blackboard", {})
	var blackboard: Dictionary = owner_npc.get("blackboard")
	if not blackboard.has("seen_targets"):
		blackboard["seen_targets"] = []
	owner_npc.set("blackboard", blackboard)

func _on_body_entered(body: Node3D) -> void:
	if not _is_valid_target(body):
		return
	_ensure_blackboard_keys()
	var blackboard: Dictionary = owner_npc.get("blackboard")
	var seen_targets: Array = blackboard.get("seen_targets", [])
	if not seen_targets.has(body):
		seen_targets.append(body)
	blackboard["seen_targets"] = seen_targets
	blackboard["current_target"] = body
	owner_npc.set("blackboard", blackboard)
	emit_signal("target_seen", body)
	print("[Perception] Target seen: ", body.name)

func _on_body_exited(body: Node3D) -> void:
	if owner_npc == null:
		return
	if not _is_valid_target(body):
		return
	_ensure_blackboard_keys()
	var blackboard: Dictionary = owner_npc.get("blackboard")
	var seen_targets: Array = blackboard.get("seen_targets", [])
	seen_targets.erase(body)
	blackboard["seen_targets"] = seen_targets
	if blackboard.get("current_target") == body:
		blackboard.erase("current_target")
	owner_npc.set("blackboard", blackboard)
	emit_signal("target_lost", body)
	print("[Perception] Target lost: ", body.name)

func _is_valid_target(body: Node3D) -> bool:
	if body == null:
		return false
	if target_group != StringName() and not body.is_in_group(target_group):
		return false
	return true
