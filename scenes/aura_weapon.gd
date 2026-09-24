extends Node2D

## Arma "Aura sagrada": un círculo alrededor del player que cada tanto
## quema a todos los monstruos adentro. Vive como hijo del player (lo
## sigue sola). Evolución "Santuario" (aura + vida máxima): más grande,
## más blanca, y cada pulso que toca enemigos cura al player.

## Por nivel: radio, daño por pulso, segundos entre pulsos.
const LEVELS: Array = [
	{"radius": 52.0, "damage": 1.5, "tick": 0.6},
	{"radius": 58.0, "damage": 2.0, "tick": 0.55},
	{"radius": 64.0, "damage": 2.6, "tick": 0.5},
	{"radius": 71.0, "damage": 3.3, "tick": 0.45},
	{"radius": 80.0, "damage": 4.2, "tick": 0.4},
]
const EVOLVED_RADIUS_MULT := 1.35
const EVOLVED_HEAL := 0.6

const COLOR_FILL := Color(1.0, 0.82, 0.35, 0.10)
const COLOR_RING := Color(1.0, 0.85, 0.4, 0.55)
const COLOR_FILL_EVO := Color(1.0, 0.97, 0.8, 0.14)
const COLOR_RING_EVO := Color(1.0, 1.0, 0.85, 0.75)

var player = null   # sin tipo: mismo motivo que _swords_rig en player.gd
var level: int = 1
var evolved: bool = false
var _cd: float = 0.3
var _t: float = 0.0
var _pulse: float = 0.0

func setup(p) -> void:
	player = p
	# Debajo del sprite del player, arriba del piso.
	show_behind_parent = true

func set_level(l: int) -> void:
	level = clampi(l, 1, LEVELS.size())

func evolve() -> void:
	evolved = true

func radius() -> float:
	return LEVELS[level - 1]["radius"] * (EVOLVED_RADIUS_MULT if evolved else 1.0)

func _process(delta: float) -> void:
	_t += delta
	_pulse = maxf(0.0, _pulse - delta * 3.0)
	_cd -= delta
	if _cd <= 0.0 and player != null and is_instance_valid(player) and player.hp > 0.0:
		var data: Dictionary = LEVELS[level - 1]
		_cd = data["tick"]
		var r2: float = radius() * radius()
		var hits := 0
		for m in get_tree().get_nodes_in_group("monster"):
			if is_instance_valid(m) and global_position.distance_squared_to(m.global_position) <= r2:
				m.take_damage(data["damage"] * player.damage_mult, "santuario" if evolved else "aura")
				hits += 1
		if hits > 0:
			_pulse = 1.0
			if evolved:
				player.heal(EVOLVED_HEAL)
	queue_redraw()

func _draw() -> void:
	var r := radius()
	var wobble: float = 1.0 + 0.03 * sin(_t * 4.0)
	var fill: Color = COLOR_FILL_EVO if evolved else COLOR_FILL
	var ring: Color = COLOR_RING_EVO if evolved else COLOR_RING
	draw_circle(Vector2.ZERO, r * wobble, Color(fill, fill.a + 0.08 * _pulse))
	draw_arc(Vector2.ZERO, r * wobble, 0.0, TAU, 48, Color(ring, ring.a + 0.3 * _pulse), 2.0, false)
	if evolved:
		draw_arc(Vector2.ZERO, r * 0.62, _t, _t + TAU * 0.8, 32, Color(ring, 0.35), 1.5, false)
