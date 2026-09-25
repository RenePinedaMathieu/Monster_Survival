extends Area2D

## Premio que suelta un barril roto (breakable.gd). Flota y se agarra
## al tocarlo:
##   heal    recupera 25% de la vida
##   magnet  atrae TODA la experiencia del mapa
##   bomb    revienta a los monstruos comunes cercanos
##   coins   +15 monedas

const ICONS: Dictionary = {
	"heal": "res://assets/ui/rpg/heart.png",
	"magnet": "res://assets/ui/rpg/magnet.png",
	"bomb": "res://assets/ui/skill_icons/skill_98.png",
	"coins": "res://assets/ui/rpg/coin.png",
}
const TINTS: Dictionary = {
	"heal": Color(1.8, 0.5, 0.5),
	"magnet": Color(1.4, 1.4, 1.6),
	"bomb": Color(1, 1, 1),
	"coins": Color(1, 1, 1),
}
const BOMB_RADIUS := 300.0
const LIFE := 30.0
const FLOAT_TEXT := preload("res://scenes/damage_number.gd")

## Al agarrarlo sale un texto que dice qué fue (antes no se sabía si
## había sido vida o la bomba).
const LABELS: Dictionary = {
	"heal": ["+%d VIDA", Color("6ee06e")],
	"magnet": ["¡IMÁN!", Color("9fd8ff")],
	"bomb": ["¡BOMBA!", Color("ff8a2e")],
	"coins": ["+15 MONEDAS", Color("ffd24a")],
}

var kind: String = "heal"
var _t: float = 0.0
var _sprite: Sprite2D
var _taken: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1   # el player
	monitorable = false
	z_index = 3
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = load(ICONS[kind])
	_sprite.modulate = TINTS[kind]
	var tex_size: float = _sprite.texture.get_width()
	# Los íconos del pack son de 16 px; la bomba es una ilustración grande.
	_sprite.scale = Vector2.ONE * (18.0 / tex_size)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if tex_size > 32.0 else CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_t += delta
	_sprite.position.y = -4.0 + sin(_t * 4.0) * 2.5
	if _t > LIFE - 3.0:
		visible = int(_t * 8.0) % 2 == 0   # parpadea antes de desaparecer
	if _t > LIFE:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	_apply.call_deferred(body)

func _apply(player: Node) -> void:
	var text: String = LABELS[kind][0]
	match kind:
		"heal":
			var amount: float = player.max_hp * 0.25
			player.heal(amount)
			player.flash(player.FLASH_GREEN)
			text = text % int(round(amount))
			Audio.play_sfx("level_up", global_position)
		"magnet":
			for orb in get_tree().get_nodes_in_group("xp_orb"):
				if is_instance_valid(orb) and orb.has_method("start_magnet"):
					orb.start_magnet(player)
			Audio.play_sfx("xp_pickup", global_position)
		"bomb":
			for m in get_tree().get_nodes_in_group("monster"):
				if is_instance_valid(m) and global_position.distance_to(m.global_position) <= BOMB_RADIUS:
					# A jefes y élites les pega fuerte, pero no los borra.
					var big: bool = m.is_boss() or m.is_elite
					m.take_damage(60.0 if big else 9999.0, "bomba")
			if player.has_method("shake"):
				player.shake(9.0)
			_spawn_blast()
			Audio.play_sfx("meteor_impact", global_position)
		"coins":
			GameState.add_run_currency(15)
			player.flash(player.FLASH_GOLD)
			Audio.play_sfx("coin_pickup", global_position)
	FLOAT_TEXT.spawn_text(FLOAT_TEXT, get_tree().current_scene, player.global_position, text, LABELS[kind][1])
	queue_free()

## Onda naranja que se expande hasta el radio de la bomba: muestra que
## explotó y hasta dónde llegó.
func _spawn_blast() -> void:
	var ring := Node2D.new()
	ring.z_index = 40
	ring.global_position = global_position
	ring.draw.connect(func():
		ring.draw_circle(Vector2.ZERO, BOMB_RADIUS, Color(1.0, 0.55, 0.15, 0.22))
		ring.draw_arc(Vector2.ZERO, BOMB_RADIUS, 0.0, TAU, 72, Color(1.0, 0.75, 0.3, 0.9), 10.0))
	get_parent().add_child(ring)
	ring.scale = Vector2.ONE * 0.1
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.45)
	tw.tween_callback(ring.queue_free)
