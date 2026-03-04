extends Node

signal response_ready(text: String)
signal request_failed(error_message: String)

@export var config_path: String = "res://config/llm_config.cfg"
@export var endpoint: String = "https://api.openai.com/v1/chat/completions"
@export var model: String = "gpt-4o-mini"
@export var api_key: String = ""
@export var api_key_header: String = "Authorization"
@export var request_timeout_seconds: float = 15.0
@export var use_mock_response: bool = true

var _http: HTTPRequest

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	if not _http.request_completed.is_connected(_on_request_completed):
		_http.request_completed.connect(_on_request_completed)
	_load_config()

func _load_config() -> void:
	var config := ConfigFile.new()
	var err := config.load(config_path)
	if err != OK:
		push_warning("[AI LLM] Could not load config at %s" % config_path)
		return
	endpoint = str(config.get_value("llm", "endpoint", endpoint))
	model = str(config.get_value("llm", "model", model))
	api_key = str(config.get_value("llm", "api_key", api_key))
	api_key_header = str(config.get_value("llm", "api_key_header", api_key_header))
	use_mock_response = bool(config.get_value("llm", "use_mock_response", use_mock_response))

func generate_dialogue(player_text: String, npc_memory: Dictionary, npc_name: String = "NPC") -> void:
	if use_mock_response:
		var topic_count := int((npc_memory.get("topics", []) as Array).size())
		var mock := "%s remembers %d topics and says: I heard '%s'." % [npc_name, topic_count, player_text]
		emit_signal("response_ready", mock)
		return

	if api_key.strip_edges() == "":
		emit_signal("request_failed", "Missing API key in config")
		return

	var system_prompt := "You are %s, an NPC in a fantasy town. Stay in character and concise." % npc_name
	var memory_blob := JSON.stringify(npc_memory)
	var payload := {
		"model": model,
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "system", "content": "NPC memory context: " + memory_blob},
			{"role": "user", "content": player_text}
		],
		"temperature": 0.7
	}

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"%s: Bearer %s" % [api_key_header, api_key]
	])
	var err := _http.request(endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		emit_signal("request_failed", "Request failed to start: %s" % err)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		emit_signal("request_failed", "HTTP transport failed: %s" % result)
		return

	if response_code < 200 or response_code >= 300:
		emit_signal("request_failed", "LLM API returned status: %s" % response_code)
		return

	var response_text := body.get_string_from_utf8()
	var parsed = JSON.parse_string(response_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		emit_signal("request_failed", "Invalid JSON response")
		return

	var choices: Array = parsed.get("choices", [])
	if choices.is_empty():
		emit_signal("request_failed", "No choices in response")
		return

	var message: Dictionary = choices[0].get("message", {})
	var content := str(message.get("content", ""))
	if content == "":
		emit_signal("request_failed", "Empty content in response")
		return

	emit_signal("response_ready", content)
