extends Node2D

## Acompañante (GameState.COMPANIONS): un animal que sigue al player a un
## costado y usa la habilidad de su línea. El nivel (1-5, se sube en la
## tienda) decide la forma (cría/adulto) y la fuerza de la habilidad.
## player.gd crea uno por espacio al arrancar la run (spawn_companions).
##
## Habilidades:
##   eggs       huevos al enemigo más cercano (Gallo: dos a la vez)
##   collector  junta la experiencia de alrededor
##   truffle    desentierra monedas cada tanto
##   headbutt   embiste a los que se acercan al héroe
##   honk       graznido: frena y lastima a los cercanos
##   wool       defensa extra que se regenera (barra azul)
##   feast      deja comida que cura
##   gallop     el héroe corre más rápido; patea a los cercanos
##   charge     embiste en línea al enemigo más cercano
##
## Sprites: assets/companions/<forma>/{idle,walk}_{front,back,left,right}.png,
## hojas horizontales ya recortadas al animal (tools/ase2png.py --companions).

const EGG_SCRIPT := preload("res://scenes/egg_projectile.gd")
const PICKUP_SCRIPT := preload("res://scenes/pickup.gd")
const FLOAT_TEXT := preload("res://scenes/damage_number.gd")

## Tamaño de frame (el que imprime ase2png.py) y escala en pantalla.
const SPRITES: Dictionary = {
	"chick": {"frame": Vector2(10, 11), "scale": 1.3},
	"chicken": {"frame": Vector2(18, 18), "scale": 1.35},
	"rooster": {"frame": Vector2(18, 20), "scale": 1.4},
	"calf": {"frame": Vector2(34, 24), "scale": 1.1},
	"bull": {"frame": Vector2(44, 34), "scale": 1.2},
	"foal": {"frame": Vector2(36, 31), "scale": 1.0},
	"horse": {"frame": Vector2(44, 36), "scale": 1.15},
	"goatling": {"frame": Vector2(28, 21), "scale": 1.05},
	"goat": {"frame": Vector2(28, 28), "scale": 1.15},
	"gosling": {"frame": Vector2(14, 20), "scale": 1.1},
	"goose": {"frame": Vector2(20, 28), "scale": 1.15},
	"lamb": {"frame": Vector2(26, 21), "scale": 1.05},
	"sheep": {"frame": Vector2(28, 24), "scale": 1.25},
	"rabbit_cub": {"frame": Vector2(14, 15), "scale": 1.05},
	"rabbit": {"frame": Vector2(24, 23), "scale": 1.15},
	"piglet": {"frame": Vector2(22, 17), "scale": 1.2},
	"turkey": {"frame": Vector2(24, 22), "scale": 1.25},
}
const DIRS := ["front", "back", "left", "right"]
const FPS := 9.0
const FOLLOW_OFFSET := Vector2(30.0, 12.0)
const FOLLOW_LERP := 6.0
const WALK_SPEED_MIN := 12.0
const TELEPORT_DIST := 400.0

var player = null   # sin tipo: mismo motivo que _swords_rig en player.gd
var line_id: String = ""
var level: int = 1
var _slot: int = 0
var _ability: String = ""
var _sprite: Sprite2D
var _anims: Dictionary = {}   # "idle"/"walk" -> dir -> Array[Texture2D]
var _facing: String = "front"
var _frame: int = 0
var _anim_t: float = 0.0
var _cd: float = 1.0
var _side: float = -1.0
var _last_pos: Vector2
var _power: float = 1.0
## Embestida del toro / cabezazo de la cabra: mientras dura no sigue al héroe.
var _dash_t: float = 0.0
var _dash_vel: Vector2 = Vector2.ZERO
var _dash_hit: Array = []
var _dash_dmg: float = 0.0
var _dash_knock: float = 0.0

func setup(p, id: String, lvl: int, slot: int = 0) -> void:
	player = p
	line_id = id
	level = clampi(lvl, 1, GameState.COMPANION_MAX_LEVEL)
	_slot = slot
	_ability = GameState.COMPANIONS[id]["ability"]
	_power = GameState.companion_power()
	var form: String = GameState.companion_stage(id, level)[1]
	var sp: Dictionary = SPRITES[form]
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * float(sp["scale"])
	# Los pies en el origen, así queda parado a la altura del héroe.
	_sprite.offset = Vector2(0.0, -sp["frame"].y / 2.0 + 2.0)
	add_child(_sprite)
	for anim in ["idle", "walk"]:
		var per_dir: Dictionary = {}
		for dir in DIRS:
			per_dir[dir] = _slice(load("res://assets/companions/%s/%s_%s.png" % [form, anim, dir]), sp["frame"])
		_anims[anim] = per_dir
	if _slot == 1:
		_side = 1.0
	global_position = _follow_target()
	_last_pos = global_position
	_sprite.texture = _anims["idle"][_facing][0]
	_cd = 1.0 + _slot * 0.5
	_apply_passive()

func _slice(tex: Texture2D, size: Vector2) -> Array:
	var frames: Array = []
	for i in range(maxi(1, floori(tex.get_width() / size.x))):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * size.x, 0, size.x, size.y)
		frames.append(at)
	return frames

# ── Números de cada habilidad según nivel ────────────────────────
## Todo lo que depende del nivel sale de acá: lo usan la partida y la
## descripción de la tienda (describe), así nunca quedan desfasados.
static func stats(id: String, lvl: int) -> Dictionary:
	var p: float = GameState.companion_power()
	match GameState.COMPANIONS[id]["ability"]:
		"eggs":
			return {"cd": 1.3 - 0.1 * lvl, "dmg": (2.0 + 1.2 * lvl) * p, "eggs": 2 if lvl >= 5 else 1}
		"collector":
			return {"cd": 1.5 - 0.15 * lvl, "count": 1 + lvl, "radius": 130.0 + 25.0 * lvl}
		"truffle":
			return {"cd": 26.0 - 3.0 * lvl, "coins": int(round((3 + 3 * lvl) * p))}
		"headbutt":
			return {"cd": 2.4 - 0.25 * lvl, "dmg": (5.0 + 4.0 * lvl) * p, "radius": 65.0 + 6.0 * lvl}
		"honk":
			return {"cd": 7.0 - 0.6 * lvl, "dmg": (1.0 + lvl) * p, "radius": 90.0 + 14.0 * lvl, "slow": 1.4 + 0.3 * lvl}
		"wool":
			return {"cd": 2.6 - 0.3 * lvl, "shield": 5.0 * lvl * p}
		"feast":
			return {"cd": 34.0 - 3.0 * lvl, "heal": minf(0.4, (0.08 + 0.03 * lvl) * p)}
		"gallop":
			return {"cd": 3.2 - 0.3 * lvl, "speed": 0.03 * lvl * p, "dmg": (4.0 + 3.0 * lvl) * p}
		"charge":
			return {"cd": 5.5 - 0.5 * lvl, "dmg": (6.0 + 5.0 * lvl) * p}
	return {"cd": 1.0}

## Texto corto del efecto a ese nivel (tienda).
static func describe(id: String, lvl: int) -> String:
	var s := stats(id, lvl)
	match GameState.COMPANIONS[id]["ability"]:
		"eggs":
			return "%s de %d de daño cada %.1f s" % ["Dos huevos" if s["eggs"] > 1 else "Un huevo", roundi(s["dmg"]), s["cd"]]
		"collector":
			return "Junta %d orbes de XP cada %.1f s" % [s["count"], s["cd"]]
		"truffle":
			return "+%d monedas cada %d s" % [s["coins"], roundi(s["cd"])]
		"headbutt":
			return "Cabezazo de %d de daño cada %.1f s" % [roundi(s["dmg"]), s["cd"]]
		"honk":
			return "Frena y pega %d cada %.1f s" % [roundi(s["dmg"]), s["cd"]]
		"wool":
			return "+%d de defensa que se regenera" % roundi(s["shield"])
		"feast":
			return "Comida que cura %d%% cada %d s" % [roundi(s["heal"] * 100.0), roundi(s["cd"])]
		"gallop":
			return "+%d%% velocidad, patadas de %d" % [roundi(s["speed"] * 100.0), roundi(s["dmg"])]
		"charge":
			return "Embestida de %d de daño cada %.1f s" % [roundi(s["dmg"]), s["cd"]]
	return ""

## Efectos permanentes mientras está (velocidad del caballo, lana de la oveja).
func _apply_passive() -> void:
	var s := stats(line_id, level)
	match _ability:
		"gallop":
			player.move_speed *= 1.0 + float(s["speed"])
		"wool":
			player.max_defense += float(s["shield"])
			player.defense += float(s["shield"])
			player.emit_signal("defense_changed", player.defense, player.max_defense)

## Si se va (la sala QA cambia de acompañante), se lleva su efecto.
func _exit_tree() -> void:
	if player == null or not is_instance_valid(player) or player.is_queued_for_deletion():
		return
	var s := stats(line_id, level)
	match _ability:
		"gallop":
			player.move_speed /= 1.0 + float(s["speed"])
		"wool":
			player.max_defense = maxf(0.0, player.max_defense - float(s["shield"]))
			player.defense = minf(player.defense, player.max_defense)
			player.emit_signal("defense_changed", player.defense, player.max_defense)

# ── Seguir al héroe ──────────────────────────────────────────────

func _follow_target() -> Vector2:
	var off := FOLLOW_OFFSET
	if _ability == "gallop":
		off = Vector2(24.0, 6.0)   # el caballo va más pegado
	return player.global_position + Vector2(off.x * _side, off.y + _slot * 8.0)

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.hp <= 0.0:
		return
	if _dash_t > 0.0:
		_dash_t -= delta
		global_position += _dash_vel * delta
		_hit_along_dash()
	else:
		# El 1ro va del lado contrario a donde camina el héroe; el 2do, del otro.
		if player.velocity.x > 5.0:
			_side = -1.0 if _slot == 0 else 1.0
		elif player.velocity.x < -5.0:
			_side = 1.0 if _slot == 0 else -1.0
		var target := _follow_target()
		if global_position.distance_to(target) > TELEPORT_DIST:
			global_position = target
		else:
			global_position = global_position.lerp(target, FOLLOW_LERP * delta)

	var vel: Vector2 = (global_position - _last_pos) / maxf(delta, 0.0001)
	_last_pos = global_position
	var walking: bool = vel.length() > WALK_SPEED_MIN
	if walking:
		_facing = _dir_key(vel)
	_animate(delta, "walk" if walking else "idle")

	_cd -= delta
	if _cd <= 0.0:
		_cd = float(stats(line_id, level)["cd"]) * (0.7 if _golden else 1.0)
		_use_ability()

func _animate(delta: float, anim: String) -> void:
	var frames: Array = _anims[anim][_facing]
	_anim_t += delta
	if _anim_t >= 1.0 / FPS:
		_anim_t = 0.0
		_frame = (_frame + 1) % frames.size()
	_sprite.texture = frames[_frame % frames.size()]

func _dir_key(v: Vector2) -> String:
	if abs(v.x) > abs(v.y):
		return "right" if v.x > 0.0 else "left"
	return "front" if v.y > 0.0 else "back"

func _nearest_monster(from: Vector2, max_dist: float):
	var best = null
	var best_d2: float = max_dist * max_dist
	for m in get_tree().get_nodes_in_group("monster"):
		if not is_instance_valid(m):
			continue
		var d2: float = from.distance_squared_to(m.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = m
	return best

func _monsters_near(from: Vector2, radius: float) -> Array:
	var out: Array = []
	for m in get_tree().get_nodes_in_group("monster"):
		if is_instance_valid(m) and from.distance_to(m.global_position) <= radius:
			out.append(m)
	return out

# ── Habilidades ──────────────────────────────────────────────────

func _use_ability() -> void:
	var s := stats(line_id, level)
	match _ability:
		"eggs":
			var target = _nearest_monster(global_position, 320.0)
			if target == null:
				_cd = 0.25
				return
			var dir: Vector2 = (target.global_position - global_position).normalized()
			_facing = _dir_key(dir)
			var dmg: float = float(s["dmg"]) * player.damage_mult * (2.0 if _golden else 1.0)
			if int(s["eggs"]) > 1:
				for a in [-0.12, 0.12]:
					_throw_egg(dir.rotated(a), dmg)
			else:
				_throw_egg(dir, dmg)
		"collector":
			var pulled := 0
			for orb in get_tree().get_nodes_in_group("xp_orb"):
				if pulled >= int(s["count"]):
					break
				if is_instance_valid(orb) and orb.has_method("start_magnet") \
						and player.global_position.distance_to(orb.global_position) <= float(s["radius"]):
					orb.start_magnet(player)
					pulled += 1
			if pulled > 0:
				_hop()
		"truffle":
			GameState.add_run_currency(int(s["coins"]))
			FLOAT_TEXT.spawn_text(FLOAT_TEXT, get_tree().current_scene, global_position, "+%d" % s["coins"], Color("ffd24a"), 1.3)
			Audio.play_sfx("coin_pickup", global_position)
			_hop()
		"headbutt":
			var target = _nearest_monster(player.global_position, float(s["radius"]))
			if target == null:
				_cd = 0.3
				return
			_start_dash(target.global_position, 0.14, float(s["dmg"]), 520.0 + 20.0 * level)
		"honk":
			var hit := _monsters_near(global_position, float(s["radius"]))
			if hit.is_empty():
				_cd = 0.5
				return
			for m in hit:
				m.apply_slow(0.5, float(s["slow"]))
				m.take_damage(float(s["dmg"]) * player.damage_mult, "ganso")
			_ring(float(s["radius"]), Color(1.0, 1.0, 1.0, 0.8))
			_hop()
		"wool":
			if player.defense < player.max_defense:
				player.defense = minf(player.max_defense, player.defense + 1.0 * _power)
				player.emit_signal("defense_changed", player.defense, player.max_defense)
		"feast":
			var food := Area2D.new()
			food.set_script(PICKUP_SCRIPT)
			food.kind = "heal"
			food.heal_frac = float(s["heal"])
			var ang := randf() * TAU
			food.position = player.global_position + Vector2(cos(ang), sin(ang)) * randf_range(45.0, 75.0)
			get_tree().current_scene.add_child(food)
			_hop()
		"gallop":
			var hit := _monsters_near(global_position, 38.0)
			for m in hit:
				m.take_damage(float(s["dmg"]) * player.damage_mult, "caballo")
				if m.has_method("knockback"):
					m.knockback((m.global_position - global_position).normalized(), 320.0)
			if hit.is_empty():
				_cd = 0.4
		"charge":
			var target = _nearest_monster(global_position, 230.0)
			if target == null:
				_cd = 0.5
				return
			_start_dash(target.global_position, 0.38, float(s["dmg"]), 440.0)
			Audio.play_sfx("sword_swing", global_position)

## Salto corto: el sprite rebota (el conejo que junta, el chancho que cava).
func _hop() -> void:
	var tw := create_tween()
	tw.tween_property(_sprite, "position:y", -7.0, 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sprite, "position:y", 0.0, 0.12).set_ease(Tween.EASE_IN)

## Onda que se expande (el graznido del ganso).
func _ring(radius: float, color: Color) -> void:
	var ring := Node2D.new()
	ring.z_index = 30
	ring.global_position = global_position
	ring.draw.connect(func():
		ring.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, color, 3.0))
	get_tree().current_scene.add_child(ring)
	ring.scale = Vector2.ONE * 0.2
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2.ONE, 0.25)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.3)
	tw.tween_callback(ring.queue_free)

## Embestida hacia `to` que lastima y empuja a los que atraviesa (toro,
## cabra). Al terminar vuelve sola al lado del héroe (sigue el lerp).
func _start_dash(to: Vector2, duration: float, dmg: float, knock: float) -> void:
	var dir: Vector2 = (to - global_position).normalized()
	var dist: float = global_position.distance_to(to) + 18.0
	_dash_vel = dir * (dist / duration)
	_dash_t = duration
	_dash_hit.clear()
	_dash_dmg = dmg
	_dash_knock = knock
	_facing = _dir_key(dir)

func _hit_along_dash() -> void:
	var source := "toro" if _ability == "charge" else "cabra"
	for m in _monsters_near(global_position, 24.0):
		if m in _dash_hit:
			continue
		# La cabra da UN cabezazo; el toro atropella a todos los del camino.
		if _ability == "headbutt" and not _dash_hit.is_empty():
			return
		_dash_hit.append(m)
		m.take_damage(_dash_dmg * player.damage_mult, source)
		if m.has_method("knockback"):
			m.knockback(_dash_vel.normalized(), _dash_knock)
		player.shake(2.0)

func _throw_egg(dir: Vector2, dmg: float) -> void:
	var egg = Area2D.new()
	egg.set_script(EGG_SCRIPT)
	egg.collision_layer = 0
	egg.collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	egg.add_child(shape)
	get_tree().current_scene.add_child(egg)
	egg.global_position = global_position + dir * 10.0 + Vector2(0.0, -8.0)
	egg.setup(dir, dmg)
	if _golden:
		egg.make_golden()

## Evolución "Gallina dorada" (gallina + regeneración): huevos de oro —
## doble daño, más seguido y +1 moneda por cada golpe.
var _golden: bool = false

func evolve() -> void:
	if _ability != "eggs":
		return
	_golden = true
	_sprite.modulate = Color(1.25, 1.1, 0.6)
