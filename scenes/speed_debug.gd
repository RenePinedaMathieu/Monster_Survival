extends CanvasLayer

## Detector de lentitud (lo agrega main.gd). Mide cuánto avanza de verdad
## el héroe contra lo que debería avanzar con la dirección apretada y, si
## va a menos de SLOW_FRAC durante WINDOW segundos, anota dónde y con qué
## estaba chocando. F3 (o L) lo muestra; F4 (o C) copia las anotaciones
## para pegarlas en el chat. Escondido no molesta: sólo mide.

const SLOW_FRAC := 0.75
const WINDOW := 0.25
const RAMP_TIME := 0.2        # lo que tarda en llegar a velocidad (aceleración)
const MAX_EVENTS := 30

var player = null
var world = null

var _panel: PanelContainer
var _label: Label
var _events: Array = []
var _last_pos := Vector2.ZERO
var _moving_t := 0.0
var _win_t := 0.0
var _win_dist := 0.0
var _win_expect := 0.0
var _win_real_us := 0
var _win_hits := {}
var _last_ratio := 1.0
var _cooldown := 0.0
var _copied_t := 0.0

func _ready() -> void:
	layer = 40
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.72)
	sb.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.anchor_left = 0.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 12
	_panel.offset_bottom = -12
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_panel.add_child(_label)
	visible = false
	if player != null:
		_last_pos = player.global_position

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	if k == KEY_F3 or k == KEY_L:
		visible = not visible
		get_viewport().set_input_as_handled()
	elif k == KEY_F4 or k == KEY_C:
		DisplayServer.clipboard_set(report())
		_copied_t = 2.0
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var pos: Vector2 = player.global_position
	var step: float = pos.distance_to(_last_pos)
	_last_pos = pos
	_cooldown = maxf(0.0, _cooldown - delta)
	var input: Vector2 = player._keyboard_input()
	if input == Vector2.ZERO:
		input = player._touch_input
	# Sólo cuenta caminando normal: sin dash, remolino ni muerte (esos
	# mueven al héroe distinto) y ya con la velocidad alcanzada.
	var normal_walk: bool = input != Vector2.ZERO and player.hp > 0.0 \
		and player._dash_t <= 0.0 and player._whirl_t <= 0.0
	if not normal_walk:
		_moving_t = 0.0
		_reset_window()
		return
	_moving_t += delta
	if _moving_t < RAMP_TIME:
		_reset_window()
		return
	for i in range(player.get_slide_collision_count()):
		_win_hits[_collider_name(player.get_slide_collision(i))] = true
	_win_t += delta
	_win_dist += step
	_win_expect += player.move_speed * delta
	if _win_real_us == 0:
		_win_real_us = Time.get_ticks_usec()
	if _win_t >= WINDOW:
		_last_ratio = _win_dist / maxf(0.001, _win_expect)
		if _last_ratio < SLOW_FRAC and _cooldown <= 0.0:
			_add_event(pos)
			_cooldown = 1.0
		_reset_window()

func _reset_window() -> void:
	_win_t = 0.0
	_win_dist = 0.0
	_win_expect = 0.0
	_win_real_us = 0
	_win_hits.clear()

func _collider_name(col: KinematicCollision2D) -> String:
	var c = col.get_collider()
	if c is TileMap:
		var tm: TileMap = c
		var cell: Vector2i = tm.local_to_map(tm.to_local(col.get_position() - col.get_normal() * 2.0))
		return "tile %s" % str(tm.get_cell_atlas_coords(0, cell))
	if c == null:
		return "?"
	return "%s %s" % [c.get_class(), c.name]

func _tile_under(pos: Vector2) -> String:
	if world == null or not ("_tilemap" in world) or world._tilemap == null:
		return "-"
	var tm: TileMap = world._tilemap
	return str(tm.get_cell_atlas_coords(0, tm.local_to_map(tm.to_local(pos))))

func _add_event(pos: Vector2) -> void:
	var causes: Array = []
	if player._mud_zones > 0:
		causes.append("barro")
	if player.in_sandstorm:
		causes.append("tormenta")
	for k in _win_hits:
		causes.append("choque " + k)
	if causes.is_empty():
		causes.append("SIN CHOQUE")
	var real_s: float = (Time.get_ticks_usec() - _win_real_us) / 1000000.0
	var hud = get_parent().get_node_or_null("HUD")
	var t: float = hud.get_run_time() if hud != null and hud.has_method("get_run_time") else 0.0
	var near := 0
	for m in get_tree().get_nodes_in_group("monster"):
		if is_instance_valid(m) and m.global_position.distance_to(pos) < 40.0:
			near += 1
	_events.append("%02d:%02d  %d %%  en (%d, %d) tile %s  · %s · FPS %d · vel %d · escala tiempo %.2f · monstruos cerca %d · reloj real %.2f s" % [
		int(t) / 60, int(t) % 60, roundi(_last_ratio * 100.0), roundi(pos.x), roundi(pos.y), _tile_under(pos),
		", ".join(causes), Engine.get_frames_per_second(), roundi(player.move_speed), Engine.time_scale, near, real_s])
	if _events.size() > MAX_EVENTS:
		_events.pop_front()

func report() -> String:
	var mapa: String = GameState.selected_map if "selected_map" in GameState else "?"
	var head := "Detector de lentitud · mapa %s · héroe %s · %s" % [mapa, GameState.selected_character_id, OS.get_name()]
	return head + "\n" + "\n".join(_events)

func _process(delta: float) -> void:
	if not visible or player == null or not is_instance_valid(player):
		return
	_copied_t = maxf(0.0, _copied_t - delta)
	var lines: Array = []
	lines.append("DETECTOR DE LENTITUD (F3 ocultar · F4 copiar)%s" % ("  ¡COPIADO!" if _copied_t > 0.0 else ""))
	lines.append("Velocidad: %d %% · FPS %d · tile %s · barro %s · tormenta %s" % [
		roundi(_last_ratio * 100.0), Engine.get_frames_per_second(), _tile_under(player.global_position),
		"sí" if player._mud_zones > 0 else "no", "sí" if player.in_sandstorm else "no"])
	lines.append("Frenazos anotados: %d" % _events.size())
	for e in _events.slice(maxi(0, _events.size() - 5)):
		lines.append("· " + e)
	_label.text = "\n".join(lines)
