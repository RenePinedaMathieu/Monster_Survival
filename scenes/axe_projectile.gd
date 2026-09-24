extends Area2D

## Hacha del arma "Hacha giratoria" (axe_weapon.gd). Dos modos:
##   throw  sale en línea recta, frena a OUT_DISTANCE y vuelve al
##          player; pega una vez a cada enemigo a la ida y otra a la
##          vuelta.
##   orbit  (evolución Torbellino) gira alrededor del player para
##          siempre y le vuelve a pegar a quien siga tocándola cada
##          REHIT_TIME.

const AXE_ICON := "res://assets/ui/weapon_icons/icon_86.png"
const SPEED := 360.0
const OUT_DISTANCE := 170.0
const SPIN := 14.0
const ORBIT_RADIUS := 78.0
const ORBIT_SPEED := 3.2
const REHIT_TIME := 0.45

var _player = null
var _damage: float = 5.0
var _mode: String = "throw"
var _dir: Vector2 = Vector2.RIGHT
var _traveled: float = 0.0
var _returning: bool = false
var _angle: float = 0.0
var _hit_ids: Array = []
var _last_hit: Dictionary = {}   # instance_id -> segundos desde el último golpe
var _sprite: Sprite2D

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load(AXE_ICON)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(0.85, 0.85)
	add_child(_sprite)
	z_index = 5
	body_entered.connect(_on_body_entered)

func start_throw(player, dir: Vector2, damage: float) -> void:
	_player = player
	_mode = "throw"
	_dir = dir
	_damage = damage
	global_position = player.global_position

func start_orbit(player, angle: float, damage: float) -> void:
	_player = player
	_mode = "orbit"
	_angle = angle
	_damage = damage
	_sprite.modulate = Color(1.2, 1.1, 0.8)
	_sprite.scale = Vector2(1.05, 1.05)
	global_position = player.global_position + Vector2(cos(angle), sin(angle)) * ORBIT_RADIUS

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		queue_free()
		return
	_sprite.rotation += SPIN * delta
	if _mode == "orbit":
		_angle += ORBIT_SPEED * delta
		global_position = _player.global_position + Vector2(cos(_angle), sin(_angle)) * ORBIT_RADIUS
		for id in _last_hit.keys():
			_last_hit[id] += delta
			if _last_hit[id] > 5.0:
				_last_hit.erase(id)   # monstruos que ya murieron o se alejaron
		for body in get_overlapping_bodies():
			var bid: int = body.get_instance_id()
			if _last_hit.get(bid, REHIT_TIME) >= REHIT_TIME and body.has_method("take_damage"):
				_last_hit[bid] = 0.0
				body.take_damage(_damage, "torbellino")
		return

	if not _returning:
		var step := SPEED * delta
		global_position += _dir * step
		_traveled += step
		if _traveled >= OUT_DISTANCE:
			_returning = true
			_hit_ids.clear()   # a la vuelta puede volver a pegarle a los mismos
	else:
		var to_player: Vector2 = _player.global_position - global_position
		if to_player.length() < 16.0:
			queue_free()
			return
		global_position += to_player.normalized() * SPEED * 1.1 * delta

func _on_body_entered(body: Node) -> void:
	if _mode != "throw" or not body.has_method("take_damage"):
		return
	var bid := body.get_instance_id()
	if bid in _hit_ids:
		return
	_hit_ids.append(bid)
	body.take_damage(_damage, "hacha")
