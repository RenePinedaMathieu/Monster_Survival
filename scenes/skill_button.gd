extends Button

## Botón de la habilidad activa (HUD), con las mismas piezas que el resto
## del HUD: el panel de madera de los otros paneles y, adentro, la casilla
## de la barra de mejoras (action_slot.png) con el ícono. Lista = borde
## verde (el de la casilla resaltada del pack) y un destello al volver a
## estar lista; en recarga, una sombra que baja con los segundos y el
## número al centro. Se toca en el teléfono o se usa ESPACIO.

const RpgTheme := preload("res://scenes/rpg_theme.gd")
const UITheme := preload("res://scenes/ui_theme.gd")
const SLOT_TEXTURE := "res://assets/ui/rpg/action_slot.png"
const COLOR_READY := Color("5fcf5f")          # verde de slot_hover.png
const COLOR_SHADE := Color(0.08, 0.05, 0.04, 0.72)
const PANEL_PAD := 7.0                        # borde de madera alrededor de la casilla
const ICON_PAD_FRAC := 0.12                   # margen del ícono dentro de la casilla

var _ratio: float = 0.0       # 0 = lista, 1 = recién usada
var _remaining: float = 0.0
var _pulse: float = 0.0
var _slot: TextureRect
var _icon_rect: TextureRect
var _overlay: SkillOverlay

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE   # si no, ESPACIO también lo "aprieta"
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", RpgTheme.wood_box(0.0, 0.0))
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	_slot = TextureRect.new()
	_slot.texture = load(SLOT_TEXTURE)
	_slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_slot.stretch_mode = TextureRect.STRETCH_SCALE
	_slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inset(_slot, PANEL_PAD)
	add_child(_slot)
	_icon_rect = TextureRect.new()
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon_rect)
	_overlay = SkillOverlay.new()
	_overlay.button = self
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	resized.connect(_layout)
	_layout()

func _inset(c: Control, pad: float) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = pad
	c.offset_top = pad
	c.offset_right = -pad
	c.offset_bottom = -pad

func _layout() -> void:
	# El ícono deja un margen proporcional a la casilla (como en la barra
	# de mejoras: 5 px en una casilla de 42).
	var inner: float = minf(size.x, size.y) - PANEL_PAD * 2.0
	_inset(_icon_rect, PANEL_PAD + inner * ICON_PAD_FRAC)

func setup(icon_tex: Texture2D, hint: String) -> void:
	_icon_rect.texture = icon_tex
	tooltip_text = hint

func set_cooldown(remaining: float, total: float) -> void:
	var was_ready: bool = _ratio <= 0.0
	_remaining = remaining
	_ratio = clampf(remaining / total, 0.0, 1.0) if total > 0.0 else 0.0
	if _ratio <= 0.0 and not was_ready:
		_pulse = 1.0   # destello al volver a estar lista
	_icon_rect.modulate = Color(0.75, 0.75, 0.75) if _ratio > 0.0 else Color.WHITE
	_overlay.queue_redraw()

func _process(delta: float) -> void:
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 2.5)
		_overlay.queue_redraw()

## Sombra de recarga, segundos y borde verde, encima de la casilla.
class SkillOverlay extends Control:
	var button = null
	func _draw() -> void:
		var pad: float = button.PANEL_PAD
		var slot := Rect2(Vector2(pad, pad), size - Vector2(pad, pad) * 2.0)
		if button._ratio > 0.0:
			# La sombra cubre desde arriba lo que falta de recarga.
			var h: float = slot.size.y * button._ratio
			draw_rect(Rect2(slot.position, Vector2(slot.size.x, h)), button.COLOR_SHADE)
			var font: Font = UITheme.make_bold_font(0.6)
			var txt := str(ceili(button._remaining))
			var fs := int(slot.size.y * 0.42)
			var w: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var p := slot.get_center() + Vector2(-w / 2.0, fs * 0.36)
			draw_string_outline(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, RpgTheme.COLOR_LIGHT_OUTLINE)
			draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, RpgTheme.COLOR_LIGHT_TEXT)
		else:
			draw_rect(slot.grow(-1.5), Color(button.COLOR_READY, 0.95), false, 3.0)
			if button._pulse > 0.0:
				var g: float = 6.0 * (1.0 - button._pulse)
				draw_rect(slot.grow(g), Color(button.COLOR_READY, button._pulse), false, 3.0)
