extends Node2D

## Meteorito de la carta "lluvia de meteoros" — cae en una posición
## random cerca de un enemigo, telegrafía con una sombra que crece
## en el piso, y al impactar hace daño en área + una onda expansiva.
## Todo dibujado a mano en pixel art grueso (nada de sprites/partículas).
##
## player.gd instancia esto directo por código (sin .tscn — el look
## entero es _draw()) y le setea `damage` antes de soltarlo al mundo.

const FALL_TIME := 0.7
const IMPACT_RADIUS := 70.0
const SHOCKWAVE_TIME := 0.35
const PIXEL := 4.0

var damage: float = 16.0
var _t := 0.0
var _phase := "falling"   # falling → shockwave → (queue_free)
var _shock_t := 0.0

func _ready() -> void:
	z_index = 500   # por encima de todo mientras cae/explota
	add_to_group("meteor")

func _process(delta: float) -> void:
	match _phase:
		"falling":
			_t += delta
			if _t >= FALL_TIME:
				_impact()
		"shockwave":
			_shock_t += delta
			if _shock_t >= SHOCKWAVE_TIME:
				queue_free()
				return
	queue_redraw()

func _impact() -> void:
	_phase = "shockwave"
	for m in get_tree().get_nodes_in_group("monster"):
		if not is_instance_valid(m): continue
		if global_position.distance_to(m.global_position) <= IMPACT_RADIUS:
			if m.has_method("take_damage"):
				m.take_damage(damage, "meteoros")
	for p in get_tree().get_nodes_in_group("player"):
		if p.has_method("shake") and global_position.distance_to(p.global_position) < 260.0:
			p.shake(2.0)

func _draw() -> void:
	match _phase:
		"falling":
			var t: float = _t / FALL_TIME
			# Sombra en el piso, creciendo — telegraph de dónde va a pegar.
			var shadow_r: float = lerp(6.0, IMPACT_RADIUS * 0.55, t)
			draw_circle(Vector2.ZERO, shadow_r, Color(0, 0, 0, 0.35 * t))
			# La roca cae desde arriba de la pantalla.
			var fall_h: float = lerp(-260.0, 0.0, ease(t, 2.0))
			_draw_rock(Vector2(0, fall_h), 1.0)
		"shockwave":
			var t: float = _shock_t / SHOCKWAVE_TIME
			_draw_rock(Vector2.ZERO, 1.0 - t)
			var ring_r: float = lerp(6.0, IMPACT_RADIUS, t)
			var alpha: float = 1.0 - t
			draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 32, Color(1.0, 0.7, 0.2, alpha), PIXEL, false)
			draw_arc(Vector2.ZERO, ring_r * 0.7, 0.0, TAU, 32, Color(1.0, 0.9, 0.5, alpha * 0.8), PIXEL * 0.7, false)

func _draw_rock(pos: Vector2, alpha: float) -> void:
	var cells := [
		[-1, -1], [0, -1], [1, -1],
		[-2, 0], [-1, 0], [0, 0], [1, 0], [2, 0],
		[-1, 1], [0, 1], [1, 1],
	]
	for c in cells:
		var p: Vector2 = pos + Vector2(c[0], c[1]) * PIXEL
		draw_rect(Rect2(p, Vector2(PIXEL, PIXEL)), Color(0.35, 0.28, 0.22, alpha))
	draw_rect(Rect2(pos + Vector2(-1, -1) * PIXEL, Vector2(PIXEL, PIXEL)), Color(1.0, 0.5, 0.15, alpha))
