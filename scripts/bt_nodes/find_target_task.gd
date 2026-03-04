extends BTTask
class_name FindTargetTask

func tick(actor: Node, blackboard: Dictionary, _delta: float) -> int:
	if actor == null:
		return BTNode.FAILURE

	if actor.can_see_player() and actor.player != null:
		blackboard["target"] = actor.player
		blackboard["last_known_position"] = actor.player.global_position
		return BTNode.SUCCESS

	blackboard.erase("target")
	return BTNode.SUCCESS
