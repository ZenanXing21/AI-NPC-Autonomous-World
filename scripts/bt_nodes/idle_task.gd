extends BTTask
class_name IdleTask

@export var min_idle_seconds: float = 0.5
@export var max_idle_seconds: float = 1.5

func tick(actor: Node, blackboard: Dictionary, delta: float) -> int:
	if actor == null:
		return BTNode.FAILURE
	return actor.bt_idle(delta, blackboard, min_idle_seconds, max_idle_seconds)
