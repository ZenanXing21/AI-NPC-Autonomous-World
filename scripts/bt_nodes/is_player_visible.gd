extends BTCondition
class_name IsPlayerVisible

func tick(actor: Node, blackboard: Dictionary, _delta: float) -> int:
	if actor == null:
		return BTNode.FAILURE

	if actor.can_see_player():
		blackboard["target"] = actor.player
		blackboard["last_known_position"] = actor.player.global_position
		return BTNode.SUCCESS

	return BTNode.FAILURE
