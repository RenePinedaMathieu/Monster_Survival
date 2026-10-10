extends Node2D

## Escudo de fuerza: cargado para un disparo (Bastión: 3 cargas y también
## golpes cuerpo a cuerpo). Cargado se ve el aro de inmunidad del pack
## Magic Buff a los pies (buff_fx.gd, antes un círculo celeste dibujado);
## al parar un golpe salta el escudo del mismo efecto.

const LEVELS: Array = [
	{"cooldown": 9.0},
	{"cooldown": 8.0},
	{"cooldown": 7.0},
	{"cooldown": 6.0},
	{"cooldown": 5.0},
]
## Cuadro del efecto de inmunidad en que queda mientras está cargado
## (el último: sólo el aro).
const READY_FRAME := 15
## Evolución "Bastión" (escudo + Piel de hierro): 3 cargas, se recargan
## el doble de rápido y también paran golpes cuerpo a cuerpo.
const BASTION_CHARGES := 3

var player = null
var level: int = 1
var active: bool = false
var evolved: bool = false
var charges: int = 0
var _cd: float = 0.0
var _ring = null   # buff_fx.gd mientras está cargado

func setup(p) -> void:
	player = p
	active = true
	charges = 1
	_show_ring()

func set_level(l: int) -> void:
	level = clampi(l, 1, LEVELS.size())
	_cd = minf(_cd, LEVELS[level - 1]["cooldown"])

func evolve() -> void:
	evolved = true
	charges = BASTION_CHARGES
	active = true
	_show_ring()

func _max_charges() -> int:
	return BASTION_CHARGES if evolved else 1

func _recharge_time() -> float:
	return LEVELS[level - 1]["cooldown"] * player.cooldown_mult * (0.5 if evolved else 1.0)

func block_projectile(_from_pos: Vector2) -> bool:
	if not active:
		return false
	charges -= 1
	active = charges > 0
	if _cd <= 0.0:
		_cd = _recharge_time()
	# Paró el golpe: el escudo del efecto, rápido.
	player.play_buff("immunity", 24.0)
	if not active:
		_hide_ring()
	return true

## Bastión: también para un golpe cuerpo a cuerpo (player.take_damage).
func absorb_hit() -> bool:
	return evolved and block_projectile(global_position)

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.hp <= 0.0:
		return
	if charges < _max_charges():
		_cd -= delta
		if _cd <= 0.0:
			charges += 1
			active = true
			_show_ring()
			if charges < _max_charges():
				_cd = _recharge_time()

## Cargado: el efecto completo una vez y después queda el aro.
func _show_ring() -> void:
	if _ring != null and is_instance_valid(_ring):
		return
	_ring = player.play_buff("immunity", 16.0, READY_FRAME)

func _hide_ring() -> void:
	if _ring != null and is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null

func _exit_tree() -> void:
	_hide_ring()
