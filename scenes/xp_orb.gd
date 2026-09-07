extends Area2D

## Gema de XP dropea de los monsters. Cuando el player está en su
## radio de magnetismo, la orb vuela hacia él con lerp exponencial.
## Al tocar al player, le suma XP y desaparece.

const MAGNET_SPEED := 480.0
const IDLE_BOB_SPEED := 3.0
const IDLE_BOB_AMOUNT := 2.0

@export var xp_value: int = 1

var _target: Node2D = null
var _t := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Micro-bob idle para dar vida
	var s: Sprite2D = $Sprite2D
	create_tween().set_loops().tween_property(s, "position",
		Vector2(0, -IDLE_BOB_AMOUNT), 0.5).from(Vector2(0, IDLE_BOB_AMOUNT))

func set_xp(v: int) -> void:
	xp_value = v
	# Los orbs más grandes cambian de color (verde 3+, morado 5+)
	if v >= 5:
		$Sprite2D.modulate = Color(0.9, 0.5, 1.0)
		$Sprite2D.scale = Vector2(2.0, 2.0)
	elif v >= 3:
		$Sprite2D.modulate = Color(0.6, 1.0, 0.55)
		$Sprite2D.scale = Vector2(1.7, 1.7)

## Llamada por el player cuando la orb está dentro del magnet_radius.
## Setea el target y en _process nos volamos hacia él.
func start_magnet(player: Node2D) -> void:
	_target = player

func _process(delta: float) -> void:
	if _target and is_instance_valid(_target):
		var dir := (_target.global_position - global_position).normalized()
		global_position += dir * MAGNET_SPEED * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("gain_xp"):
		body.gain_xp(xp_value)
		queue_free()
