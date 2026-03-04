extends BTTask
class_name ChaseTask

func tick(actor: Node, blackboard: Dictionary, delta: float) -> int:
	if actor == null:
		return BTNode.FAILURE
	return actor.bt_chase(delta, blackboard)
