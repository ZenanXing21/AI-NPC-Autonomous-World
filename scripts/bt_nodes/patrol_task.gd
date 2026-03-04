extends BTTask
class_name PatrolTask

func tick(actor: Node, blackboard: Dictionary, delta: float) -> int:
	if actor == null:
		return BTNode.FAILURE
	return actor.bt_patrol(delta, blackboard)
