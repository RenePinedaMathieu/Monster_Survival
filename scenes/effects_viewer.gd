extends Node2D

## VISOR DE EFECTOS (catálogo → EFECTOS): cada arma, efecto y
## acompañante reproducido en vivo contra muñecos, con cámara al zoom del
## juego para verlos del tamaño real. Los muñecos tienen la API que usan
## armas y proyectiles pero no suman estadísticas ni logros. La lista
## marca qué es DIBUJADO POR CÓDIGO (candidato a sprite) y qué es sprite.

const RpgTheme := preload("res://scenes/rpg_theme.gd")
const Monster := preload("res://scenes/monster.gd")
const Companion := preload("res://scenes/companion.gd")
const Pickup := preload("res://scenes/pickup.gd")
const DAMAGE_NUMBER := preload("res://scenes/damage_number.gd")
const SHOT_SCENE := preload("res://scenes/shot_projectile.tscn")
const CATALOG_SCENE := "res://scenes/catalog.tscn"
const BACKGROUNDS := [Color("1c1b22"), Color("5b7a3a"), Color("d9b36b"), Color("e4d3a0")]
const BG_NAMES := ["OSCURO", "PASTO", "ARENA", "PERGAMINO"]
const COLOR_CODE := Color("ff9a3c")

## [nombre, tipo, id, archivo/script que lo dibuja]
const EFFECTS := [
	["Meteoro", "DIBUJADO", "meteor", "meteor.gd"],
	["Aura sagrada", "DIBUJADO", "aura", "aura_weapon.gd"],
	["Santuario (aura evolucionada)", "DIBUJADO", "aura_evo", "aura_weapon.gd"],
	["Rayo en cadena", "DIBUJADO", "rayo", "lightning_weapon.gd + bolt_effect.gd"],
	["Tormenta eléctrica (rayo evo.)", "DIBUJADO", "rayo_evo", "bolt_effect.gd"],
	["Láser en cadena", "DIBUJADO", "laser", "chain_laser_weapon.gd + laser_effect.gd"],
	["Cadena carmesí (láser evo.)", "DIBUJADO", "laser_evo", "chain_laser_weapon.gd + laser_effect.gd"],
	["Pulso", "DIBUJADO", "pulso", "pulse_weapon.gd"],
	["Terremoto (pulso evo.)", "DIBUJADO", "pulso_evo", "pulse_weapon.gd"],
	["Escudo de fuerza (bloquea)", "DIBUJADO", "escudo", "force_shield_weapon.gd"],
	["Bastión (escudo evo., 3 cargas)", "DIBUJADO", "escudo_evo", "force_shield_weapon.gd"],
	["Espadas voladoras", "ÍCONO + DIBUJADO", "espadas", "weapon_icons/icon_15.png + flying_sword.gd"],
	["Hacha giratoria", "ÍCONO", "hacha", "weapon_icons/icon_86.png"],
	["Disparo niv. 1 / 5 / cargado", "ÍCONO + DIBUJADO", "disparo", "weapon_icons/icon_43.png + shot_projectile.gd"],
	["Disparo de fuego", "ÍCONO + DIBUJADO", "fuego", "shot_projectile.gd (efecto fire)"],
	["Disparo eléctrico (rayo instantáneo)", "DIBUJADO", "electrico", "elemental_shot_weapon.gd + bolt_effect.gd"],
	["Disparo congelante", "ÍCONO + DIBUJADO", "congelante", "shot_projectile.gd (efecto freeze)"],
	["Infierno (fuego evo.)", "ÍCONO + DIBUJADO", "fuego_evo", "shot_projectile.gd (fuego con radio)"],
	["Sobrecarga (eléctrico evo.)", "DIBUJADO", "electrico_evo", "elemental_shot_weapon.gd + bolt_effect.gd"],
	["Centinela dron", "DIBUJADO", "centinela", "sentinel_weapon.gd + shot_projectile.gd"],
	["Sierras orbitales", "DIBUJADO", "sierras", "saw_weapon.gd"],
	["Aura helada", "DIBUJADO", "aura_lenta", "slow_aura_weapon.gd"],
	["Cero absoluto (congelante evo.)", "ÍCONO + DIBUJADO", "congelante_evo", "elemental_shot_weapon.gd"],
	["Bola de fuego de ELARA (formas 1-3)", "SPRITE DEL PACK", "elara_fuego", "hero_projectile.gd + sprites/elara/fx/fire_*_1.png"],
	["Bola de fuego de ELARA (formas 4-6)", "SPRITE DEL PACK", "elara_fuego4", "hero_projectile.gd + sprites/elara/fx/fire_*_4.png"],
	["Flecha de DOREN (atraviesa)", "SPRITE DEL PACK", "doren_flecha", "hero_projectile.gd + sprites/doren/fx/arrow.png"],
	["Lobo de SIRA (fuera del juego)", "SPRITE", "lobo", "wolf_ally.gd + sprites/wolf/"],
	["Huevos (gallina)", "DIBUJADO", "huevos", "egg_projectile.gd"],
	["Disparo enemigo (imp)", "DIBUJADO", "enemigo", "enemy_projectile.gd"],
	["Abanico enemigo (beholder)", "DIBUJADO", "abanico", "enemy_projectile.gd"],
	["Anillo de fuego del jefe", "DIBUJADO", "anillo", "enemy_projectile.gd"],
	["Bola de fuego + suelo en llamas", "DIBUJADO", "fuego_suelo", "ground_fire_projectile.gd + burning_ground.gd"],
	["Bomba del barril", "DIBUJADO", "bomba", "pickup.gd (_spawn_blast)"],
	["Charco de barro (pantano)", "DIBUJADO", "barro", "mud_puddle.gd"],
	["Números de daño y textos", "TEXTO", "numeros", "damage_number.gd"],
]

var _bg: int = 0
var _bg_rect: ColorRect
var _bg_button: Button
var _info: Label
var _camera: Camera2D
var _dummy: DummyPlayer
var _repeat_t: float = 0.0
var _repeat_cb: Callable = Callable()
var _stage_nodes: Array = []   # lo que no se borra al cambiar de efecto

func _ready() -> void:
	var back_layer := CanvasLayer.new()
	back_layer.layer = -10
	add_child(back_layer)
	_bg_rect = ColorRect.new()
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.color = BACKGROUNDS[_bg]
	back_layer.add_child(_bg_rect)
	_camera = Camera2D.new()
	_camera.zoom = Vector2(2.0, 2.0)
	_camera.position = Vector2(-70.0, 0.0)   # el panel de la izquierda tapa un poco
	add_child(_camera)
	_camera.make_current()

	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", RpgTheme.wood_box(10.0, 8.0))
	panel.anchor_bottom = 1.0
	panel.offset_left = 8.0
	panel.offset_top = 8.0
	panel.offset_bottom = -8.0
	panel.offset_right = 318.0
	ui.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var title := Label.new()
	title.text = "EFECTOS EN VIVO"
	RpgTheme.style_light_label(title, 20)
	col.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	row.add_child(_button("VOLVER", 13, func(): get_tree().change_scene_to_file(CATALOG_SCENE)))
	_bg_button = _button("FONDO: " + BG_NAMES[_bg], 13, func():
		_bg = (_bg + 1) % BACKGROUNDS.size()
		_bg_rect.color = BACKGROUNDS[_bg]
		_bg_button.text = "FONDO: " + BG_NAMES[_bg])
	row.add_child(_bg_button)
	row.add_child(_button("−", 14, func(): _camera.zoom = Vector2.ONE * maxf(1.0, _camera.zoom.x - 0.5)))
	row.add_child(_button("+", 14, func(): _camera.zoom = Vector2.ONE * minf(4.0, _camera.zoom.x + 0.5)))
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	RpgTheme.style_light_label(_info, 13)
	_info.text = "Elige un efecto. Naranja = dibujado por código (candidato a sprite)."
	col.add_child(_info)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	for e in EFFECTS:
		var b := _button(e[0], 12, _play_effect.bind(e[2]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if e[1] == "DIBUJADO":
			b.add_theme_color_override("font_color", COLOR_CODE.darkened(0.45))
		list.add_child(b)
	for line in GameState.COMPANIONS:
		var name: String = GameState.companion_stage(line, 5)[2]
		var b := _button("Acompañante: " + name, 12, _play_companion.bind(line))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		list.add_child(b)
	_stage_nodes = get_children()
	_play_effect("meteor")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(CATALOG_SCENE)

func _button(text: String, size: int, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 32)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RpgTheme.style_button(b, size)
	b.pressed.connect(cb)
	return b

func _process(delta: float) -> void:
	if _repeat_cb.is_valid():
		_repeat_t -= delta
		if _repeat_t <= 0.0:
			_repeat_t = 1.6
			_repeat_cb.call()

## Borra el escenario y pone el muñeco del héroe con 6 blancos alrededor.
func _reset() -> void:
	_repeat_cb = Callable()
	_repeat_t = 0.0
	for c in get_children():
		if not (c in _stage_nodes):
			c.queue_free()
	_dummy = DummyPlayer.new()
	add_child(_dummy)
	var data: Dictionary = Monster.KIND_DATA["rat"]
	var frames: Array = Monster._build_anim_frames(data, data["frame_size"], 4)["idle"]["front"]
	for i in range(6):
		var d := DummyMonster.new()
		d.frames = frames
		d.sprite_scale = Monster.kind_scale(data)
		var ang := TAU * i / 6.0 + 0.3
		d.position = Vector2(cos(ang), sin(ang) * 0.75) * (95.0 + (i % 2) * 45.0)
		add_child(d)

## Los blancos vivos (los del efecto anterior pueden seguir en el grupo
## hasta el próximo frame).
func _targets() -> Array:
	return get_tree().get_nodes_in_group("monster").filter(func(m): return not m.is_queued_for_deletion())

func _play_effect(id: String) -> void:
	_reset()
	for e in EFFECTS:
		if e[2] == id:
			_info.text = "%s\n[%s] %s" % [e[0], e[1], e[3]]
	var p := _dummy
	match id:
		"meteor":
			_repeat_cb = func():
				var m = Node2D.new()
				m.set_script(preload("res://scenes/meteor.gd"))
				add_child(m)
				var ts := _targets()
				m.global_position = ts[randi() % ts.size()].global_position
		"aura", "aura_evo":
			var w := _weapon(preload("res://scenes/aura_weapon.gd"), true, 3)
			if id == "aura_evo":
				w.evolve()
		"rayo", "rayo_evo":
			var w := _weapon(preload("res://scenes/lightning_weapon.gd"), false, 5)
			if id == "rayo_evo":
				w.evolve()
		"laser", "laser_evo":
			var w := _weapon(preload("res://scenes/chain_laser_weapon.gd"), false, 5)
			if id.ends_with("_evo"):
				w.evolve()
		"pulso", "pulso_evo":
			var w := _weapon(preload("res://scenes/pulse_weapon.gd"), false, 5)
			if id.ends_with("_evo"):
				w.evolve()
		"escudo", "escudo_evo":
			var w := _weapon(preload("res://scenes/force_shield_weapon.gd"), true, 5)
			if id.ends_with("_evo"):
				w.evolve()
			_repeat_cb = func(): _enemy_shot(Color("ff7a2e"), 122.0)
		"centinela":
			_weapon(preload("res://scenes/sentinel_weapon.gd"), true, 3)
		"sierras":
			_weapon(preload("res://scenes/saw_weapon.gd"), true, 3)
		"aura_lenta":
			_weapon(preload("res://scenes/slow_aura_weapon.gd"), true, 5)
		"elara_fuego", "elara_fuego4", "doren_flecha":
			var kind: String = "arrow" if id == "doren_flecha" else "fireball"
			var tier: int = 4 if id == "elara_fuego4" else 1
			_repeat_cb = func():
				for t in _targets():
					var dir: Vector2 = (t.global_position - p.global_position).normalized()
					var pr := Area2D.new()
					pr.set_script(preload("res://scenes/hero_projectile.gd"))
					pr.setup(kind, dir, 6.0 if kind == "fireball" else 4.5, tier)
					if kind == "fireball":
						pr.speed = 240.0
						pr.max_dist = p.global_position.distance_to(t.global_position) + 20.0
					else:
						pr.speed = 520.0
						pr.pierce = 3
						pr.max_dist = 360.0
					add_child(pr)
					pr.global_position = p.global_position + dir * 14.0 + Vector2(0, -6)
		"lobo":
			var wolf := Node2D.new()
			wolf.set_script(preload("res://scenes/wolf_ally.gd"))
			add_child(wolf)
			wolf.setup(_dummy)
		"espadas":
			_weapon(preload("res://scenes/flying_swords_rig.gd"), true, 3)
		"hacha":
			_weapon(preload("res://scenes/axe_weapon.gd"), false, 5)
		"disparo":
			_repeat_cb = func():
				for i in range(3):
					var shot = SHOT_SCENE.instantiate()
					add_child(shot)
					shot.global_position = p.global_position + Vector2(10, -24 + i * 24)
					shot.setup(Vector2.RIGHT, i == 2, [1, 5, 3][i])
		"fuego", "electrico", "congelante", "fuego_evo", "electrico_evo", "congelante_evo":
			var w := _weapon(preload("res://scenes/elemental_shot_weapon.gd"), false, 3)
			w.element = {"fuego": "fire", "electrico": "electric", "congelante": "freeze"}[id.trim_suffix("_evo")]
			if id.ends_with("_evo"):
				w.evolve()
		"huevos":
			_repeat_cb = func():
				var ts := _targets()
				var egg := Area2D.new()
				egg.set_script(preload("res://scenes/egg_projectile.gd"))
				egg.collision_layer = 0
				egg.collision_mask = 2
				var shape := CollisionShape2D.new()
				var circle := CircleShape2D.new()
				circle.radius = 5.0
				shape.shape = circle
				egg.add_child(shape)
				add_child(egg)
				egg.global_position = p.global_position
				egg.setup((ts[randi() % ts.size()].global_position - p.global_position).normalized(), 5.0)
		"enemigo":
			_repeat_cb = func(): _enemy_shot(Color("ff7a2e"), 122.0)
		"abanico":
			_repeat_cb = func():
				for a in [-0.26, 0.0, 0.26]:
					_enemy_shot(Color("b36bff"), 108.0, a)
		"anillo":
			_repeat_cb = func():
				var from: Vector2 = _targets()[0].global_position
				for i in range(12):
					var s := Area2D.new()
					s.set_script(preload("res://scenes/enemy_projectile.gd"))
					add_child(s)
					s.setup(from, Vector2.RIGHT.rotated(TAU * i / 12.0), 90.0, 0.0, Color("ff4d2e"))
		"fuego_suelo":
			_repeat_cb = func():
				var f := Node2D.new()
				f.set_script(preload("res://scenes/ground_fire_projectile.gd"))
				add_child(f)
				f.setup(_targets()[0].global_position, p.global_position + Vector2(randf_range(-50, 50), randf_range(-30, 30)))
		"bomba":
			_repeat_cb = func():
				var pk := Area2D.new()
				pk.set_script(Pickup)
				pk.kind = "bomb"
				pk.monitoring = false
				add_child(pk)
				pk.global_position = p.global_position
				pk._spawn_blast()
				pk.queue_free()
		"barro":
			var mud := Area2D.new()
			mud.set_script(preload("res://scenes/mud_puddle.gd"))
			mud.radius = 60.0
			mud.position = Vector2(-110, 50)
			add_child(mud)
		"numeros":
			_repeat_cb = func():
				var ts := _targets()
				for i in range(ts.size()):
					DAMAGE_NUMBER.spawn(DAMAGE_NUMBER, self, ts[i].global_position, [0.7, 5.0, 12.0, 24.0, 60.0, 3.0][i % 6], i == 4)
				DAMAGE_NUMBER.spawn_text(DAMAGE_NUMBER, self, p.global_position, "+25 VIDA", Color("6ee06e"))

func _play_companion(line: String) -> void:
	_reset()
	var st: Array = GameState.companion_stage(line, 5)
	_info.text = "Acompañante: %s (nivel 5)\n[SPRITE] assets/companions/%s + companion.gd" % [st[2], st[1]]
	var c := Node2D.new()
	c.set_script(Companion)
	add_child(c)
	c.setup(_dummy, line, GameState.COMPANION_MAX_LEVEL, 0)
	# El muñeco camina en círculo para ver cómo lo sigue y se anima.
	_dummy.wander = true

func _weapon(script: Script, attach: bool, level: int) -> Node:
	var w := Node2D.new()
	w.set_script(script)
	if attach:
		_dummy.add_child(w)
	else:
		add_child(w)
	w.setup(_dummy)
	if w.has_method("set_level"):
		w.set_level(level)
	return w

func _enemy_shot(color: Color, speed: float, rot: float = 0.0) -> void:
	var from: Vector2 = _targets()[0].global_position
	var s := Area2D.new()
	s.set_script(preload("res://scenes/enemy_projectile.gd"))
	add_child(s)
	s.setup(from, (_dummy.global_position - from).normalized().rotated(rot), speed, 0.0, color)

# ── Muñecos ──────────────────────────────────────────────────────

## Muñeco de héroe con lo que leen armas, acompañantes y proyectiles.
class DummyPlayer extends CharacterBody2D:
	signal defense_changed(current: float, max_defense: float)
	const FLASH_GOLD := Color(2.2, 1.7, 0.35)
	const FLASH_GREEN := Color(0.55, 2.2, 0.6)
	var hp: float = 100.0
	var max_hp: float = 100.0
	var damage_mult: float = 1.0
	var atk_speed_mult: float = 1.0
	var area_mult: float = 1.0
	var effect_duration_mult: float = 1.0
	var cooldown_mult: float = 1.0
	var move_speed: float = 125.0
	var defense: float = 0.0
	var max_defense: float = 0.0
	var wander: bool = false
	var _t: float = 0.0
	var _flash_t: float = 0.0
	func _ready() -> void:
		add_to_group("player")
		collision_layer = 1
		collision_mask = 0
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 10.0
		shape.shape = circle
		add_child(shape)
		var spr := Sprite2D.new()
		spr.texture = load("res://assets/sprites/swordman/Swordsman_lvl1/Swordsman_lvl1_Idle/Swordsman_lvl1_Idle_front.png")
		spr.region_enabled = true
		spr.region_rect = Rect2(0, 0, 64, 64)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(spr)
	func _process(delta: float) -> void:
		_t += delta
		if wander:
			var prev := position
			position = Vector2(cos(_t * 0.8), sin(_t * 0.8) * 0.6) * 90.0
			velocity = (position - prev) / maxf(delta, 0.0001)
		if _flash_t > 0.0:
			_flash_t -= delta
			modulate = Color(1.6, 0.6, 0.6) if _flash_t > 0.0 else Color.WHITE
	func take_damage(_amount: float) -> void:
		_flash_t = 0.15
	func heal(_amount: float) -> void:
		pass
	func flash(c: Color) -> void:
		modulate = c
		create_tween().tween_property(self, "modulate", Color.WHITE, 0.4)
	func shake(_s: float) -> void:
		pass
	func apply_burn(_frac: float, _dur: float) -> void:
		_flash_t = 0.2
	## Escudo de fuerza colgado del muñeco: bloquea como en el juego.
	func block_projectile(from_pos: Vector2) -> bool:
		for c in get_children():
			if c.has_method("block_projectile") and c.block_projectile(from_pos):
				return true
		return false

## Blanco con la API que usan armas y proyectiles, sin estadísticas.
class DummyMonster extends CharacterBody2D:
	const DN := preload("res://scenes/damage_number.gd")
	var frames: Array = []
	var sprite_scale: float = 1.0
	var hp: float = 1000000.0
	var max_hp: float = 1000000.0
	var is_elite: bool = false
	var _dead: bool = false
	var _slow_t: float = 0.0
	var _spr: Sprite2D
	var _i: int = 0
	var _t: float = 0.0
	var _home := Vector2.ZERO
	var _knock := Vector2.ZERO
	func _ready() -> void:
		add_to_group("monster")
		collision_layer = 2
		collision_mask = 0
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 12.0
		shape.shape = circle
		add_child(shape)
		_spr = Sprite2D.new()
		_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_spr.scale = Vector2.ONE * sprite_scale
		if not frames.is_empty():
			_spr.texture = frames[0]
		add_child(_spr)
		_home = position
	func _process(delta: float) -> void:
		_t += delta
		if _t > 0.15 and not frames.is_empty():
			_t = 0.0
			_i = (_i + 1) % frames.size()
			_spr.texture = frames[_i]
		_knock = _knock.lerp(Vector2.ZERO, minf(1.0, 6.0 * delta))
		position = _home + _knock
		_slow_t = maxf(0.0, _slow_t - delta)
	func take_damage(amount: float, _source: String = "", show_number: bool = true) -> void:
		if show_number:
			DN.spawn(DN, get_tree().current_scene, global_position, amount)
		_spr.modulate = Color(2.0, 2.0, 2.0)
		create_tween().tween_property(_spr, "modulate", Color.WHITE, 0.12)
	func is_boss() -> bool:
		return false
	func knockback(dir: Vector2, strength: float) -> void:
		_knock = dir * minf(40.0, strength * 0.1)
	func _tint(c: Color) -> void:
		modulate = c
		create_tween().tween_property(self, "modulate", Color.WHITE, 0.8)
	func apply_slow(_f: float, d: float) -> void:
		_slow_t = d
		_tint(Color(0.7, 0.85, 1.35))
	func apply_poison(_dps: float, _d: float) -> void:
		_tint(Color(0.6, 1.4, 0.6))
	func apply_burn(_frac: float, _d: float, _s: String = "") -> void:
		_tint(Color(1.5, 0.8, 0.5))
	func apply_stun(_d: float) -> void:
		_tint(Color(1.4, 1.4, 0.6))
	func apply_freeze(_d: float) -> void:
		_tint(Color(0.6, 0.9, 1.6))
