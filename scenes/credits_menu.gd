extends Control

## Pantalla de créditos (Opciones → CRÉDITOS).
##
## Cumple dos obligaciones de licencia para publicar:
##   1. Música de Kevin MacLeod (CC-BY 4.0): exige la atribución
##      LITERAL que está en MUSIC_ATTRIBUTION (ver assets/sound/CREDITS.md).
##   2. Godot Engine (MIT) y sus librerías internas (FreeType, etc.)
##      exigen incluir sus avisos de licencia en el juego distribuido —
##      se sacan del propio motor (Engine.get_license_text / info), así
##      siempre coinciden con la versión con la que se exportó.
##
## Para sumar créditos: editar TEAM / SECTIONS. Al agregar un asset
## nuevo de terceros, anotarlo acá Y en el CREDITS.md de su carpeta.

const RpgTheme := preload("res://scenes/rpg_theme.gd")
const MENU_SCENE := "res://scenes/main_menu.tscn"
const BACKGROUND_TEXTURE := "res://assets/layouts/background_home.png"

## Nombres del equipo — completar antes de publicar (si queda vacío, la
## sección no se muestra).
const TEAM: Array = []

const MUSIC_ATTRIBUTION := """Music by Kevin MacLeod (incompetech.com)
Licensed under Creative Commons: By Attribution 4.0 License
http://creativecommons.org/licenses/by/4.0/

Tracks used:
- "Comfortable Mystery 3"
- "Sneaky Adventure"
- "Kick Shock"
- "Voxel Revolution"
"""

## Cada sección: título + líneas. Sólo assets con origen y licencia ya
## verificados (ver los CREDITS.md de assets/).
const SECTIONS: Array = [
	{"title": "Música", "lines": [MUSIC_ATTRIBUTION]},
	{"title": "Efectos de sonido", "lines": [
		"Kenney — kenney.nl (CC0)",
		"Interface Sounds · Impact Sounds · RPG Audio",
	]},
	{"title": "Gráficos", "lines": [
		"Overworld Tileset: Grass Biome — Beast Pixels (CC0)",
		"Free Basic Pixel Art UI for RPG — CraftPix.net",
	]},
]

var _text: RichTextLabel
var _back: Button

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load(BACKGROUND_TEXTURE)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var window := PanelContainer.new()
	window.add_theme_stylebox_override("panel", RpgTheme.window_box_titled(26.0, 22.0))
	window.set_anchors_preset(Control.PRESET_FULL_RECT)
	window.offset_left = 60.0
	window.offset_right = -60.0
	window.offset_top = 30.0
	window.offset_bottom = -30.0
	add_child(window)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	window.add_child(vbox)

	var title := Label.new()
	title.text = "CRÉDITOS"
	RpgTheme.style_header_title(title, 24)
	vbox.add_child(title)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = true
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.focus_mode = Control.FOCUS_ALL
	# Ya va traducido a mano (secciones con tr(), licencias en inglés
	# original) — que no intente traducir el bloque entero.
	_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_text.add_theme_color_override("default_color", RpgTheme.COLOR_INK)
	_text.add_theme_font_size_override("normal_font_size", 15)
	_text.add_theme_font_size_override("bold_font_size", 18)
	_text.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_text.text = _build_text()
	vbox.add_child(_text)

	_back = Button.new()
	_back.text = "VOLVER"
	_back.custom_minimum_size = Vector2(200, 48)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	RpgTheme.style_button(_back, 18)
	_back.pressed.connect(_on_back)
	vbox.add_child(_back)

	# Con control: el stick/cruceta baja el texto (foco en el texto);
	# B / ESC vuelve. El botón VOLVER queda para mouse y táctil.
	_text.grab_focus()

func _process(delta: float) -> void:
	# Stick/cruceta para recorrer los créditos, también sin foco.
	var dir := Input.get_axis("ui_up", "ui_down")
	if absf(dir) > 0.1:
		var bar := _text.get_v_scroll_bar()
		bar.value += dir * 600.0 * delta

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()

func _on_back() -> void:
	Audio.play_sfx("ui_click")
	get_tree().change_scene_to_file(MENU_SCENE)

func _build_text() -> String:
	var parts: PackedStringArray = []
	parts.append("[center][b]One Last Hero[/b][/center]\n")
	if not TEAM.is_empty():
		parts.append(_section(tr("Un juego de"), "\n".join(PackedStringArray(TEAM))))
	for s in SECTIONS:
		parts.append(_section(tr(s["title"]), "\n".join(PackedStringArray(s["lines"]))))
	parts.append(_section(tr("Motor"), "Made with Godot Engine — godotengine.org\n\n" + Engine.get_license_text()))
	parts.append(_section(tr("Licencias de terceros"), _third_party_text()))
	return "\n".join(parts)

func _section(title: String, body: String) -> String:
	# Los textos de licencia traen [ ] que BBCode interpretaría como tags.
	return "[b]%s[/b]\n%s\n" % [title, body.replace("[", "[lb]")]

## Componentes que vienen dentro del motor (FreeType, ENet, mbedTLS...)
## con su copyright y el texto de cada licencia.
func _third_party_text() -> String:
	var out: PackedStringArray = []
	for info in Engine.get_copyright_info():
		var component: String = info.get("name", "")
		for part in info.get("parts", []):
			var holders: PackedStringArray = part.get("copyright", PackedStringArray())
			out.append("%s — %s (%s)" % [component, ", ".join(holders), part.get("license", "")])
	out.append("")
	var licenses: Dictionary = Engine.get_license_info()
	for license_name in licenses:
		out.append("— %s —\n%s\n" % [license_name, licenses[license_name]])
	return "\n".join(out)
