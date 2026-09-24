extends Area2D

## Barril repartido por el mapa (painted_world.gd). Se rompe al pasar
## por encima y suelta un premio (pickup.gd): curación, imán, bomba o
## monedas. Le da al jugador un motivo para moverse por el mapa y no
## sólo girar en círculos.

signal broken

const PICKUP_SCRIPT := preload("res://scenes/pickup.gd")
const TEXTURE := "res://assets/ui/rpg/barrel.png"
## Probabilidad acumulada de cada premio.
const DROPS: Array = [["heal", 0.40], ["coins", 0.65], ["magnet", 0.85], ["bomb", 1.0]]

var _broken: bool = false
var _debris: Array = []   # [{pos, vel, age}]
var _sprite: Sprite2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1   # el player
	monitorable = false
	z_index = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = load(TEXTURE)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(1.7, 1.7)
	_sprite.position = Vector2(0, -6)
	add_child(_sprite)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _broken or not body.is_in_group("player"):
		return
	_broken = true
	_sprite.visible = false
	Audio.play_sfx("monster_hit", global_position)
	for i in range(8):
		var a := randf() * TAU
		_debris.append({"pos": Vector2(0, -6), "vel": Vector2(cos(a), sin(a) - 0.8) * randf_range(40.0, 90.0), "age": 0.0})
	_spawn_pickup.call_deferred()
	broken.emit()

func _spawn_pickup() -> void:
	var roll := randf()
	var kind: String = "heal"
	for d in DROPS:
		if roll <= d[1]:
			kind = d[0]
			break
	var pickup := Area2D.new()
	pickup.set_script(PICKUP_SCRIPT)
	pickup.kind = kind
	pickup.position = global_position
	get_parent().add_child(pickup)

func _process(delta: float) -> void:
	if not _broken:
		return
	for d in _debris:
		d["age"] += delta
		d["vel"].y += 260.0 * delta
		d["pos"] += d["vel"] * delta
	queue_redraw()
	if not _debris.is_empty() and _debris[0]["age"] > 0.6:
		queue_free()

func _draw() -> void:
	for d in _debris:
		var a: float = 1.0 - d["age"] / 0.6
		draw_rect(Rect2(d["pos"] - Vector2(2, 2), Vector2(4, 4)), Color(0.55, 0.36, 0.2, a))
