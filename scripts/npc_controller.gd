extends CharacterBody3D

@export var speed = 3.0
@onready var nav = $NavigationAgent3D

func _ready():
	set_random_target()

func set_random_target():
	var target = Vector3(
		randf_range(-10,10),
		0,
		randf_range(-10,10)
	)
	nav.set_target_position(target)

func _physics_process(delta):

	if nav.is_navigation_finished():
		set_random_target()

	var next = nav.get_next_path_position()
	var dir = (next - global_position).normalized()

	velocity = dir * speed
	move_and_slide()
