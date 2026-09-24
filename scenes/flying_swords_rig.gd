extends Node2D

## Rig de la carta "espadas voladoras": mantiene hasta 5 espadas
## (flying_sword.gd) formadas en una V aplanada detrás del player
## (no orbitando alrededor). Cada tanto UNA espada disponible ataca
## al enemigo más cercano dentro de su alcance (bastante más corto
## que el del disparo a distancia — ver ATTACK_RANGE); al conectar (o
## llegar sin pegarle) desaparece, y ese slot arranca su propio
## regen — se van reponiendo de a una, no todas juntas.
##
## player.gd crea UNA instancia de este rig la primera vez que se
## elige la carta; picks repetidos llaman a buff() en vez de crear un
## segundo rig.

const BLADE_SCRIPT := preload("res://scenes/flying_sword.gd")
const MAX_SWORDS := 5
const SWORD_DAMAGE := 3.0
const ATTACK_INTERVAL := 1.3    # cada tanto ataca UNA espada disponible
const RETRY_INTERVAL := 0.3     # si no hay blanco/espada, reintenta pronto
const REGEN_TIME := 2.2         # tiempo para que reaparezca una espada consumida
## Bastante más corto que AUTO_FIRE_RANGE del player — las espadas
## son de medio alcance, el disparo es el de largo alcance real.
const ATTACK_RANGE := 220.0
const MAX_LEVEL := 5
const MAX_ATTACKS_PER_CYCLE := 3

## Formación en V aplanada detrás del player, en espacio local
## (x = hacia atrás, y = lateral). Índice 0 = punta, más cerca del
## player; los demás se abren hacia los costados y un poco más atrás.
const SLOT_OFFSETS: Array = [
	Vector2(14, 0),
	Vector2(19, 16), Vector2(19, -16),
	Vector2(24, 30), Vector2(24, -30),
]
const FORMATION_LERP := 10.0   # qué tan rápido "alcanzan" su lugar en la V

var player = null   # sin tipo: ver nota en player.gd sobre set_script
## Evolución "Tormenta de espadas": en vez de la V, las espadas giran
## en círculo alrededor del player y cortan lo que tocan al pasar.
const ORBIT_RADIUS := 58.0
const ORBIT_SPEED := 2.6
var _orbit: bool = false
var _orbit_angle: float = 0.0
var _slots: Array = []          # cada elemento: blade o null
var _regen_timers: Array = []
var _attack_cd: float = 0.6
var _facing := Vector2(0.0, 1.0)   # hacia dónde mira el player — las espadas van del lado opuesto

func setup(p) -> void:
	player = p
	_slots.resize(MAX_SWORDS)
	_regen_timers.resize(MAX_SWORDS)
	for i in range(MAX_SWORDS):
		_regen_timers[i] = 0.0
		_spawn_blade(i)

## Nivel de la carta (1..MAX_LEVEL) — sube el daño y el color de las
## espadas (ver LEVEL_CORE en flying_sword.gd), hasta un aura
## arcoíris en el nivel máximo. Se aplica también a las que se
## regeneren después (ver _spawn_blade).
var level: int = 1
var _damage_mult: float = 1.0
## Camino "más cantidad" — cuántas espadas disponibles atacan juntas
## en cada ciclo en vez de una sola (ver _try_attack).
var attacks_per_cycle: int = 1

func buff() -> void:
	level = min(MAX_LEVEL, level + 1)
	_damage_mult = 1.0 + (level - 1) * 0.25
	for blade in _slots:
		if blade != null and is_instance_valid(blade):
			blade.damage = SWORD_DAMAGE * _damage_mult
			blade.set_level(level)

func buff_count() -> void:
	attacks_per_cycle = min(MAX_ATTACKS_PER_CYCLE, attacks_per_cycle + 1)

func evolve() -> void:
	_orbit = true
	for blade in _slots:
		if blade != null and is_instance_valid(blade):
			blade.set_orbit(true)

func _spawn_blade(i: int) -> void:
	var blade = Area2D.new()
	blade.set_script(BLADE_SCRIPT)
	blade.collision_layer = 0
	blade.collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	blade.add_child(shape)
	get_tree().current_scene.add_child(blade)
	blade.damage = SWORD_DAMAGE * _damage_mult
	blade.set_level(level)
	blade.consumed.connect(_on_blade_consumed.bind(i))
	blade.global_position = player.global_position + SLOT_OFFSETS[i].rotated(_facing.angle() + PI)
	if _orbit:
		blade.set_orbit(true)
	_slots[i] = blade

func _on_blade_consumed(i: int) -> void:
	_slots[i] = null
	_regen_timers[i] = REGEN_TIME

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	if player.velocity.length() > 5.0:
		_facing = player.velocity.normalized()
	var behind_angle := _facing.angle() + PI
	_orbit_angle += ORBIT_SPEED * delta

	for i in range(MAX_SWORDS):
		var blade = _slots[i]
		if blade != null and is_instance_valid(blade):
			if blade.state == BLADE_SCRIPT.State.FORMATION:
				if _orbit:
					var a: float = _orbit_angle + TAU * i / MAX_SWORDS
					var target_o: Vector2 = player.global_position + Vector2(cos(a), sin(a)) * ORBIT_RADIUS
					blade.global_position = blade.global_position.lerp(target_o, FORMATION_LERP * 2.0 * delta)
					# Tangente al círculo: la hoja "corta" en el sentido del giro
					# (el sprite apunta a rotation - PI en formación, ver
					# SWORD_ROT_OFFSET en flying_sword.gd).
					blade.rotation = a + PI * 1.5
				else:
					var target: Vector2 = player.global_position + SLOT_OFFSETS[i].rotated(behind_angle)
					blade.global_position = blade.global_position.lerp(target, FORMATION_LERP * delta)
					blade.rotation = behind_angle
		else:
			_regen_timers[i] -= delta * (2.0 if _orbit else 1.0)
			if _regen_timers[i] <= 0.0:
				_spawn_blade(i)

	_attack_cd -= delta
	if _attack_cd <= 0.0:
		_try_attack()

## Lanza hasta attacks_per_cycle espadas disponibles (carta "más
## cantidad") — cada una va teledirigida a un blanco distinto cuando
## se puede, en vez de que todas vayan al mismo bicho.
func _try_attack() -> void:
	var available: Array = []
	for i in range(MAX_SWORDS):
		var blade = _slots[i]
		if blade != null and is_instance_valid(blade) and blade.state == BLADE_SCRIPT.State.FORMATION:
			available.append(blade)
	if available.is_empty():
		_attack_cd = RETRY_INTERVAL
		return

	available.shuffle()
	var monsters := get_tree().get_nodes_in_group("monster")
	var used_targets: Array = []
	var launched := 0

	for blade in available:
		if launched >= attacks_per_cycle:
			break
		var best: Node2D = null
		var best_d2 := ATTACK_RANGE * ATTACK_RANGE
		for m in monsters:
			if not is_instance_valid(m) or m in used_targets: continue
			var d2: float = blade.global_position.distance_squared_to(m.global_position)
			if d2 < best_d2:
				best_d2 = d2
				best = m
		if best:
			# Nodo, no posición — la espada queda teledirigida y
			# persigue al blanco si se mueve, no un punto fijo.
			blade.launch_at(best)
			used_targets.append(best)
			launched += 1

	_attack_cd = ATTACK_INTERVAL if launched > 0 else RETRY_INTERVAL

func _exit_tree() -> void:
	for blade in _slots:
		if blade != null and is_instance_valid(blade):
			blade.queue_free()
