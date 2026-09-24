extends CanvasLayer

## Pantalla de fin de partida (victoria o derrota). Pausa el juego y
## resume la run: oleada, tiempo, bajas, jefes, monedas y el daño que
## hizo cada arma (GameState.run_stats, ver weapons.gd). Botones: seguir
## en modo infinito (sólo tras ganar), reintentar, compartir y menú.
##
## Uso (main.gd):
##   var r = RESULTS_SCENE.instantiate()
##   add_child(r)
##   r.show_results(...)

signal continue_pressed

const RpgTheme := preload("res://scenes/rpg_theme.gd")
const Weapons := preload("res://scenes/weapons.gd")
const MENU_SCENE := "res://scenes/main_menu.tscn"
const GAME_NAME := "One Last Hero"
const MAX_DAMAGE_ROWS := 6
const BAR_COLOR := Color("d74427")

@onready var _window: PanelContainer = $Center/Window
@onready var _title: Label = $Center/Window/VBox/Title
@onready var _subtitle: Label = $Center/Window/VBox/Subtitle
@onready var _stats: GridContainer = $Center/Window/VBox/Stats
@onready var _damage_title: Label = $Center/Window/VBox/DamageTitle
@onready var _damage_list: VBoxContainer = $Center/Window/VBox/DamageList
@onready var _buttons: GridContainer = $Center/Window/VBox/Buttons
@onready var _continue_button: Button = $Center/Window/VBox/Buttons/ContinueButton
@onready var _retry_button: Button = $Center/Window/VBox/Buttons/RetryButton
@onready var _share_button: Button = $Center/Window/VBox/Buttons/ShareButton
@onready var _menu_button: Button = $Center/Window/VBox/Buttons/MenuButton
@onready var _toast: Label = $Center/Window/VBox/Toast

var _share_text: String = ""

func _ready() -> void:
	get_tree().paused = true
	_window.add_theme_stylebox_override("panel", RpgTheme.window_box_titled(28.0, 24.0))
	RpgTheme.style_header_title(_title, 24)
	RpgTheme.style_ink_label(_subtitle, 17, true)
	RpgTheme.style_ink_label(_damage_title, 15, true)
	RpgTheme.style_ink_label(_toast, 14, true)
	_toast.add_theme_color_override("font_color", RpgTheme.COLOR_INK_GOOD)
	for b in [_continue_button, _retry_button, _share_button, _menu_button]:
		RpgTheme.style_button(b, 16)
		b.pressed.connect(func(): Audio.play_sfx("ui_click"))
	_continue_button.pressed.connect(_on_continue)
	_retry_button.pressed.connect(_on_retry)
	_share_button.pressed.connect(_on_share)
	_menu_button.pressed.connect(_on_menu)
	Screen.layout_changed.connect(_apply_layout)
	_apply_layout(Screen.compact)

func _apply_layout(compact: bool) -> void:
	var visible_buttons: int = 4 if _continue_button.visible else 3
	_buttons.columns = 2 if compact else visible_buttons
	_window.custom_minimum_size.x = minf(640.0, Screen.view_size().x - 16.0)

## daily_score >= 0: partida del reto diario (se muestra el puntaje).
func show_results(victory: bool, wave: int, time_sec: float, hero: String, can_continue: bool, daily_score: int = -1) -> void:
	var stats: Dictionary = GameState.run_stats
	if daily_score >= 0:
		_add_stat("PUNTAJE DEL RETO", str(daily_score))
	_title.text = "¡VICTORIA!" if victory else "DERROTA"
	_subtitle.text = ("%s salvó la región" % hero) if victory else ("%s cayó en la oleada %d" % [hero, wave])
	var mins := int(time_sec) / 60
	var secs := int(time_sec) % 60
	var time_text := "%02d:%02d" % [mins, secs]
	_add_stat("Oleada", str(wave))
	_add_stat("Tiempo", time_text)
	_add_stat("Enemigos derrotados", str(stats.get("total_kills", 0)))
	_add_stat("Jefes derrotados", str(stats.get("bosses", 0)))
	_add_stat("Monedas ganadas", str(stats.get("coins", 0)))
	_build_damage_rows(stats.get("damage", {}))
	_build_new_achievements()
	_continue_button.visible = can_continue
	_apply_layout(Screen.compact)
	Audio.play_sfx("wave_clear" if victory else "player_death")

	_share_text = ("¡Gané con %s en %s y sobreviví %s! ¿Te atreves?" % [hero, GAME_NAME, time_text]) if victory \
		else ("Llegué a la oleada %d con %s en %s (%s). ¿Me superas?" % [wave, hero, GAME_NAME, time_text])
	if daily_score >= 0:
		_share_text = "Reto diario de %s (%s): %d puntos. ¿Me superas?" % [GAME_NAME, GameState.daily_date(), daily_score]
	_retry_button.grab_focus()

func _add_stat(label_text: String, value: String) -> void:
	var l := Label.new()
	l.text = label_text
	RpgTheme.style_ink_label(l, 15, false, true)
	_stats.add_child(l)
	var v := Label.new()
	v.text = value
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RpgTheme.style_ink_label(v, 15, true)
	_stats.add_child(v)

## Una fila por arma, ordenadas de más a menos daño, con barra
## relativa a la que más pegó y el % del total.
func _build_damage_rows(damage: Dictionary) -> void:
	var ids: Array = damage.keys()
	ids.erase("qa")
	ids.sort_custom(func(a, b): return damage[a] > damage[b])
	var total: float = 0.0
	for id in ids:
		total += damage[id]
	if ids.is_empty() or total <= 0.0:
		var none := Label.new()
		none.text = "Ningún arma llegó a pegar."
		RpgTheme.style_ink_label(none, 14, false, true)
		_damage_list.add_child(none)
		return
	var top: float = damage[ids[0]]
	for i in range(mini(ids.size(), MAX_DAMAGE_ROWS)):
		var id: String = ids[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_damage_list.add_child(row)

		var icon := TextureRect.new()
		icon.texture = Weapons.icon(id)
		icon.custom_minimum_size = Vector2(30, 30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		row.add_child(icon)

		var name_label := Label.new()
		name_label.text = Weapons.display_name(id)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		RpgTheme.style_ink_label(name_label, 14, true)
		row.add_child(name_label)

		# En teléfono la barra no entra junto al nombre — alcanza la cifra.
		if not Screen.compact:
			var bar := ProgressBar.new()
			bar.max_value = top
			bar.value = damage[id]
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(110, 12)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			RpgTheme.style_level_bar(bar, BAR_COLOR)
			row.add_child(bar)

		var value := Label.new()
		value.text = "%d (%d%%)" % [int(damage[id]), int(round(damage[id] / total * 100.0))]
		value.custom_minimum_size = Vector2(92, 0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		RpgTheme.style_ink_label(value, 13, false, true)
		row.add_child(value)

## Logros conseguidos en esta partida (con su premio) — es lo que hace
## que perder igual se sienta como avanzar.
func _build_new_achievements() -> void:
	var list: Array = GameState.run_new_achievements
	if list.is_empty():
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var title := Label.new()
	title.text = "LOGROS NUEVOS"
	RpgTheme.style_ink_label(title, 15, true)
	box.add_child(title)
	for a in list.slice(0, 5):
		var l := Label.new()
		l.text = "• %s — %s" % [a["name"], GameState.reward_text(a["reward"])]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		RpgTheme.style_ink_label(l, 14, true)
		l.add_theme_color_override("font_color", RpgTheme.COLOR_INK_GOOD)
		box.add_child(l)
	_damage_list.add_sibling(box)

# ── Botones ──────────────────────────────────────────────────────

func _on_continue() -> void:
	continue_pressed.emit()
	queue_free()

func _on_retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)

## En web: menú nativo de compartir del teléfono (navigator.share) con
## el link del juego; si el navegador no lo tiene, lo copia al
## portapapeles. En escritorio, directo al portapapeles.
func _on_share() -> void:
	if OS.has_feature("web"):
		var url: String = str(JavaScriptBridge.eval("window.location.origin + window.location.pathname", true))
		var text: String = _share_text + " " + url
		JavaScriptBridge.eval(
			"(function(t){if(navigator.share){navigator.share({text:t}).catch(function(){});}"
			+ "else if(navigator.clipboard){navigator.clipboard.writeText(t);}})(%s)" % JSON.stringify(text), true)
		_show_toast("¡Listo para compartir!")
	else:
		DisplayServer.clipboard_set(_share_text)
		_show_toast("¡Copiado al portapapeles!")

func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
