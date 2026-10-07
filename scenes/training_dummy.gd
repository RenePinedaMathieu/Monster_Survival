extends CharacterBody2D

## Blanco de práctica (sala QA): un maniquí de la arena que las armas
## toman por un monstruo (grupo "monster", misma API de golpes y
## estados) pero que no se mueve, no ataca y no muere. Muestra los
## números de daño y, arriba, su daño por segundo de los últimos
## WINDOW segundos; recent_damage() da el de cada arma (la sala QA lo
## suma entre todos los blancos para compararlas). La
## quemadura y el veneno se simulan como en monster.gd; la quemadura es
## un % de la vida, así que se calcula sobre REF_HP (un monstruo de
## vida media) y no sobre la vida infinita del blanco.

const DN := preload("res://scenes/damage_number.gd")
const SHEET := "res://assets/ui/village/npc/mannequin1.png"
const FRAME := 32
const WINDOW := 4.0
const HIT_FPS := 12.0
const REF_HP := 100.0

var hp: float = 1000000.0
var max_hp: float = 1000000.0
var is_elite: bool = false
var _dead: bool = false
var _spr: Sprite2D
var _label: Label
var _hits: Array = []        # [tiempo, daño, arma]
var _t: float = 0.0
var _hit_t: float = -1.0     # animación de golpe en curso
var _knock := Vector2.ZERO
var _home := Vector2.ZERO
var _refresh: float = 0.0
var _burn_t := 0.0
var _burn_frac := 0.0
var _burn_tick := 0.0
var _burn_source := "quemadura"
var _poison_t := 0.0
var _poison_dps := 0.0
var _poison_tick := 0.0

func _ready() -> void:
	add_to_group("monster")
	collision_layer = 2
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	add_child(shape)
	_spr = Sprite2D.new()
	_spr.texture = load(SHEET)
	_spr.hframes = 4
	_spr.vframes = 4
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.offset = Vector2(0, -8)
	add_child(_spr)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 7)
	_label.add_theme_color_override("font_color", Color("f4f0d8"))
	_label.add_theme_color_override("font_outline_color", Color("1b1410"))
	_label.add_theme_constant_override("outline_size", 3)
	_label.size = Vector2(60, 12)
	_label.position = Vector2(-30, -42)
	_label.z_index = 20
	add_child(_label)
	_home = position
	_update_label()

func _process(delta: float) -> void:
	_t += delta
	# Golpeado: la animación del maniquí (fila de frente) una vez.
	if _hit_t >= 0.0:
		_hit_t += delta
		var f := int(_hit_t * HIT_FPS)
		if f >= 4:
			_hit_t = -1.0
			_spr.frame = 0
		else:
			_spr.frame = f
	_knock = _knock.lerp(Vector2.ZERO, minf(1.0, 6.0 * delta))
	position = _home + _knock
	# Quemadura y veneno: un golpe cada medio segundo, como monster.gd.
	if _burn_t > 0.0:
		_burn_t -= delta
		_burn_tick += delta
		if _burn_tick >= 0.5:
			take_damage(REF_HP * _burn_frac * _burn_tick, _burn_source)
			_burn_tick = 0.0
	if _poison_t > 0.0:
		_poison_t -= delta
		_poison_tick += delta
		if _poison_tick >= 0.5:
			take_damage(_poison_dps * _poison_tick, "veneno")
			_poison_tick = 0.0
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.25
		_update_label()

## Daño de los últimos WINDOW segundos por arma (id -> daño).
func recent_damage() -> Dictionary:
	while not _hits.is_empty() and _t - _hits[0][0] > WINDOW:
		_hits.pop_front()
	var by := {}
	for h in _hits:
		by[h[2]] = float(by.get(h[2], 0.0)) + h[1]
	return by

func _update_label() -> void:
	var total := 0.0
	for v in recent_damage().values():
		total += v
	_label.text = "DPS %d" % roundi(total / WINDOW)

func take_damage(amount: float, source: String = "", show_number: bool = true) -> void:
	_hits.append([_t, amount, source if source != "" else "?"])
	if show_number:
		DN.spawn(DN, get_tree().current_scene, global_position + Vector2(0, -20), amount)
	_spr.modulate = Color(2.0, 2.0, 2.0)
	create_tween().tween_property(_spr, "modulate", Color.WHITE, 0.12)
	if _hit_t < 0.0:
		_hit_t = 0.0

func is_boss() -> bool:
	return false

func knockback(dir: Vector2, strength: float) -> void:
	_knock = dir * minf(10.0, strength * 0.03)

func _tint(c: Color) -> void:
	modulate = c
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.8)

func apply_slow(_f: float, _d: float) -> void:
	_tint(Color(0.7, 0.85, 1.35))

func apply_poison(dps: float, duration: float) -> void:
	_poison_dps = maxf(_poison_dps if _poison_t > 0.0 else 0.0, dps)
	_poison_t = maxf(_poison_t, duration)
	_tint(Color(0.6, 1.4, 0.6))

func apply_burn(frac: float, duration: float, source: String = "quemadura") -> void:
	_burn_frac = maxf(_burn_frac if _burn_t > 0.0 else 0.0, frac)
	_burn_t = maxf(_burn_t, duration)
	_burn_source = source
	_tint(Color(1.5, 0.8, 0.5))

func apply_stun(_d: float) -> void:
	_tint(Color(1.4, 1.4, 0.6))

func apply_freeze(_d: float) -> void:
	_tint(Color(0.6, 0.9, 1.6))
