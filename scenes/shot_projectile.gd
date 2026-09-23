extends Area2D

## Buster shot estilo Mega Man: nace chico y crece rápido a su
## tamaño real, deja una colita corta y suelta chispitas de brillo
## mientras vuela. Nada de negro — sólo tonos del propio color del
## disparo.
##
## Progresión de nivel de "disparo a distancia" (ver ranged_power_level
## en player.gd — la carta del mismo nombre lo sube, no es un card
## aparte): nivel 0 = celeste base, sube de color hasta nivel 5 =
## rosado con más partículas y más daño. "Cargado" (post level-up
## normal) SIEMPRE se ve dorado encima de cualquier nivel — es un
## efecto aparte, más raro y llamativo.
##
## Alcance: AUTO_FIRE_RANGE de player.gd (3600) ya es mayor a todo el
## mapa (1900 de punta a punta, ver world.gd WORLD_BOUND), así que
## alcanza con que el proyectil cubra la diagonal completa del mapa
## (~2700) y no los 3600 literales — nada puede estar más lejos que
## eso dentro del mapa igual.
## Range de la flecha — la flecha es el ARMA DE LARGA DISTANCIA por
## excelencia, tiene que sentirse que llega más lejos que las
## espadas voladoras. 700 * 10 = 7000u (mapa entero cabe en 1900).
## SPEED alto también hace que se sienta rápida/afilada.
const SPEED := 700.0
const LIFETIME := 10.0
const DAMAGE := 2.0
const CHARGED_DAMAGE_MULT := 2.5
const CHARGED_SCALE := 1.6
const SPAWN_GROW_TIME := 0.08   # "nace chico" — crece a tamaño real rapidísimo
const SPARKLE_BASE_INTERVAL := 0.05
const SPARKLE_LIFE := 0.22

const RADIUS := 4.0
const TAIL_LENGTH := 9.0

## Body por nivel de "disparo a distancia" (camino fuerza) — índice 0
## = base (antes de tener la carta), índice 5 = máximo (rosado).
## Edge/tip se derivan del body para no tener que declarar 3 arrays
## paralelos.
const LEVEL_BODY: Array = [
	Color(0.55, 0.8, 1.0),    # 0 — celeste base
	Color(0.55, 0.75, 1.0),   # 1
	Color(0.68, 0.62, 1.0),   # 2
	Color(0.85, 0.55, 1.0),   # 3
	Color(1.0, 0.5, 0.92),    # 4
	Color(1.0, 0.4, 0.72),    # 5 — rosado, máximo
]

const COLOR_EDGE_CHARGED := Color(0.75, 0.4, 0.05, 1.0)
const COLOR_BODY_CHARGED := Color(1.0, 0.85, 0.3, 1.0)
const COLOR_TIP_CHARGED := Color(1.0, 1.0, 0.85, 1.0)
const COLOR_TAIL_CHARGED := Color(1.0, 0.6, 0.15, 0.9)

## Sprite del proyectil — flecha del pack weapon_icons. Se instancia
## en _ready y se re-tinta por nivel/charged en _process.
const ARROW_ICON := "res://assets/ui/weapon_icons/icon_43.png"
const ARROW_SCALE := 0.65
## La flecha del icono apunta HACIA ARRIBA (norte). Para que se
## alinee con el vector de vuelo (que orienta al Area2D via
## rotation = dir.angle()), el sprite necesita rotar +π/2 respecto
## al parent — así "arriba" se alinea con "derecha", y de ahí sigue
## la rotación del parent.
const ARROW_ROT_OFFSET := PI * 0.25
var _sprite: Sprite2D

var velocity: Vector2 = Vector2.ZERO
var _damage: float = DAMAGE
var _age: float = 0.0
var _charged: bool = false
var _level: int = 0
var _sparkle_cd: float = 0.0
var _sparkles: Array = []   # [{pos: Vector2, age: float}]

func set_damage(d: float) -> void:
	_damage = d

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_sprite = Sprite2D.new()
	_sprite.texture = load(ARROW_ICON)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(ARROW_SCALE, ARROW_SCALE)
	_sprite.rotation = ARROW_ROT_OFFSET
	add_child(_sprite)

## dir: dirección de vuelo (orienta el dibujo). charged: tiro post
## level-up — más grande, más brillante, más daño (siempre dorado, sin
## importar el nivel de "disparo a distancia"). level: ranged_power_level
## de player.gd (0 = todavía no desbloqueado). Llamar setup() DESPUÉS
## de set_damage() para que el multiplicador de carga se aplique
## sobre el daño ya escalado por damage_mult, no lo pise.
func setup(dir: Vector2, charged: bool = false, level: int = 0) -> void:
	velocity = dir.normalized() * SPEED
	rotation = dir.angle()
	_charged = charged
	_level = clamp(level, 0, LEVEL_BODY.size() - 1)
	if charged:
		_damage *= CHARGED_DAMAGE_MULT
	queue_redraw()

func _process(delta: float) -> void:
	position += velocity * delta
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return

	# Nace chico y crece a tamaño real en SPAWN_GROW_TIME — el "efecto
	# de disparo" en vez de aparecer ya a tamaño completo.
	var base: float = CHARGED_SCALE if _charged else 1.0
	var grow: float = clamp(_age / SPAWN_GROW_TIME, 0.0, 1.0)
	scale = Vector2.ONE * base * lerp(0.3, 1.0, grow)

	# Niveles más altos de "disparo a distancia" sueltan más partículas.
	var sparkle_interval: float = SPARKLE_BASE_INTERVAL / (1.0 + _level * 0.35)
	_sparkle_cd -= delta
	if _sparkle_cd <= 0.0:
		_sparkle_cd = sparkle_interval
		_sparkles.append({
			"pos": Vector2(randf_range(-2.0, 2.0), randf_range(-2.5, 2.5)),
			"age": 0.0,
		})
	for s in _sparkles:
		s["age"] += delta
	_sparkles = _sparkles.filter(func(s): return s["age"] < SPARKLE_LIFE)

	queue_redraw()

func _draw() -> void:
	# El body ahora lo hace el Sprite2D con la flecha real. Acá sólo
	# la trailita y las chispitas para el polish visual.
	var body: Color = COLOR_BODY_CHARGED if _charged else LEVEL_BODY[_level]
	var tail: Color = COLOR_TAIL_CHARGED if _charged else Color(body, 0.9)
	draw_line(Vector2(-TAIL_LENGTH, 0.0), Vector2(-RADIUS * 0.4, 0.0), tail, 2.5, false)

	# Tint del sprite por nivel/charged en cada frame (el modulate es
	# barato y así la flecha sube de color como antes).
	if _sprite:
		_sprite.modulate = body

	var sparkle_color: Color = COLOR_BODY_CHARGED if _charged else body.lerp(Color.WHITE, 0.4)
	for s in _sparkles:
		var a: float = 1.0 - (s["age"] / SPARKLE_LIFE)
		var p: Vector2 = s["pos"]
		draw_rect(Rect2(p - Vector2(0.8, 0.8), Vector2(1.6, 1.6)), Color(sparkle_color, a))

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(_damage)
		queue_free()
