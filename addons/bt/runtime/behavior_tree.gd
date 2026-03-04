extends Resource
class_name BehaviorTree

@export var root: BTNode

func tick(actor: Node, blackboard: Dictionary, delta: float) -> int:
	if root == null:
		return BTNode.FAILURE
	return root.tick(actor, blackboard, delta)
