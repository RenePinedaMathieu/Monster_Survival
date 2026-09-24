extends CanvasLayer

## Tutorial de bienvenida — un globo de texto sobre fondo oscuro con
## varias páginas. Se muestra UNA sola vez, disparado desde
## main_menu.gd al presionar "Jugar" mientras GameState.tutorial_seen
## sea false — de ahí en más queda guardado y no vuelve a interrumpir.
##
## Interactivo: las páginas con "target" (una NodePath relativa al
## padre de este overlay, o sea main_menu.tscn) apagan la pantalla
## excepto un recuadro brillante alrededor del botón real señalado,
## con una flecha — no sólo texto, de verdad marca dónde hay que
## hacer clic. El botón real queda BLOQUEADO mientras tanto (un
## rectángulo invisible tapa el hueco) para que un clic ahí no
## dispare la acción real por accidente mientras el tutorial sigue
## abierto — avanzar es siempre con el botón "SIGUIENTE" del globo.
##
## Uso:
##   var t = TUTORIAL_SCENE.instantiate()
##   add_child(t)          # como hijo de main_menu.tscn
##   t.finished.connect(_on_tutorial_finished)

signal finished

const UITheme := preload("res://scenes/ui_theme.gd")
const RpgTheme := preload("res://scenes/rpg_theme.gd")
const COLOR_HIGHLIGHT := Color("6ae356")

## "target" vacío = página informativa centrada, sin nada que marcar.
const PAGES: Array[Dictionary] = [
	{
		"title": "BIENVENIDO A ONE LAST HERO",
		"body": "A continuación te enseñaremos lo básico para que juegues sin problemas. Solo toma un minuto.",
		"target": "",
	},
	{
		"title": "ELIGE TU HÉROE",
		"body": "Ese es el botón para empezar a jugar. Al presionarlo vas a poder elegir tu personaje — algunos pelean cuerpo a cuerpo, otros disparan a distancia.",
		"target": "MenuButtons/PlayButton",
	},
	{
		"title": "SUBE DE NIVEL",
		"body": "Matar enemigos da experiencia. Al subir de nivel se elige una mejora entre 3 opciones: más daño, más velocidad, o desbloquear armas nuevas como disparos a distancia, espadas voladoras o lluvia de meteoros.",
		"target": "",
	},
	{
		"title": "MONEDA Y MEJORAS PERMANENTES",
		"body": "Ese es el botón de la tienda. Los enemigos sueltan moneda al morir, y esa moneda queda guardada al terminar la partida para comprar mejoras permanentes, poderes nuevos que aparecen al subir de nivel, y acompañantes que pelean contigo.",
		"target": "MenuButtons/ShopButton",
	},
	{
		"title": "OPCIONES",
		"body": "Desde aquí se ajusta el volumen y se activa la pantalla completa (F11 también funciona en cualquier momento durante la partida).",
		"target": "MenuButtons/OptionsButton",
	},
	{
		"title": "¡A SOBREVIVIR!",
		"body": "El movimiento es con WASD o las flechas (en el teléfono, el dedo en la mitad izquierda) — el ataque es automático. ESPACIO o el botón redondo usan la habilidad de tu héroe. Sobrevive 20 oleadas y vence al jefe final. Suerte, héroe.",
		"target": "",
	},
]

const SPOT_PADDING := 10.0
const ARROW_BOUNCE := 8.0
## Altura de globo "normal" (páginas sin target, o target con espacio
## de sobra arriba) — se achica hasta terminar justo arriba del botón
## señalado en pantallas más chicas, pero nunca por debajo de
## BUBBLE_MIN_BOTTOM (ahí ya no entra el contenido del globo).
const BUBBLE_TOP := 26.0
const BUBBLE_MAX_BOTTOM := 380.0
const BUBBLE_MIN_BOTTOM := 312.0
const BUBBLE_TARGET_MARGIN := 20.0

@onready var _bubble: PanelContainer = $Bubble
@onready var _title_label: Label = $Bubble/Margin/VBox/Title
@onready var _body_label: Label = $Bubble/Margin/VBox/Body
@onready var _page_label: Label = $Bubble/Margin/VBox/Nav/PageLabel
@onready var _prev_button: Button = $Bubble/Margin/VBox/Nav/PrevButton
@onready var _next_button: Button = $Bubble/Margin/VBox/Nav/NextButton
@onready var _skip_button: Button = $Bubble/Margin/VBox/SkipButton

@onready var _full_dim: ColorRect = $FullDim
@onready var _spotlight: Control = $Spotlight
@onready var _spot_top: ColorRect = $Spotlight/Top
@onready var _spot_bottom: ColorRect = $Spotlight/Bottom
@onready var _spot_left: ColorRect = $Spotlight/Left
@onready var _spot_right: ColorRect = $Spotlight/Right
@onready var _spot_guard: ColorRect = $Spotlight/Guard
@onready var _highlight: Panel = $Spotlight/Highlight
@onready var _arrow: TextureRect = $Spotlight/Arrow

var _page: int = 0
var _highlight_style: StyleBoxFlat
var _arrow_tween: Tween
## Offset vertical del rebote de la flecha — separado de su posición
## base (que _update_spotlight recalcula TODOS los frames para seguir
## al botón si la ventana cambia de tamaño) para que ambas animaciones
## no se pisen entre sí.
var _arrow_bounce: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bubble.add_theme_stylebox_override("panel", RpgTheme.window_box_titled(24.0, 20.0))
	RpgTheme.style_header_title(_title_label, 20)
	RpgTheme.style_ink_label(_body_label, 16)
	RpgTheme.style_ink_label(_page_label, 13, false, true)
	for b in [_prev_button, _next_button, _skip_button]:
		RpgTheme.style_button(b, 15)
		b.mouse_entered.connect(UITheme.pulse.bind(b, 1.05, 0.08))
		b.mouse_exited.connect(UITheme.pulse.bind(b, 1.0, 0.08))
	_prev_button.pressed.connect(_on_prev)
	_next_button.pressed.connect(_on_next)
	_skip_button.pressed.connect(_finish)

	_highlight_style = StyleBoxFlat.new()
	_highlight_style.bg_color = Color(0, 0, 0, 0)
	_highlight_style.border_color = COLOR_HIGHLIGHT
	_highlight_style.set_border_width_all(4)
	_highlight_style.set_corner_radius_all(4)
	_highlight_style.anti_aliasing = false
	_highlight.add_theme_stylebox_override("panel", _highlight_style)
	create_tween().set_loops().tween_property(_highlight_style, "border_color:a", 0.35, 0.5) \
		.from(1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Flecha del pack de UI (la fuente por defecto no trae "▶" y en web
	# no hay fuentes del sistema de respaldo: se veía un cuadrado).
	_arrow.texture = load("res://assets/ui/rpg/arrow_right.png")
	_arrow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_arrow.modulate = Color(1.4, 1.6, 1.0)

	Screen.layout_changed.connect(_apply_layout)
	_apply_layout(Screen.compact)
	_render_page()
	_next_button.grab_focus()

## En teléfono el globo usa todo el ancho (560 no entra en 480).
func _apply_layout(_compact: bool) -> void:
	var w: float = minf(560.0, Screen.view_size().x - 24.0)
	_bubble.custom_minimum_size.x = w
	_bubble.offset_left = -w / 2.0
	_bubble.offset_right = w / 2.0

func _process(_delta: float) -> void:
	# Recalcula el hueco cada frame mientras hay un target — así sigue
	# pegado al botón real aunque la ventana cambie de tamaño (F11,
	# resize) mientras el tutorial está abierto.
	if _current_target():
		_update_spotlight()

func _current_target() -> Control:
	var path: String = PAGES[_page].get("target", "")
	if path == "":
		return null
	return get_parent().get_node_or_null(path) as Control

func _render_page() -> void:
	var data: Dictionary = PAGES[_page]
	_title_label.text = data["title"]
	_body_label.text = data["body"]
	_page_label.text = "%d / %d" % [_page + 1, PAGES.size()]
	_prev_button.visible = _page > 0
	_next_button.text = "SIGUIENTE" if _page < PAGES.size() - 1 else "¡A JUGAR!"

	var target := _current_target()
	_full_dim.visible = target == null
	_spotlight.visible = target != null
	if target != null:
		_update_spotlight()
		_animate_arrow()
	else:
		_bubble.offset_bottom = BUBBLE_MAX_BOTTOM
		if _arrow_tween:
			_arrow_tween.kill()

## Arma el "hueco" con 4 franjas oscuras alrededor del target + un
## rectángulo invisible exactamente sobre el target que bloquea el
## clic real (para no disparar la acción real de golpe mientras el
## tutorial sigue abierto) sin taparlo visualmente.
func _update_spotlight() -> void:
	var target := _current_target()
	if target == null:
		return
	var r: Rect2 = target.get_global_rect().grow(SPOT_PADDING)
	var vp: Vector2 = get_viewport().get_visible_rect().size

	_spot_top.position = Vector2.ZERO
	_spot_top.size = Vector2(vp.x, max(0.0, r.position.y))

	_spot_bottom.position = Vector2(0.0, r.position.y + r.size.y)
	_spot_bottom.size = Vector2(vp.x, max(0.0, vp.y - (r.position.y + r.size.y)))

	_spot_left.position = Vector2(0.0, r.position.y)
	_spot_left.size = Vector2(max(0.0, r.position.x), r.size.y)

	_spot_right.position = Vector2(r.position.x + r.size.x, r.position.y)
	_spot_right.size = Vector2(max(0.0, vp.x - (r.position.x + r.size.x)), r.size.y)

	_spot_guard.position = r.position
	_spot_guard.size = r.size

	_highlight.position = r.position
	_highlight.size = r.size

	# A la izquierda del botón, no arriba — los botones del menú están
	# apilados con muy poco espacio entre ellos, y una flecha arriba
	# terminaba metida encima del botón anterior de la pila.
	_arrow.position = Vector2(
		r.position.x - 34.0 + _arrow_bounce,
		r.position.y + r.size.y * 0.5 - _arrow.size.y * 0.5,
	)

	# El globo no puede bajar más allá de donde arranca el botón
	# señalado (con margen) — en pantallas más chicas quedaba pegado
	# o superpuesto con el menú de abajo. Nunca por debajo de
	# BUBBLE_MIN_BOTTOM para no recortar el contenido del globo.
	_bubble.offset_bottom = max(BUBBLE_MIN_BOTTOM, min(BUBBLE_MAX_BOTTOM, r.position.y - BUBBLE_TARGET_MARGIN))

func _animate_arrow() -> void:
	if _arrow_tween:
		_arrow_tween.kill()
	_arrow_bounce = 0.0
	_arrow_tween = create_tween().set_loops()
	_arrow_tween.tween_property(self, "_arrow_bounce", ARROW_BOUNCE, 0.4).set_trans(Tween.TRANS_SINE)
	_arrow_tween.tween_property(self, "_arrow_bounce", 0.0, 0.4).set_trans(Tween.TRANS_SINE)

func _on_prev() -> void:
	if _page > 0:
		_page -= 1
		Audio.play_sfx("ui_click")
		_render_page()

func _on_next() -> void:
	Audio.play_sfx("ui_click")
	if _page < PAGES.size() - 1:
		_page += 1
		_render_page()
	else:
		_finish()

func _finish() -> void:
	GameState.mark_tutorial_seen()
	finished.emit()
	queue_free()
