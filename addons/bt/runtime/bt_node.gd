extends Resource
class_name BTNode

const FAILURE := 0
const SUCCESS := 1
const RUNNING := 2

func tick(_actor: Node, _blackboard: Dictionary, _delta: float) -> int:
	return SUCCESS
