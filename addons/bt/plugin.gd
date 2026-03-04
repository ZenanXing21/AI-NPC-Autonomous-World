@tool
extends EditorPlugin

func _enter_tree() -> void:
	print("[SimpleBT] Plugin enabled")

func _exit_tree() -> void:
	print("[SimpleBT] Plugin disabled")
