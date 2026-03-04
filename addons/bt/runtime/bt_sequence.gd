extends BTNode
class_name BTSequence

@export var children: Array[BTNode] = []

func tick(actor: Node, blackboard: Dictionary, delta: float) -> int:
	for child in children:
		if child == null:
			continue
		var result := child.tick(actor, blackboard, delta)
		if result != SUCCESS:
			return result
	return SUCCESS
