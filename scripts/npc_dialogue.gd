extends Node

signal player_interacted(player_name: String, topic: String)

@export var interaction_range: float = 3.0
@export var default_topics: PackedStringArray = ["town", "work", "rumors"]

var memory: Dictionary = {
	"player_name": "",
	"topics": [],
	"interaction_count": 0,
}

var _owner_npc: Node3D
var _current_player: Node3D

func _ready() -> void:
	_owner_npc = get_parent() as Node3D
	if not player_interacted.is_connected(_on_player_interacted):
		player_interacted.connect(_on_player_interacted)
	print("[Dialogue] Ready. Press interact near NPC to talk.")

func _process(_delta: float) -> void:
	_current_player = _find_nearby_player()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _current_player != null:
		var player_name := _resolve_player_name(_current_player)
		var topic := _pick_topic_for_next_line()
		emit_signal("player_interacted", player_name, topic)

func remember(key: String, value: Variant) -> void:
	memory[key] = value

func recall(key: String) -> Variant:
	return memory.get(key)

func forget(key: String) -> void:
	memory.erase(key)

func _on_player_interacted(player_name: String, topic: String) -> void:
	remember("player_name", player_name)

	var topics: Array = memory.get("topics", [])
	if not topics.has(topic):
		topics.append(topic)
	remember("topics", topics)

	var count: int = int(memory.get("interaction_count", 0)) + 1
	remember("interaction_count", count)

	print("[Dialogue] " + _compose_dialogue_line(player_name, topic, count, topics))

func _compose_dialogue_line(player_name: String, topic: String, count: int, topics: Array) -> String:
	if count == 1:
		return "Hello %s, nice to meet you. Let's talk about %s." % [player_name, topic]

	var known_name: String = str(recall("player_name"))
	if known_name == player_name and topics.has(topic):
		return "Welcome back %s. We already discussed %s. Want to hear rumors instead?" % [player_name, topic]

	return "Good to see you again %s. Last time we spoke %d times. Let's discuss %s now." % [player_name, count - 1, topic]

func _find_nearby_player() -> Node3D:
	if _owner_npc == null:
		return null
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Node3D
		if player != null and _owner_npc.global_position.distance_to(player.global_position) <= interaction_range:
			return player
	return null

func _resolve_player_name(player_node: Node3D) -> String:
	if player_node == null:
		return "Traveler"
	if player_node.has_meta("player_name"):
		return str(player_node.get_meta("player_name"))
	return player_node.name

func _pick_topic_for_next_line() -> String:
	var topics: Array = memory.get("topics", [])
	for topic in default_topics:
		if not topics.has(topic):
			return topic
	if default_topics.is_empty():
		return "life"
	return String(default_topics[randi() % default_topics.size()])
