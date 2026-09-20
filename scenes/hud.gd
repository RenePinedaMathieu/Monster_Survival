extends CanvasLayer

## HUD estilo Vampire Survivors, con look pixel-art (paneles oscuros
## translúcidos + borde dorado cuadrado, texto con outline — mismo
## lenguaje visual que el menú y la selección de personaje) en vez
## del theme default de Godot:
##   - HP arriba a la izquierda; la barra pasa de verde a rojo según
##     el % de vida restante.
##   - Badge de nivel + barra de XP debajo.
##   - Timer del run centrado arriba.
##   - Panel de wave debajo del XP.
##   - Banner central "OLEADA SUPERADA" con fade.

const UITheme := preload("res://scenes/ui_theme.gd")

const COLOR_XP       := Color("4fc3e0")
const COLOR_HP_LOW   := Color("e0483e")
const COLOR_HP_MID   := Color("e0a94c")
const COLOR_HP_FULL  := Color("6bcf6b")
const COLOR_DEFENSE  := Color("8fb8e0")
const COLOR_BOSS     := Color("c73e6b")

@onready var _hp_value_label: Label = $HPPanel/Margin/VBox/Row/Value
@onready var _hp_caption_label: Label = $HPPanel/Margin/VBox/Row/Caption
@onready var _hp_bar: ProgressBar = $HPPanel/Margin/VBox/HPBar
@onready var _defense_bar: ProgressBar = $HPPanel/Margin/VBox/DefenseBar
@onready var _level_badge: PanelContainer = $LevelPanel/Margin2/HBox2/LevelBadge
@onready var _level_number: Label = $LevelPanel/Margin2/HBox2/LevelBadge/LevelNumber
@onready var _xp_caption_label: Label = $LevelPanel/Margin2/HBox2/XPCol/XPCaption
@onready var _xp_bar: ProgressBar = $LevelPanel/Margin2/HBox2/XPCol/XPBar
@onready var _wave_label: Label = $WavePanel/Margin4/VBox3/WaveLabel
@onready var _monsters_label: Label = $WavePanel/Margin4/VBox3/MonstersLabel
@onready var _coins_label: Label = $WavePanel/Margin4/VBox3/CoinsLabel
@onready var _timer_label: Label = $TimerPanel/Margin3/TimerLabel
@onready var _banner: Label = $BreakBanner
@onready var _boss_panel: PanelContainer = $BossPanel
@onready var _boss_label: Label = $BossPanel/Margin5/VBox4/BossLabel
@onready var _boss_bar: ProgressBar = $BossPanel/Margin5/VBox4/BossBar

var _hp_fill_style: StyleBoxFlat
var _hp_gradient := Gradient.new()

var _run_time: float = 0.0
var _running: bool = true

func _ready() -> void:
	_hp_gradient.colors = PackedColorArray([COLOR_HP_LOW, COLOR_HP_MID, COLOR_HP_FULL])
	_hp_gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])

	for panel in [$HPPanel, $TimerPanel, $LevelPanel, $WavePanel, _boss_panel]:
		panel.add_theme_stylebox_override("panel", UITheme.make_panel_box())
	_level_badge.add_theme_stylebox_override("panel", UITheme.make_box(UITheme.COLOR_FILL, UITheme.COLOR_BORDER))

	_hp_fill_style = UITheme.style_progress_bar(_hp_bar, COLOR_HP_FULL)
	UITheme.style_progress_bar(_xp_bar, COLOR_XP)
	UITheme.style_progress_bar(_defense_bar, COLOR_DEFENSE)
	UITheme.style_progress_bar(_boss_bar, COLOR_BOSS)

	UITheme.style_label(_hp_caption_label, 15)
	UITheme.style_label(_hp_value_label, 15, true)
	UITheme.style_label(_level_number, 22, true)
	UITheme.style_label(_xp_caption_label, 12)
	UITheme.style_label(_wave_label, 18, true)
	UITheme.style_label(_monsters_label, 15)
	UITheme.style_label(_coins_label, 15)
	UITheme.style_label(_timer_label, 28, true)
	UITheme.style_label(_banner, 44, true)
	UITheme.style_label(_boss_label, 16, true)
	_hp_caption_label.modulate.a = 0.8
	_xp_caption_label.modulate.a = 0.8

	_coins_label.text = "Monedas: %d" % GameState.run_currency
	GameState.currency_changed.connect(_on_currency_changed)

func _process(delta: float) -> void:
	if not _running: return
	_run_time += delta
	var mins := int(_run_time) / 60
	var secs := int(_run_time) % 60
	_timer_label.text = "%02d:%02d" % [mins, secs]

func on_hp_changed(current: float, max_hp: float) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = current
	_hp_value_label.text = "%d / %d" % [int(round(current)), int(round(max_hp))]
	var ratio: float = clamp(current / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0
	_hp_fill_style.bg_color = _hp_gradient.sample(ratio)

func on_xp_changed(current: int, needed: int, level: int) -> void:
	_xp_bar.max_value = needed
	_xp_bar.value = current
	_level_number.text = str(level)

## La barra de defensa (armadura comprada en la tienda) sólo se
## muestra si el player realmente tiene puntos de defensa — sin
## compras, max_defense es 0 y esto queda oculto como antes.
func on_defense_changed(current: float, max_defense: float) -> void:
	_defense_bar.visible = max_defense > 0.0
	if max_defense > 0.0:
		_defense_bar.max_value = max_defense
		_defense_bar.value = current

func _on_currency_changed(amount: int) -> void:
	_coins_label.text = "Monedas: %d" % amount

# ── Boss ──────────────────────────────────────────────────────────

func show_boss_bar(max_hp: float) -> void:
	_boss_panel.visible = true
	_boss_bar.max_value = max_hp
	_boss_bar.value = max_hp

func on_boss_hp_changed(current: float, max_hp: float) -> void:
	_boss_bar.max_value = max_hp
	_boss_bar.value = current

func hide_boss_bar() -> void:
	_boss_panel.visible = false

func set_wave(n: int, remaining: int) -> void:
	_wave_label.text = "OLEADA %d" % n
	_monsters_label.text = "Enemigos: %d" % remaining

func show_wave_break(_duration: float) -> void:
	_banner.text = "OLEADA %d SUPERADA" % int(_wave_label.text.trim_prefix("OLEADA "))
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.3)
	tw.tween_interval(1.2)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.5)

func stop_timer() -> void:
	_running = false

func get_run_time() -> float:
	return _run_time
