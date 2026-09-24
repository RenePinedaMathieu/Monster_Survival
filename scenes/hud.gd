extends CanvasLayer

## HUD in-game con las piezas del pack de UI (rpg_theme.gd):
##   - Panel de personaje (arriba izq.): retrato del héroe en el círculo,
##     placa verde con el nivel y 3 barras — roja = vida, azul = defensa
##     (armadura de la tienda), verde = experiencia.
##   - Tablón de madera con oleada / enemigos / monedas de la run.
##   - Timer centrado arriba y barra del jefe debajo.
##   - Minimapa enmarcado en madera (arriba der.).
##   - Barra de mejoras activas abajo al centro: una casilla por arma y
##     por pasiva de la build (player.build_summary()) con su nivel; las
##     armas evolucionadas muestran el ícono de la evolución y "EVO".
##   - Banner central "OLEADA SUPERADA" con fade.

const UITheme := preload("res://scenes/ui_theme.gd")
const RpgTheme := preload("res://scenes/rpg_theme.gd")

const CHAR_PANEL_TEXTURE := "res://assets/ui/rpg/char_panel.png"
const ACTION_SLOT_TEXTURE := "res://assets/ui/rpg/action_slot.png"
const COIN_TEXTURE := "res://assets/ui/rpg/coin.png"

## Colores reales de las barras llenas del pack (claro arriba, oscuro abajo).
const BAR_HP := [Color("d74427"), Color("b82b28")]
const BAR_DEFENSE := [Color("37a0df"), Color("3583c4")]
const BAR_XP := [Color("44a13b"), Color("368040")]
const COLOR_BOSS := Color("d74427")

## Fondo del círculo del retrato — el mismo azul de los retratos del pack.
const PORTRAIT_BG := Color("7f95dc")
const PORTRAIT_SIZE := 67

const COLOR_EVOLVED := Color("ffd24a")

@onready var _portrait: TextureRect = $CharPanel/Portrait
@onready var _hp_bar: ProgressBar = $CharPanel/HPBar
@onready var _defense_bar: ProgressBar = $CharPanel/DefenseBar
@onready var _xp_bar: ProgressBar = $CharPanel/XPBar
@onready var _level_badge: PanelContainer = $CharPanel/LevelBadge
@onready var _level_number: Label = $CharPanel/LevelBadge/LevelNumber
@onready var _hp_value_label: Label = $HPValue
@onready var _wave_label: Label = $InfoPanel/VBox/WaveLabel
@onready var _monsters_label: Label = $InfoPanel/VBox/MonstersLabel
@onready var _coins_label: Label = $InfoPanel/VBox/CoinsRow/CoinsLabel
@onready var _timer_label: Label = $TimerPanel/TimerLabel
@onready var _banner: Label = $BreakBanner
@onready var _boss_panel: PanelContainer = $BossPanel
@onready var _boss_label: Label = $BossPanel/VBox/BossLabel
@onready var _boss_bar: ProgressBar = $BossPanel/VBox/BossBar
@onready var _upgrades_bar: PanelContainer = $UpgradesArea/UpgradesBar
@onready var _upgrade_rows: VBoxContainer = $UpgradesArea/UpgradesBar/Rows

var _run_time: float = 0.0
var _running: bool = true
var _action_slot: Texture2D

func _ready() -> void:
	$CharPanel/Frame.texture = load(CHAR_PANEL_TEXTURE)
	$InfoPanel/VBox/CoinsRow/CoinIcon.texture = load(COIN_TEXTURE)
	_action_slot = load(ACTION_SLOT_TEXTURE)

	RpgTheme.style_track_bar(_hp_bar, BAR_HP[0], BAR_HP[1])
	RpgTheme.style_track_bar(_defense_bar, BAR_DEFENSE[0], BAR_DEFENSE[1])
	RpgTheme.style_track_bar(_xp_bar, BAR_XP[0], BAR_XP[1])
	RpgTheme.style_level_bar(_boss_bar, COLOR_BOSS)
	_defense_bar.value = 0.0

	_level_badge.add_theme_stylebox_override("panel", RpgTheme.badge_box())
	_level_number.add_theme_font_size_override("font_size", 14)
	_level_number.add_theme_color_override("font_color", RpgTheme.COLOR_BTN_TEXT)
	_level_number.add_theme_font_override("font", UITheme.make_bold_font(0.6))

	for panel in [$InfoPanel, $TimerPanel, _boss_panel]:
		panel.add_theme_stylebox_override("panel", RpgTheme.wood_box())
	$MinimapFrame.add_theme_stylebox_override("panel", RpgTheme.wood_box(9.0, 9.0))
	_upgrades_bar.add_theme_stylebox_override("panel", RpgTheme.wood_box(9.0, 6.0))

	RpgTheme.style_light_label(_hp_value_label, 15)
	RpgTheme.style_light_label(_wave_label, 18)
	RpgTheme.style_light_label(_monsters_label, 14)
	RpgTheme.style_light_label(_coins_label, 14)
	RpgTheme.style_light_label(_timer_label, 26)
	RpgTheme.style_light_label(_boss_label, 16)
	RpgTheme.style_light_label(_banner, 44)

	_coins_label.text = "%d" % GameState.run_currency
	GameState.currency_changed.connect(_on_currency_changed)
	Screen.layout_changed.connect(_apply_layout)
	_apply_layout(Screen.compact)

## Teléfono vertical: el panel de personaje y el minimapa ocupan todo el
## ancho de arriba, así que el timer baja debajo del minimapa y la
## barra del jefe debajo de todo eso, a lo ancho de la pantalla.
func _apply_layout(compact: bool) -> void:
	var vp := Screen.view_size()
	# Minimapa más chico en vertical: el panel de personaje ya ocupa 264
	# de los 420 de ancho.
	var map_side: float = 110.0 if compact else 150.0
	$MinimapFrame/Minimap.set_side(map_side)
	$MinimapFrame.offset_left = -(map_side + 18.0 + 12.0)
	$MinimapFrame.offset_bottom = 12.0 + map_side + 18.0
	var timer: PanelContainer = $TimerPanel
	if compact:
		timer.anchor_left = 1.0
		timer.anchor_right = 1.0
		timer.offset_left = -(map_side + 18.0 + 12.0)
		timer.offset_right = -12.0
		timer.offset_top = map_side + 38.0
		timer.offset_bottom = map_side + 88.0
	else:
		timer.anchor_left = 0.5
		timer.anchor_right = 0.5
		timer.offset_left = -70.0
		timer.offset_right = 70.0
		timer.offset_top = 12.0
		timer.offset_bottom = 62.0
	var boss_w: float = minf(440.0, vp.x - 24.0)
	_boss_panel.offset_left = -boss_w / 2.0
	_boss_panel.offset_right = boss_w / 2.0
	_boss_panel.offset_top = 218.0 if compact else 72.0
	_boss_panel.offset_bottom = _boss_panel.offset_top + 60.0
	_rebuild_upgrade_rows()

func _process(delta: float) -> void:
	if not _running: return
	_run_time += delta
	var mins := int(_run_time) / 60
	var secs := int(_run_time) % 60
	_timer_label.text = "%02d:%02d" % [mins, secs]

# ── Panel de personaje ───────────────────────────────────────────

func on_hp_changed(current: float, max_hp: float) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = current
	_hp_value_label.text = "%d / %d" % [int(round(current)), int(round(max_hp))]

func on_xp_changed(current: int, needed: int, level: int) -> void:
	_xp_bar.max_value = needed
	_xp_bar.value = current
	_level_number.text = "NV %d" % level

## Sin armadura comprada max_defense es 0: la pista azul queda vacía.
func on_defense_changed(current: float, max_defense: float) -> void:
	_defense_bar.max_value = max(max_defense, 1.0)
	_defense_bar.value = current if max_defense > 0.0 else 0.0

## Retrato circular armado a partir de un frame del sprite del héroe:
## recorte cuadrado de cabeza y torso, escalado sin suavizar, sobre el
## fondo azul del pack y recortado en círculo (el aro de madera de
## char_panel.png tapa el borde).
func set_portrait(tex: Texture2D) -> void:
	if tex == null:
		return
	var src := tex.get_image()
	if src == null or src.is_empty():
		return
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var used := src.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return

	var side: int = mini(maxi(used.size.x, int(used.size.y * 0.6)), maxi(used.size.x, used.size.y))
	var cx: int = used.position.x + int(used.size.x / 2.0)
	var region := Rect2i(cx - int(side / 2.0), used.position.y - 1, side, side)
	var clipped := region.intersection(Rect2i(Vector2i.ZERO, src.get_size()))
	var crop := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	crop.blit_rect(src, clipped, clipped.position - region.position)
	crop.resize(PORTRAIT_SIZE, PORTRAIT_SIZE, Image.INTERPOLATE_NEAREST)

	var out := Image.create_empty(PORTRAIT_SIZE, PORTRAIT_SIZE, false, Image.FORMAT_RGBA8)
	out.fill(PORTRAIT_BG)
	out.blend_rect(crop, Rect2i(0, 0, PORTRAIT_SIZE, PORTRAIT_SIZE), Vector2i.ZERO)
	var c := (PORTRAIT_SIZE - 1) / 2.0
	var r2 := (PORTRAIT_SIZE / 2.0) * (PORTRAIT_SIZE / 2.0)
	for y in range(PORTRAIT_SIZE):
		for x in range(PORTRAIT_SIZE):
			if (x - c) * (x - c) + (y - c) * (y - c) > r2:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
	_portrait.texture = ImageTexture.create_from_image(out)

# ── Barra de mejoras activas ─────────────────────────────────────

## Recibe player.build_summary(): [{icon, level, evolved}, ...] — armas
## primero, después pasivas.
func on_upgrades_changed(summary: Array) -> void:
	_last_summary = summary
	_rebuild_upgrade_rows()

var _last_summary: Array = []

## Reparte las casillas en filas que entren a lo ancho (en un teléfono
## vertical no entran las 11 posibles en una fila).
func _rebuild_upgrade_rows() -> void:
	for child in _upgrade_rows.get_children():
		_upgrade_rows.remove_child(child)
		child.queue_free()
	var per_row: int = maxi(1, floori((Screen.view_size().x - 40.0) / 46.0))
	var row: HBoxContainer = null
	for i in range(_last_summary.size()):
		if i % per_row == 0:
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 4)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_upgrade_rows.add_child(row)
		var entry: Dictionary = _last_summary[i]
		row.add_child(_make_upgrade_tile(entry["icon"], entry["level"], entry["evolved"]))
	_upgrades_bar.visible = not _last_summary.is_empty()

func _make_upgrade_tile(icon_path: String, level: int, evolved: bool) -> Control:
	var tile := TextureRect.new()
	tile.texture = _action_slot
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if icon_path != "" and ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.offset_left = 5.0
		icon.offset_top = 5.0
		icon.offset_right = -5.0
		icon.offset_bottom = -5.0
		tile.add_child(icon)

	if evolved or level > 1:
		var label := Label.new()
		label.text = "EVO" if evolved else str(level)
		RpgTheme.style_light_label(label, 11 if evolved else 12)
		if evolved:
			label.add_theme_color_override("font_color", COLOR_EVOLVED)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.anchor_left = 1.0
		label.anchor_top = 1.0
		label.anchor_right = 1.0
		label.anchor_bottom = 1.0
		label.offset_left = -34.0
		label.offset_top = -20.0
		label.offset_right = 1.0
		label.offset_bottom = 3.0
		tile.add_child(label)
	return tile

# ── Oleadas / moneda ─────────────────────────────────────────────

func _on_currency_changed(amount: int) -> void:
	_coins_label.text = "%d" % amount

func show_boss_bar(max_hp: float) -> void:
	_boss_panel.visible = true
	_boss_bar.max_value = max_hp
	_boss_bar.value = max_hp

func on_boss_hp_changed(current: float, max_hp: float) -> void:
	_boss_bar.max_value = max_hp
	_boss_bar.value = current

func hide_boss_bar() -> void:
	_boss_panel.visible = false

var _wave: int = 0

## final_wave 0 = modo infinito (sin "/ N").
func set_wave(n: int, remaining: int, final_wave: int = 0) -> void:
	_wave = n
	_wave_label.text = ("OLEADA %d / %d" % [n, final_wave]) if final_wave > 0 else ("OLEADA %d" % n)
	_monsters_label.text = "Enemigos: %d" % remaining

func show_wave_break(_duration: float) -> void:
	_banner.text = "OLEADA %d SUPERADA" % _wave
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.3)
	tw.tween_interval(1.2)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.5)

func stop_timer() -> void:
	_running = false

func resume_timer() -> void:
	_running = true

func get_run_time() -> float:
	return _run_time
