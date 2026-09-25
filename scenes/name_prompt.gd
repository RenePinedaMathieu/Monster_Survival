extends RefCounted

## Campo "Tu nombre" en el navegador del teléfono: el LineEdit de Godot
## no abre el teclado ahí (el teclado virtual web de Godot es
## experimental y está apagado en el export), así que no se podía
## escribir. En web táctil, tocar el campo abre el cuadro nativo del
## navegador (window.prompt) y el nombre se guarda al aceptar. En PC y
## en el navegador de escritorio el LineEdit funciona normal.

const PROMPT_TEXT := "Tu nombre para el ranking (máximo 16 letras):"

static func attach(edit: LineEdit) -> void:
	if not (OS.has_feature("web") and DisplayServer.is_touchscreen_available()):
		return
	edit.focus_mode = Control.FOCUS_NONE
	edit.gui_input.connect(func(ev: InputEvent):
		# El toque llega también como click (emulate_mouse_from_touch):
		# se usa sólo el click al soltar para no abrir el cuadro dos veces.
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			edit.accept_event()
			var js := "window.prompt(%s, %s)" % [JSON.stringify(PROMPT_TEXT), JSON.stringify(edit.text)]
			var result = JavaScriptBridge.eval(js, true)
			if typeof(result) == TYPE_STRING and result.strip_edges() != "":
				GameState.set_player_name(result)
				edit.text = GameState.player_name)
