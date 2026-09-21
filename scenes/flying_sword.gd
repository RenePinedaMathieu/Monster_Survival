extends Area2D

## Una espada de luz de la carta "espadas voladoras". El rig
## (flying_swords_rig.gd) es quien decide todo: mientras está en
## FORMATION le va empujando la posición/rotación desde afuera (la V
## detrás del player); cuando le toca atacar, la manda a DASH con
## launch_at(target_node) — la espada queda TELEDIRIGIDA a ese nodo
## (persigue su posición actual, no un punto fijo) hasta pegarle o
## hasta que el blanco deje de existir. Al conectar (o quedarse sin
## blanco) se avisa con la señal `consumed` y se autodestruye — el
## rig se encarga de regenerar una nueva más tarde en ese slot.
##
## Visual: hoja de luz que suelta chispitas de brillo todo el tiempo
## y una estela más marcada mientras dashea. El color sube de nivel
## (ver set_level) hasta un aura arcoíris en el nivel máximo.

enum State { FORMATION, DASH }

const PIXEL := 2.4
const DASH_SPEED := 700.0
const DASH_MAX_TIME := 1.4   # por si el blanco se sigue moviendo, no persigue para siempre
const SPARKLE_INTERVAL := 0.09
const SPARKLE_LIFE := 0.3
const TRAIL_INTERVAL := 0.02
const TRAIL_LIFE := 0.18

## [columna, fila, tono] mirando a +X. Tono: 0=punta, 1=núcleo,
## 2=borde (más oscuro que el núcleo, nunca negro), 3=mango.
const CELLS: Array = [
	[-2, 0, 3], [-1, 0, 3],
	[0, -1, 2], [0, 0, 1], [0, 1, 2],
	[1, -1, 2], [1, 0, 1], [1, 1, 2],
	[2, 0, 0],
]
const COLOR_HILT := Color(0.8, 0.75, 0.55, 1.0)

## Núcleo por nivel — 1 a 4 suben de tono; 5 es rainbow (calculado
## en runtime, ver _core_color()).
const LEVEL_CORE: Array = [
	Color(0.65, 1.0, 0.75),   # 1 — verde luz
	Color(0.55, 0.9, 1.0),    # 2 — celeste
	Color(0.75, 0.6, 1.0),    # 3 — violeta
	Color(1.0, 0.75, 0.35),   # 4 — dorado
]
const MAX_LEVEL := 5

## Sprite de la espada — icono del pack weapon_icons.
const SWORD_ICON := "res://assets/ui/weapon_icons/icon_15.png"
const SWORD_SCALE := 0.6
## El icono viene dibujado apuntando arriba-derecha (~45°). Rotando
## -3π/4 lo dejamos apuntando abajo-izquierda relativo al eje 0, así
## cuando el rig lo orienta con velocity.angle() al vector de dash
## la espada queda apuntando hacia el enemigo con la hoja delante.
const SWORD_ROT_OFFSET := -PI * 0.75
var _sprite: Sprite2D

signal consumed

var state: int = State.FORMATION
var damage: float = 3.0
var level: int = 1

var _dash_target_node: Node2D = null
var _dash_last_dir: Vector2 = Vector2.RIGHT
var _dash_elapsed: float = 0.0
var _sparkle_cd: float = 0.0
var _trail_cd: float = 0.0
var _sparkles: Array = []   # [{pos: Vector2, age: float}]
var _trail: Array = []      # [{pos: Vector2, age: float}]
var _time: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_sprite = Sprite2D.new()
	_sprite.texture = load(SWORD_ICON)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(SWORD_SCALE, SWORD_SCALE)
	_sprite.rotation = SWORD_ROT_OFFSET
	add_child(_sprite)

func set_level(l: int) -> void:
	level = clamp(l, 1, MAX_LEVEL)

func _process(delta: float) -> void:
	_time += delta

	if state == State.DASH:
		_dash_elapsed += delta
		if not is_instance_valid(_dash_target_node) or _dash_elapsed > DASH_MAX_TIME:
			_finish()
			return
		var to_target: Vector2 = _dash_target_node.global_position - global_position
		if to_target.length() < 12.0:
			_finish()
			return
		_dash_last_dir = to_target.normalized()
		rotation = _dash_last_dir.angle()
		global_position += _dash_last_dir * DASH_SPEED * delta

		_trail_cd -= delta
		if _trail_cd <= 0.0:
			_trail_cd = TRAIL_INTERVAL
			_trail.append({"pos": Vector2(-2.0, randf_range(-1.0, 1.0)), "age": 0.0})
		for t in _trail:
			t["age"] += delta
		_trail = _trail.filter(func(t): return t["age"] < TRAIL_LIFE)

	_sparkle_cd -= delta
	if _sparkle_cd <= 0.0:
		_sparkle_cd = SPARKLE_INTERVAL
		_sparkles.append({"pos": Vector2(randf_range(-6.0, 6.0), randf_range(-3.0, 3.0)), "age": 0.0})
	for s in _sparkles:
		s["age"] += delta
	_sparkles = _sparkles.filter(func(s): return s["age"] < SPARKLE_LIFE)

	queue_redraw()

func launch_at(target_node: Node2D) -> void:
	state = State.DASH
	_dash_target_node = target_node
	_dash_elapsed = 0.0

func _finish() -> void:
	consumed.emit()
	queue_free()

func _on_body_entered(body: Node) -> void:
	if state == State.DASH and body.has_method("take_damage"):
		body.take_damage(damage)
		_finish()

func _core_color() -> Color:
	if level >= MAX_LEVEL:
		var hue: float = fmod(_time * 0.5, 1.0)
		return Color.from_hsv(hue, 0.7, 1.0)
	return LEVEL_CORE[clamp(level - 1, 0, LEVEL_CORE.size() - 1)]

func _draw() -> void:
	# El body ahora lo hace el Sprite2D con la espada real. Acá sólo
	# la estela y las chispitas para conservar el polish visual.
	var core: Color = _core_color()

	# Tint del sprite por nivel (rainbow en el máximo, sino LEVEL_CORE).
	if _sprite:
		_sprite.modulate = core

	for t in _trail:
		var a: float = 1.0 - (t["age"] / TRAIL_LIFE)
		draw_rect(Rect2(Vector2(t["pos"]) * PIXEL - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), Color(core, a * 0.8))

	for s in _sparkles:
		var a2: float = 1.0 - (s["age"] / SPARKLE_LIFE)
		var p: Vector2 = s["pos"]
		draw_rect(Rect2(p - Vector2(0.7, 0.7), Vector2(1.4, 1.4)), Color(1.0, 1.0, 1.0, a2))
