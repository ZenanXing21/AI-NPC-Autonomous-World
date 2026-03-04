extends CanvasLayer

@export var target_npc_path: NodePath = NodePath("../CharacterBody3D")
@export var refresh_interval: float = 0.2

@onready var _name_label: Label = $PanelContainer/MarginContainer/VBoxContainer/NPCNameValue
@onready var _state_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StateValue
@onready var _memory_label: Label = $PanelContainer/MarginContainer/VBoxContainer/MemoryValue
@onready var _dialogue_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TriggerDialogueButton
@onready var _llm_input: LineEdit = $PanelContainer/MarginContainer/VBoxContainer/LLMInput
@onready var _llm_button: Button = $PanelContainer/MarginContainer/VBoxContainer/AskLLMButton
@onready var _llm_output: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/LLMOutput

var _target_npc: Node
var _refresh_timer: float = 0.0

func _ready() -> void:
	_target_npc = get_node_or_null(target_npc_path)
	_dialogue_button.pressed.connect(_on_trigger_dialogue_button_pressed)
	_llm_button.pressed.connect(_on_ask_llm_button_pressed)
	_update_labels()

func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer >= refresh_interval:
		_refresh_timer = 0.0
		if _target_npc == null:
			_target_npc = get_node_or_null(target_npc_path)
		_update_labels()

func _update_labels() -> void:
	if _target_npc == null:
		_name_label.text = "Name: N/A"
		_state_label.text = "State: N/A"
		_memory_label.text = "Memory: N/A"
		_llm_output.text = "LLM: NPC target not found"
		return

	_name_label.text = "Name: %s" % _target_npc.name
	if _target_npc.has_method("get_ai_state"):
		var raw_state := str(_target_npc.call("get_ai_state"))
		_state_label.text = "State: %s" % _format_state_name(raw_state)
	else:
		_state_label.text = "State: Unknown"

	if _target_npc.has_method("get_memory_status"):
		_memory_label.text = "Memory: %s" % str(_target_npc.call("get_memory_status"))
	else:
		_memory_label.text = "Memory: No memory interface"

	if _target_npc.has_method("get_last_llm_output"):
		var output := str(_target_npc.call("get_last_llm_output"))
		if output != "":
			_llm_output.text = "LLM: " + output

func _format_state_name(state_name: String) -> String:
	match state_name:
		"PatrolState":
			return "Patrolling"
		"InvestigateState":
			return "Investigating"
		"ChaseState":
			return "Chasing"
		"IdleState":
			return "Idle"
		_:
			return state_name

func _on_trigger_dialogue_button_pressed() -> void:
	if _target_npc != null and _target_npc.has_method("trigger_dialogue"):
		_target_npc.call("trigger_dialogue")
		_update_labels()

func _on_ask_llm_button_pressed() -> void:
	if _target_npc == null or not _target_npc.has_method("request_llm_dialogue"):
		_llm_output.text = "LLM: target NPC does not support LLM dialogue"
		return
	var player_text := _llm_input.text.strip_edges()
	if player_text == "":
		player_text = "Tell me about this town."
	_target_npc.call("request_llm_dialogue", player_text)
	_llm_output.text = "LLM: request sent..."
