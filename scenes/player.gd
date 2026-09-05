extends CharacterBody2D

const SPEED := 200.0

func _physics_process(_delta: float) -> void:
	var input := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	velocity = input * SPEED
	move_and_slide()
