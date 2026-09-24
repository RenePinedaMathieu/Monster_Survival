extends Node2D

## Número de daño que sube y se desvanece sobre el monstruo golpeado.
## Hay un tope de números vivos a la vez: con 100 bichos en pantalla y
## varias armas pegando, sin tope se volvía ilegible y caro en teléfono.

const LIFE := 0.55
const RISE := 16.0
const FONT_SIZE := 9
const MAX_ALIVE := 36

const COLOR_NORMAL := Color("fff3d6")
const COLOR_BIG := Color("ffd24a")
const COLOR_CRIT := Color("ff6a3d")
const COLOR_OUTLINE := Color("2a1510")

static var _alive: int = 0

var _text: String = ""
var _color: Color = COLOR_NORMAL
var _t: float = 0.0
var _start: Vector2

## Crea el número colgado de `parent` en `pos`. Golpes grandes (>= 20)
## salen dorados y un poco más grandes.
static func spawn(script: Script, parent: Node, pos: Vector2, amount: float, crit: bool = false) -> void:
	# Los críticos siempre se muestran, aunque haya muchos números.
	if (_alive >= MAX_ALIVE and not crit) or parent == null:
		return
	var n = script.new()
	n._text = String.num(amount, 0 if amount >= 10.0 else 1) + ("!" if crit else "")
	n._color = COLOR_CRIT if crit else (COLOR_BIG if amount >= 20.0 else COLOR_NORMAL)
	if crit:
		n.scale = Vector2(1.5, 1.5)
	elif amount >= 20.0:
		n.scale = Vector2(1.3, 1.3)
	parent.add_child(n)
	n.global_position = pos + Vector2(randf_range(-6.0, 6.0), -14.0)
	n._start = n.position

func _ready() -> void:
	_alive += 1
	z_index = 450

func _exit_tree() -> void:
	_alive -= 1

func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	var k: float = _t / LIFE
	position = _start + Vector2(0.0, -RISE * ease(k, 0.4))
	modulate.a = 1.0 if k < 0.6 else 1.0 - (k - 0.6) / 0.4
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var p := Vector2(-w / 2.0, 0.0)
	draw_string_outline(font, p, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 3, COLOR_OUTLINE)
	draw_string(font, p, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, _color)
