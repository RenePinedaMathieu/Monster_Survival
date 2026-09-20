extends CanvasLayer

## Menú de pausa (ESC durante la partida). Tres vistas dentro del
## mismo panel: los 4 botones principales, la lista de "Potenciadores"
## (qué cartas se fueron eligiendo + stats actuales del player), y
## "Opciones" (mismo volumen/pantalla-completa que el menú principal).
##
## Uso (desde main.gd):
##   var p = PAUSE_MENU_SCENE.instantiate()
##   add_child(p)
##   p.setup(_player)
##   get_tree().paused = true

const UITheme := preload("res://scenes/ui_theme.gd")
const LEVEL_UP_MENU := preload("res://scenes/level_up_menu.gd")
const MENU_SCENE := "res://scenes/main_menu.tscn"

## Etiquetas legibles para el historial de "Potenciadores" — se
## reusan los títulos ya definidos en level_up_menu.gd en vez de
## mantener una segunda copia del texto de cada carta.
var _upgrade_titles: Dictionary = {}

@onready var _main_view: VBoxContainer = $Center/Panel/Margin/VBox/MainView
@onready var _resume_button: Button = $Center/Panel/Margin/VBox/MainView/ResumeButton
@onready var _powerups_button: Button = $Center/Panel/Margin/VBox/MainView/PowerupsButton
@onready var _options_button: Button = $Center/Panel/Margin/VBox/MainView/OptionsButton
@onready var _quit_button: Button = $Center/Panel/Margin/VBox/MainView/QuitButton

@onready var _powerups_view: VBoxContainer = $Center/Panel/Margin/VBox/PowerupsView
@onready var _stats_list: VBoxContainer = $Center/Panel/Margin/VBox/PowerupsView/Scroll/StatsList
@onready var _powerups_back: Button = $Center/Panel/Margin/VBox/PowerupsView/BackButton

@onready var _options_view: VBoxContainer = $Center/Panel/Margin/VBox/OptionsView
@onready var _volume_slider: HSlider = $Center/Panel/Margin/VBox/OptionsView/VolumeRow/VolumeSlider
@onready var _fullscreen_check: CheckButton = $Center/Panel/Margin/VBox/OptionsView/FullscreenRow/FullscreenCheck
@onready var _options_back: Button = $Center/Panel/Margin/VBox/OptionsView/BackButton

@onready var _title: Label = $Center/Panel/Margin/VBox/Title
@onready var _panel: PanelContainer = $Center/Panel

var _player: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for u in LEVEL_UP_MENU.UPGRADES:
		_upgrade_titles[u["id"]] = u["title"]

	_panel.add_theme_stylebox_override("panel", UITheme.make_box(UITheme.COLOR_FILL, UITheme.COLOR_BORDER, 0.0, 3))
	UITheme.style_label(_title, 32, true)
	for b in [_resume_button, _powerups_button, _options_button, _quit_button, _powerups_back, _options_back]:
		UITheme.style_button(b, 18)
		b.mouse_entered.connect(UITheme.pulse.bind(b, 1.05, 0.08))
		b.mouse_exited.connect(UITheme.pulse.bind(b, 1.0, 0.08))

	_resume_button.pressed.connect(_on_resume)
	_powerups_button.pressed.connect(_show_view.bind(_powerups_view))
	_options_button.pressed.connect(_show_view.bind(_options_view))
	_quit_button.pressed.connect(_on_quit)
	_powerups_back.pressed.connect(_show_view.bind(_main_view))
	_options_back.pressed.connect(_show_view.bind(_main_view))

	var master_idx := AudioServer.get_bus_index("Master")
	_volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_idx))
	_volume_slider.value_changed.connect(_on_volume_changed)
	_fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	_show_view(_main_view)
	_resume_button.grab_focus()

func setup(player: Node) -> void:
	_player = player

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _main_view.visible:
			_on_resume()
		else:
			_show_view(_main_view)
		get_viewport().set_input_as_handled()

func _show_view(view: VBoxContainer) -> void:
	_main_view.visible = view == _main_view
	_powerups_view.visible = view == _powerups_view
	_options_view.visible = view == _options_view
	if view == _powerups_view:
		_build_powerups()
	_title.text = "PAUSA" if view == _main_view else ("POTENCIADORES" if view == _powerups_view else "OPCIONES")

## Arma la lista de cartas elegidas + un resumen de stats actuales,
## desde cero cada vez que se abre la pestaña (la run sigue avanzando
## detrás del menú de pausa mientras está construida, así que no
## conviene cachear esto).
func _build_powerups() -> void:
	for child in _stats_list.get_children():
		child.queue_free()
	if _player == null:
		return

	_add_section_label("CARTAS ELEGIDAS")
	if _player.upgrade_log.is_empty():
		_add_stat_line("(todavía ninguna)")
	else:
		var counts: Dictionary = {}
		for id in _player.upgrade_log:
			counts[id] = counts.get(id, 0) + 1
		for id in counts:
			var title: String = _upgrade_titles.get(id, id)
			var count: int = counts[id]
			_add_stat_line(title + (" x%d" % count if count > 1 else ""))

	_add_section_label("STATS ACTUALES")
	_add_stat_line("Vida máxima: %d" % int(round(_player.max_hp)))
	if _player.max_defense > 0.0:
		_add_stat_line("Defensa máxima: %d" % int(round(_player.max_defense)))
	_add_stat_line("Multiplicador de daño: x%.2f" % _player.damage_mult)
	_add_stat_line("Velocidad de ataque: x%.2f" % _player.atk_speed_mult)
	_add_stat_line("Velocidad de movimiento: %d" % int(round(_player.move_speed)))
	if _player.hp_regen_per_sec > 0.0:
		_add_stat_line("Regeneración: %.1f HP/s" % _player.hp_regen_per_sec)
	_add_stat_line("Radio de imán: %d" % int(round(_player.magnet_radius)))
	if _player.has_method("has_ranged_attack") and _player.has_ranged_attack() and _player.ranged_power_level > 0:
		_add_stat_line("Disparo a distancia: nivel %d, x%d proyectiles" % [_player.ranged_power_level, _player.projectiles_per_shot + _player.ranged_bonus_shots])
	if _player.has_method("has_flying_swords") and _player.has_flying_swords():
		_add_stat_line("Espadas voladoras: nivel %d" % _player.sword_level())
	if _player.has_method("has_meteors") and _player.has_meteors():
		_add_stat_line("Lluvia de meteoros: activa")

func _add_section_label(text: String) -> void:
	var l := Label.new()
	l.text = text
	UITheme.style_label(l, 16, true)
	l.modulate.a = 0.9
	_stats_list.add_child(l)

func _add_stat_line(text: String) -> void:
	var l := Label.new()
	l.text = text
	UITheme.style_label(l, 14)
	l.modulate.a = 0.85
	_stats_list.add_child(l)

# ── Botones principales ────────────────────────────────────────────

func _on_resume() -> void:
	get_tree().paused = false
	queue_free()

func _on_quit() -> void:
	# Igual que morir: banca la moneda ganada antes de salir, pero sin
	# tocar el récord (abandonar no cuenta como "llegar hasta ahí").
	GameState.bank_run_currency()
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)

func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))

func _on_fullscreen_toggled(pressed: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if pressed else DisplayServer.WINDOW_MODE_WINDOWED
	)
