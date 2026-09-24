extends Area2D

## Cofre que sueltan élites y jefes (monster.gd). Flota con un brillo
## dorado; cuando el player lo toca abre chest_popup (que decide la
## recompensa: una evolución si hay alguna lista, si no una mejora).

const CHEST_TEXTURE := "res://assets/ui/rpg/chest.png"
const POPUP_SCENE := "res://scenes/chest_popup.tscn"
const GLOW := Color(1.0, 0.85, 0.35)

var _t: float = 0.0
var _sprite: Sprite2D
var _opened: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1   # el player
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = load(CHEST_TEXTURE)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(1.6, 1.6)
	_sprite.modulate = Color(1.35, 1.1, 0.7)
	add_child(_sprite)
	z_index = 3
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_t += delta
	_sprite.position.y = -4.0 + sin(_t * 3.0) * 3.0
	queue_redraw()

func _draw() -> void:
	var a: float = 0.25 + 0.15 * sin(_t * 4.0)
	draw_circle(Vector2(0, 2), 16.0, Color(GLOW, a * 0.5))
	draw_arc(Vector2(0, 2), 18.0 + sin(_t * 4.0) * 2.0, 0.0, TAU, 24, Color(GLOW, a + 0.2), 1.5, false)

func _on_body_entered(body: Node) -> void:
	if _opened or not body.is_in_group("player"):
		return
	_opened = true
	# Diferido: estamos dentro del callback de física, y la recompensa
	# puede crear armas con Area2D (hachas) — agregarlas en pleno flush
	# de colisiones tira "Can't change this state while flushing queries".
	_open.call_deferred(body)

func _open(player: Node) -> void:
	Audio.play_sfx("level_up")
	var popup = load(POPUP_SCENE).instantiate()
	get_tree().current_scene.add_child(popup)
	popup.open(player)
	queue_free()
