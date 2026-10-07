extends Control

## CATÁLOGO DEL UNIVERSO (sala QA): todo lo visual del juego en un solo
## lugar para revisar que sea coherente — sirve de guía para los juegos
## que salgan de este universo (tower defense, por turnos, artillería).
##
##   HÉROES  GAROTH, ELARA y DOREN: sus colores (con cómo se ganan),
##       sus formas, su ataque y habilidad, y los poderes que le pueden
##       salir a cada uno (upgrades.gd CLASS_WEAPONS) con su evolución.
##   MONSTRUOS / ACOMPAÑANTES  todas las animaciones y direcciones,
##       A LA ESCALA DEL JUEGO (para comparar tamaños).
##   ARMAS Y CARTAS / HABILIDADES Y TIENDA / OBJETOS  el ícono o sprite
##       asignado a cada cosa.
##   EFECTOS  cada arma y efecto reproducido en vivo contra muñecos.
##   ÍCONOS  cada imagen con todos sus usos: los compartidos primero.
##
## Cada ficha dice si es SPRITE (y su archivo) o DIBUJADO POR CÓDIGO (y
## su script). Lee los mismos datos que el juego (player.gd, monster.gd,
## companion.gd, upgrades.gd, game_state.gd…): lo que cambie allá se ve
## acá sin tocar nada. Los muñecos de EFECTOS no suman estadísticas.

const RpgTheme := preload("res://scenes/rpg_theme.gd")
const Player := preload("res://scenes/player.gd")
const Monster := preload("res://scenes/monster.gd")
const Companion := preload("res://scenes/companion.gd")
const Upgrades := preload("res://scenes/upgrades.gd")
const Weapons := preload("res://scenes/weapons.gd")
const ShopMenu := preload("res://scenes/shop_menu.gd")
const CharSelect := preload("res://scenes/character_select.gd")
const Pickup := preload("res://scenes/pickup.gd")
const QA_SCENE := "res://scenes/qa_room.tscn"
const EFFECTS_SCENE := "res://scenes/effects_viewer.tscn"
const MAPS_SCENE := "res://scenes/map_viewer.tscn"

enum Cat { HEROES, MONSTERS, COMPANIONS, WEAPONS, SKILLS, ITEMS, EFFECTS, ICONS, MAPS }
const CAT_NAMES := ["HÉROES", "MONSTRUOS", "ACOMPAÑANTES", "ARMAS Y CARTAS", "HABILIDADES Y TIENDA", "OBJETOS", "EFECTOS", "ÍCONOS", "MAPAS"]
const BACKGROUNDS := [Color("1c1b22"), Color("5b7a3a"), Color("d9b36b"), Color("e4d3a0")]
const BG_NAMES := ["OSCURO", "PASTO", "ARENA", "PERGAMINO"]
const ANIMS := ["idle", "run", "attack", "hurt", "death"]
const ANIM_NAMES := ["QUIETO", "CAMINA", "ATACA", "GOLPE", "MUERE"]
const DIRS := ["front", "back", "left", "right"]
const DIR_NAMES := ["FRENTE", "ESPALDA", "IZQUIERDA", "DERECHA"]

const COLOR_SPRITE := Color("57c767")
const COLOR_CODE := Color("ff9a3c")
const COLOR_SHARED := Color("ff5a48")
const COLOR_ICON := Color("7fc8ff")
const COLOR_FAMILY := Color("b58cff")
## Íconos compartidos A PROPÓSITO: el mismo concepto en distintos
## sistemas (la carta y el nodo del árbol de "daño" usan el mismo puño).
## Salen como FAMILIA (violeta), no como conflicto (rojo).
const ICON_FAMILIES := {
	"res://assets/ui/skill_icons/skill_96.png": "Daño",
	"res://assets/ui/skill_icons/skill_99.png": "Velocidad de ataque",
	"res://assets/ui/skill_icons/skill_83.png": "Vida máxima",
	"res://assets/ui/skill_icons/skill_79.png": "Regeneración",
	"res://assets/ui/skill_icons/skill_30.png": "Imán",
	"res://assets/ui/skill_icons/skill_76.png": "Defensa",
	"res://assets/ui/skill_icons/skill_63.png": "Disparo",
	"res://assets/ui/rpg/coin.png": "Monedas",
}

var _cat: int = Cat.HEROES
var _anim: int = 0
var _dir: int = 0
var _zoom: int = 2
var _bg: int = 0

var _bg_rect: ColorRect
var _cat_buttons: Array = []
var _anim_bar: HBoxContainer
var _anim_buttons: Array = []
var _dir_buttons: Array = []
var _zoom_label: Label
var _bg_button: Button
var _scroll: ScrollContainer
## Secciones una debajo de otra (_section), cada una con sus fichas en
## una fila que se acomoda al ancho.
var _list: VBoxContainer
var _flow: HFlowContainer
## Forma que muestran las fichas de colores de HÉROES.
var _tier: int = 1
var _tier_label: Label
var _tier_box: HBoxContainer
var _hint: Label

func _ready() -> void:
	_bg_rect = ColorRect.new()
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.color = BACKGROUNDS[_bg]
	add_child(_bg_rect)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 12.0
	root.offset_right = -12.0
	root.offset_top = 10.0
	root.offset_bottom = -10.0
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# Fila 1: título, fondo, zoom, volver.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	root.add_child(top)
	var title := Label.new()
	title.text = "CATÁLOGO DEL UNIVERSO"
	RpgTheme.style_light_label(title, 24)
	top.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_bg_button = _button("FONDO: " + BG_NAMES[_bg], 14, func():
		_bg = (_bg + 1) % BACKGROUNDS.size()
		_bg_rect.color = BACKGROUNDS[_bg]
		_bg_button.text = "FONDO: " + BG_NAMES[_bg]
		_rebuild())
	top.add_child(_bg_button)
	top.add_child(_button("−", 16, func(): _set_zoom(_zoom - 1), 40.0))
	_zoom_label = Label.new()
	RpgTheme.style_light_label(_zoom_label, 15)
	top.add_child(_zoom_label)
	top.add_child(_button("+", 16, func(): _set_zoom(_zoom + 1), 40.0))
	top.add_child(_button("VOLVER", 15, func(): get_tree().change_scene_to_file(QA_SCENE)))

	# Fila 2: categorías.
	var cats := HFlowContainer.new()
	cats.add_theme_constant_override("h_separation", 6)
	cats.add_theme_constant_override("v_separation", 6)
	root.add_child(cats)
	for i in range(CAT_NAMES.size()):
		var b := _button(CAT_NAMES[i], 14, _select_cat.bind(i))
		_cat_buttons.append(b)
		cats.add_child(b)

	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	RpgTheme.style_light_label(_hint, 13)
	_hint.modulate.a = 0.85
	root.add_child(_hint)

	# Fila 3: animación y dirección (personajes).
	_anim_bar = HBoxContainer.new()
	_anim_bar.add_theme_constant_override("separation", 6)
	root.add_child(_anim_bar)
	for i in range(ANIMS.size()):
		var b := _button(ANIM_NAMES[i], 13, _set_anim.bind(i))
		_anim_buttons.append(b)
		_anim_bar.add_child(b)
	var sep := Control.new()
	sep.custom_minimum_size.x = 24.0
	_anim_bar.add_child(sep)
	for i in range(DIRS.size()):
		var b := _button(DIR_NAMES[i], 13, _set_dir.bind(i))
		_dir_buttons.append(b)
		_anim_bar.add_child(b)
	_tier_box = HBoxContainer.new()
	_tier_box.add_theme_constant_override("separation", 6)
	var sep2 := Control.new()
	sep2.custom_minimum_size.x = 24.0
	_tier_box.add_child(sep2)
	_tier_box.add_child(_button("−", 13, func(): _set_tier(_tier - 1), 34.0))
	_tier_label = Label.new()
	RpgTheme.style_light_label(_tier_label, 14)
	_tier_box.add_child(_tier_label)
	_tier_box.add_child(_button("+", 13, func(): _set_tier(_tier + 1), 34.0))
	_anim_bar.add_child(_tier_box)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)

	_set_zoom(_zoom)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(QA_SCENE)

func _button(text: String, size: int, cb: Callable, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 34)
	RpgTheme.style_button(b, size)
	b.pressed.connect(cb)
	return b

func _set_zoom(z: int) -> void:
	_zoom = clampi(z, 1, 4)
	_zoom_label.text = "ZOOM x%d" % _zoom
	_rebuild()

func _set_anim(i: int) -> void:
	_anim = i
	_rebuild()

func _set_dir(i: int) -> void:
	_dir = i
	_rebuild()

func _set_tier(t: int) -> void:
	_tier = clampi(t, 1, 9)
	_rebuild()

func _select_cat(i: int) -> void:
	_cat = i
	_rebuild()

func _rebuild() -> void:
	if _list == null:
		return
	if _cat == Cat.EFFECTS:
		get_tree().change_scene_to_file(EFFECTS_SCENE)
		return
	if _cat == Cat.MAPS:
		get_tree().change_scene_to_file(MAPS_SCENE)
		return
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_new_flow()
	for i in range(_cat_buttons.size()):
		RpgTheme.style_tab(_cat_buttons[i], i == _cat, 14)
	var animated: bool = _cat in [Cat.HEROES, Cat.MONSTERS, Cat.COMPANIONS]
	_anim_bar.visible = animated
	for i in range(_anim_buttons.size()):
		RpgTheme.style_tab(_anim_buttons[i], i == _anim, 13)
		_anim_buttons[i].visible = _cat != Cat.COMPANIONS or i < 2
	for i in range(_dir_buttons.size()):
		RpgTheme.style_tab(_dir_buttons[i], i == _dir, 13)
	_tier_box.visible = _cat == Cat.HEROES
	_tier_label.text = "FORMA %d" % _tier
	match _cat:
		Cat.HEROES: _build_heroes()
		Cat.MONSTERS: _build_monsters()
		Cat.COMPANIONS: _build_companions()
		Cat.WEAPONS: _build_weapons()
		Cat.SKILLS: _build_skills()
		Cat.ITEMS: _build_items()
		Cat.ICONS: _build_icons()

func _card_width() -> float:
	if _cat in [Cat.HEROES, Cat.MONSTERS, Cat.COMPANIONS]:
		return 150.0 + 40.0 * _zoom
	return 230.0

# ── Fichas ───────────────────────────────────────────────────────

## Ficha: vista previa + nombre + etiqueta (SPRITE / DIBUJADO / …) + líneas.
func _card(preview: Control, title: String, tag: String, tag_color: Color, lines: Array) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = BACKGROUNDS[_bg].lerp(Color.WHITE, 0.07)
	sb.border_color = BACKGROUNDS[_bg].darkened(0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8.0)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size.x = _card_width()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	card.add_child(box)
	if preview != null:
		box.add_child(preview)
	var t := Label.new()
	t.text = title
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	RpgTheme.style_light_label(t, 15)
	box.add_child(t)
	if tag != "":
		var g := Label.new()
		g.text = tag
		g.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		RpgTheme.style_light_label(g, 12)
		g.add_theme_color_override("font_color", tag_color)
		box.add_child(g)
	for line in lines:
		var l := Label.new()
		l.text = str(line)
		# Las rutas se cortan en cualquier letra; el texto, por palabras.
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY if "/" in l.text else TextServer.AUTOWRAP_WORD_SMART
		RpgTheme.style_light_label(l, 11)
		l.modulate.a = 0.8
		box.add_child(l)
	_flow.add_child(card)
	return card

func _new_flow() -> void:
	_flow = HFlowContainer.new()
	_flow.add_theme_constant_override("h_separation", 10)
	_flow.add_theme_constant_override("v_separation", 10)
	_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(_flow)

## Título de sección (y una línea de detalle); las fichas que siguen van
## debajo de él.
func _section(title: String, detail: String = "", size: int = 20) -> void:
	var t := Label.new()
	t.text = title
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	RpgTheme.style_light_label(t, size)
	_list.add_child(t)
	if detail != "":
		var d := Label.new()
		d.text = detail
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		RpgTheme.style_light_label(d, 13)
		d.modulate.a = 0.85
		_list.add_child(d)
	_new_flow()

## Caja con un sprite animado a escala de juego x zoom.
func _anim_preview(frames: Array, game_scale: float, fps: float = 8.0, box_px: float = 0.0) -> Control:
	var holder := Control.new()
	var h: float = box_px if box_px > 0.0 else 60.0 + 40.0 * _zoom
	holder.custom_minimum_size = Vector2(_card_width() - 16.0, h)
	holder.clip_contents = true
	var spr := AnimSprite.new()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2.ONE * game_scale * _zoom
	spr.set_frames(frames, fps)
	holder.add_child(spr)
	holder.resized.connect(func(): spr.position = Vector2(holder.size.x / 2.0, holder.size.y / 2.0))
	return holder

## Caja con un ícono estático (ajustado a la caja).
func _icon_preview(tex: Texture2D, px: float = 72.0, tint: Color = Color.WHITE) -> Control:
	var r := TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.modulate = tint
	var small: bool = tex != null and tex.get_width() <= 64
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if small else CanvasItem.TEXTURE_FILTER_LINEAR
	return r

func _tex(path: String, region: Rect2 = Rect2()) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var t: Texture2D = load(path)
	if region.size != Vector2.ZERO:
		var a := AtlasTexture.new()
		a.atlas = t
		a.region = region
		return a
	return t

static func _slice(path: String, frame: Vector2, max_frames: int = 64) -> Array:
	if not ResourceLoader.exists(path):
		return []
	var sheet: Texture2D = load(path)
	var out: Array = []
	var n: int = mini(max_frames, int(sheet.get_width() / frame.x))
	for i in range(n):
		var a := AtlasTexture.new()
		a.atlas = sheet
		a.region = Rect2(i * frame.x, 0, frame.x, frame.y)
		out.append(a)
	return out

# ── HÉROES ───────────────────────────────────────────────────────

## Ataque base de cada clase, para la ficha (los números son los de
## player.gd, sin mejoras).
const ATTACK_TEXT := {
	"melee": "Tajo alrededor · daño %d · alcance %d",
	"fireball": "Bola de fuego que explota en área · daño %d · alcance %d",
	"arrow": "Flecha que atraviesa · daño %d · alcance %d",
}

func _build_heroes() -> void:
	_hint.text = "Escala real del juego (x1). Por héroe: sus 4 colores en la FORMA elegida (y cómo se gana cada uno), todas sus formas y los poderes que le pueden salir al subir de nivel. Las pasivas son de todos."
	var anim_name: String = ANIMS[_anim]
	var sw_dir: String = ["front", "back", "side_left", "side_right"][_dir]
	var anim_folder: String = {"idle": "Idle", "run": "Run", "attack": "Attack", "hurt": "Hurt", "death": "Death"}[anim_name]
	for hero_id in Player.HERO_CLASSES:
		var hc: Dictionary = Player.HERO_CLASSES[hero_id]
		var entry: Dictionary = CharSelect.find_character(hero_id)
		var skill: Dictionary = Player.ACTIVE_SKILLS[hero_id]
		var dmg: float = {"melee": Player.SWORDMAN_MELEE_DAMAGE, "fireball": Player.ELARA_FIRE_DAMAGE, "arrow": Player.DOREN_ARROW_DAMAGE}[hc["attack"]]
		var detail: String = "Ataque: " + ATTACK_TEXT[hc["attack"]] % [int(dmg), int(hc["range"])]
		detail += "\nHabilidad: %s (cada %.1f s) — %s" % [skill["name"], skill["cooldown"], skill.get("desc", "")]
		detail += "\nVida x%.2f · velocidad x%.2f · %d formas (una cada %d niveles, +%d%% de daño cada una)" % [
			hc["hp"], hc["speed"], hc["max_tier"], hc["tier_every"], int(hc["tier_damage"] * 100.0)]
		if hc.has("damage_taken"):
			detail += " · recibe %d%% menos daño" % roundi((1.0 - float(hc["damage_taken"])) * 100.0)
		_section("%s · %s" % [entry["name"], entry.get("role", "")], detail, 22)
		# Colores: el sprite en la forma elegida y su retrato.
		var tier: int = mini(_tier, int(hc["max_tier"]))
		for ci in range(hc["colors"].size()):
			var path := _hero_sheet(hc["colors"][ci], tier, anim_folder, sw_dir)
			var frames := _slice(path, Player.SWORDMAN_FRAME_SIZE)
			var c: Dictionary = CharSelect.colored(CharSelect.find_character(hero_id), ci)
			var preview := HBoxContainer.new()
			preview.add_child(_anim_preview(frames, Player.SWORDMAN_SCALE))
			preview.add_child(_icon_preview(CharSelect.portrait_texture(c), 96.0))
			var how: String = "De base" if ci == 0 else "Se gana: " + GameState.color_unlock_hint(hero_id, ci)
			_card(preview, "%s %s · forma %d" % [entry["name"], c.get("color", ""), tier],
				"COLOR %d" % (ci + 1), COLOR_SPRITE if ci == 0 else COLOR_FAMILY,
				[how, "Retrato pendiente (sprite ampliado)" if c.get("portrait_pending", false) else "Retrato: ilustración", _short(path)])
		# Formas: todas, en su color de base.
		_section("Formas de %s" % entry["name"], "", 15)
		for t in range(1, int(hc["max_tier"]) + 1):
			var path := _hero_sheet(hc["colors"][0], t, anim_folder, sw_dir)
			var frames := _slice(path, Player.SWORDMAN_FRAME_SIZE)
			_card(_anim_preview(frames, Player.SWORDMAN_SCALE), "Forma %d" % t, "desde el nivel %d" % (1 + (t - 1) * int(hc["tier_every"])), COLOR_SPRITE,
				["%d cuadros de %dx%d" % [frames.size(), Player.SWORDMAN_FRAME_SIZE.x, Player.SWORDMAN_FRAME_SIZE.y]])
		# Poderes: las armas de su clase (las únicas que le salen).
		_section("Poderes de %s" % entry["name"], "Las armas que le pueden salir al subir de nivel (sólo las suyas, ver upgrades.gd CLASS_WEAPONS).", 15)
		for w in Upgrades.CLASS_WEAPONS.get(hero_id, []):
			_power_card(w)
	# Pasivas: de todos los héroes.
	_section("Pasivas (todos los héroes)", "Mejoras que le salen a cualquiera. Las bloqueadas se ganan en los desafíos.")
	for id in Upgrades.PASSIVES:
		var c: Dictionary = Upgrades.card(id)
		var lines: Array = [c["desc"], "nivel máximo %d" % Upgrades.PASSIVES[id]]
		var tag := "PASIVA"
		var color := COLOR_ICON
		if id in Upgrades.LOCKED_CARDS:
			for t in GameState.TRIALS:
				if id in t["reward"].get("cards", []):
					lines.append("Se gana en el desafío: " + t["name"])
			tag = "PASIVA · DE DESAFÍO"
			color = COLOR_CODE
		for e in Upgrades.EVOLUTIONS:
			if Upgrades.EVOLUTIONS[e]["passive"] == id:
				lines.append("Evoluciona %s → %s" % [_weapon_name(Upgrades.EVOLUTIONS[e]["weapon"]), Upgrades.EVOLUTIONS[e]["name"]])
		_card(_icon_preview(_tex(c["icon"]), 56.0), c["title"], tag, color, lines)

## Ficha de un arma: su carta, cómo se habilita y su evolución.
func _power_card(w: String) -> void:
	var data: Dictionary = Upgrades.WEAPONS[w]
	var c: Dictionary = Upgrades.card(data["unlock"])
	var lines: Array = [c.get("desc", "")]
	if data["shop"] == "":
		lines.append("Disponible desde el principio")
	else:
		var p: Dictionary = GameState.SHOP_POWERS[data["shop"]]
		lines.append("Se compra en la tienda (PODERES): %d monedas" % p["cost"])
	if data["extras"].size() > 0:
		var extras: Array = []
		for x in data["extras"]:
			extras.append(Upgrades.card(x).get("desc", x))
		lines.append("Cartas propias: " + ", ".join(extras))
	var evo := ""
	for e in Upgrades.EVOLUTIONS:
		if Upgrades.EVOLUTIONS[e]["weapon"] == w:
			evo = e
	if evo != "":
		var ev: Dictionary = Upgrades.EVOLUTIONS[evo]
		lines.append("Evoluciona a %s (al máximo + %s): %s" % [ev["name"], Upgrades.card(ev["passive"]).get("title", ev["passive"]), ev["desc"]])
	else:
		lines.append("Sin evolución")
	_card(_icon_preview(_tex(c.get("icon", "")), 56.0), data["name"], "ARMA" if data["shop"] == "" else "ARMA · DE LA TIENDA",
		COLOR_ICON if data["shop"] == "" else COLOR_CODE, lines)

func _weapon_name(w: String) -> String:
	return Upgrades.WEAPONS[w]["name"] if Upgrades.WEAPONS.has(w) else w

## Hoja de un héroe (color con "dir" o el GAROTH original del pack).
func _hero_sheet(col: Dictionary, tier: int, anim_folder: String, sw_dir: String) -> String:
	if col.has("dir"):
		var n: String = col["name"]
		return "%s%s_lvl%d/%s/%s_lvl%d_%s_%s.png" % [col["dir"], n, tier, anim_folder, n, tier, anim_folder, sw_dir]
	return _swordman_path(tier, anim_folder, sw_dir)

func _swordman_path(tier: int, anim: String, direction: String) -> String:
	var base := "res://assets/sprites/swordman/Swordsman_lvl%d/" % tier
	var folder := anim if tier >= 4 else "Swordsman_lvl%d_%s" % [tier, anim]
	var fname := "Swordsman_lvl%d_%s_%s.png" % [tier, anim if anim != "Attack" else "attack", direction]
	return "%s%s/%s" % [base, folder, fname]

# ── MONSTRUOS ────────────────────────────────────────────────────

func _build_monsters() -> void:
	_hint.text = "Escala real del juego. Los jefes (demonios) arriba. Datos: vida base, monedas, comportamiento."
	var ids: Array = Monster.KIND_DATA.keys()
	ids.sort_custom(func(a, b): return (a in Monster.BOSS_KIND_IDS) and not (b in Monster.BOSS_KIND_IDS))
	for id in ids:
		var data: Dictionary = Monster.KIND_DATA[id]
		var anim_name: String = ANIMS[_anim]
		var all: Dictionary = Monster._build_anim_frames(data, data.get("frame_size", Vector2(64, 64)), data.get("cols", 4))
		var frames: Array = all.get(anim_name, {}).get(DIRS[_dir], [])
		if frames.is_empty():
			_card(null, id, "SIN animación '%s'" % ANIM_NAMES[_anim], COLOR_SHARED, [])
			continue
		var is_boss: bool = id in Monster.BOSS_KIND_IDS
		var info: Dictionary = data.get(anim_name, {"file": data["idle"]["file"].replace("Idle", "Hurt")})
		var fs: Vector2 = data.get("frame_size", Vector2(64, 64))
		var sc: float = Monster.kind_scale(data)
		_card(_anim_preview(frames, sc, 8.0), ("JEFE · " if is_boss else "") + id, "SPRITE", COLOR_SPRITE,
			[_short(data["base"] + info["file"].replace("_front", "_" + DIRS[_dir])),
			"%d cuadros de %dx%d · %s nivel %d · escala %.2f" % [frames.size(), fs.x, fs.y, data.get("size", "?"), int(data.get("tier", 1)), sc],
			("vida y monedas las calcula main.gd (jefe)" if is_boss else "vida %s · monedas %s" % [str(data.get("hp", "?")), str(data.get("coin_reward", "?"))]) + " · " + Monster._behavior_for(id)])

# ── ACOMPAÑANTES ─────────────────────────────────────────────────

func _build_companions() -> void:
	_hint.text = "Escala real del juego. Cada línea crece al subir de nivel (cría → adulto)."
	var anim_name: String = "walk" if _anim == 1 else "idle"
	for line in GameState.COMPANIONS:
		var comp: Dictionary = GameState.COMPANIONS[line]
		for st in comp["stages"]:
			var form: String = st[1]
			var sp: Dictionary = Companion.SPRITES[form]
			var path := "res://assets/companions/%s/%s_%s.png" % [form, anim_name, DIRS[_dir]]
			var frames := _slice(path, sp["frame"])
			_card(_anim_preview(frames, float(sp["scale"]), Companion.FPS), "%s (nivel %d+)" % [st[2], st[0]], "SPRITE", COLOR_SPRITE,
				[_short(path), "%d cuadros de %dx%d · escala %.2f" % [frames.size(), sp["frame"].x, sp["frame"].y, sp["scale"]],
				"Línea %s · %s" % [line, comp["ability"]]])

# ── ARMAS Y CARTAS ───────────────────────────────────────────────

func _build_weapons() -> void:
	_hint.text = "Ícono de cada carta de subida de nivel; en armas, también lo que se ve en el juego y su evolución."
	var evo_by_weapon := {}
	for e in Upgrades.EVOLUTIONS:
		evo_by_weapon[Upgrades.EVOLUTIONS[e]["weapon"]] = e
	var in_game := {
		"disparo": ["Flecha: ícono estático + estela dibujada", "res://assets/ui/weapon_icons/icon_43.png"],
		"espadas": ["Espada: ícono estático + estela dibujada", "res://assets/ui/weapon_icons/icon_15.png"],
		"hacha": ["Hacha: ícono que gira", "res://assets/ui/weapon_icons/icon_86.png"],
		"meteoros": ["DIBUJADO POR CÓDIGO (meteor.gd)", ""],
		"aura": ["DIBUJADO POR CÓDIGO (aura_weapon.gd)", ""],
		"rayo": ["DIBUJADO POR CÓDIGO (bolt_effect.gd)", ""],
		"laser_cadena": ["DIBUJADO POR CÓDIGO (laser_effect.gd)", ""],
		"disparo_fuego": ["Flecha + quemadura (shot_projectile.gd)", "res://assets/ui/weapon_icons/icon_43.png"],
		"disparo_electrico": ["Flecha + aturdir (shot_projectile.gd)", "res://assets/ui/weapon_icons/icon_43.png"],
		"disparo_congelante": ["Flecha + congelar (shot_projectile.gd)", "res://assets/ui/weapon_icons/icon_43.png"],
		"escudo_fuerza": ["DIBUJADO POR CÓDIGO (force_shield_weapon.gd)", ""],
		"pulso": ["DIBUJADO POR CÓDIGO (pulse_weapon.gd)", ""],
	}
	var weapon_of_card := {}
	for w in Upgrades.WEAPONS:
		weapon_of_card[Upgrades.WEAPONS[w]["unlock"]] = w
	for c in Upgrades.CARDS:
		var kind := "PASIVA" if Upgrades.PASSIVES.has(c["id"]) else ("ARMA" if weapon_of_card.has(c["id"]) else "CARTA")
		var lines: Array = [c["desc"], _short(c["icon"])]
		var tag_color := COLOR_ICON
		if weapon_of_card.has(c["id"]):
			var w: String = weapon_of_card[c["id"]]
			if in_game.has(w):
				lines.append("En juego: " + in_game[w][0])
				if in_game[w][0].begins_with("DIBUJADO"):
					tag_color = COLOR_CODE
			if evo_by_weapon.has(w):
				var ev: Dictionary = Upgrades.EVOLUTIONS[evo_by_weapon[w]]
				lines.append("Evoluciona a %s (con %s)" % [ev["name"], ev["passive"]])
			else:
				lines.append("SIN evolución")
		var shared := _shared_line(c["icon"], c["title"])
		if shared != "":
			lines.append(shared)
		_card(_icon_preview(_tex(c["icon"])), "%s · %s" % [kind, c["title"]], "ÍCONO", tag_color, lines)
	for e in Upgrades.EVOLUTIONS:
		var ev: Dictionary = Upgrades.EVOLUTIONS[e]
		_card(_icon_preview(_tex(ev["icon"])), "EVOLUCIÓN · " + ev["name"], "ÍCONO", COLOR_ICON,
			["%s + %s" % [ev["weapon"], ev["passive"]], ev["desc"], _short(ev["icon"])])
	for w in ["disparo", "espadas", "hacha"]:
		var path: String = in_game[w][1]
		_card(_icon_preview(_tex(path), 72.0), "En juego · " + Upgrades.WEAPONS[w]["name"], "SPRITE (un ícono usado como proyectil)", COLOR_SPRITE,
			[_short(path), in_game[w][0]])

# ── HABILIDADES Y TIENDA ─────────────────────────────────────────

func _build_skills() -> void:
	_hint.text = "Habilidades de héroe (botón redondo), árbol de la tienda, poderes y acompañantes."
	for hero in Player.ACTIVE_SKILLS:
		var s: Dictionary = Player.ACTIVE_SKILLS[hero]
		_card(_icon_preview(_tex(s["icon"])), "HABILIDAD · %s (%s)" % [s["name"], GameState.CHARACTER_NAMES.get(hero, hero)], "ÍCONO", COLOR_ICON,
			[s.get("desc", ""), "enfriamiento %.1f s" % s["cooldown"], _short(s["icon"]), _shared_line(s["icon"], s["name"])])
	for id in GameState.SKILL_TREE:
		var n: Dictionary = GameState.SKILL_TREE[id]
		var legend: String = n.get("legend", "")
		_card(_icon_preview(_tex(n["icon"])), ("LEGENDARIA · " if legend != "" else "ÁRBOL · ") + n["name"], "ÍCONO", COLOR_ICON,
			[n["desc"], "rama %s · %d niveles" % [n["branch"], n["max_level"]], _short(n["icon"]), _shared_line(n["icon"], n["name"])])
	for id in GameState.SHOP_POWERS:
		var p: Dictionary = GameState.SHOP_POWERS[id]
		var icon: String = ShopMenu.POWER_ICONS.get(id, "")
		_card(_icon_preview(_tex(icon)), "PODER · " + p["name"], "ÍCONO", COLOR_ICON,
			[p["desc"], "%d monedas" % p["cost"], _short(icon), _shared_line(icon, p["name"])])

# ── OBJETOS ──────────────────────────────────────────────────────

func _build_items() -> void:
	_hint.text = "Objetos del mapa y premios. El color de los premios es el tinte que usa el juego."
	for kind in Pickup.ICONS:
		var icon: String = Pickup.ICONS[kind]
		_card(_icon_preview(_tex(icon), 56.0, Pickup.TINTS.get(kind, Color.WHITE)), "Premio del barril · " + kind, "SPRITE (ícono)", COLOR_SPRITE,
			[Pickup.LABELS[kind][0].replace("%d", "N"), _short(icon)])
	_card(_icon_preview(_tex("res://assets/ui/rpg/chest.png"), 64.0), "Cofre", "SPRITE + brillo dibujado", COLOR_SPRITE, ["res://assets/ui/rpg/chest.png", "chest.gd"])
	_card(_icon_preview(_tex("res://assets/ui/rpg/barrel.png"), 64.0), "Barril", "SPRITE + astillas dibujadas", COLOR_SPRITE, ["res://assets/ui/rpg/barrel.png", "breakable.gd"])
	_card(_icon_preview(_tex("res://assets/ui/ui_coin.png"), 48.0, Color(0.6, 1.0, 0.55)), "Orbe de experiencia", "SPRITE (moneda teñida de verde)", COLOR_SPRITE, ["res://assets/ui/ui_coin.png", "xp_orb.tscn"])
	_card(_icon_preview(_tex("res://assets/ui/rpg/coin.png"), 48.0), "Moneda (interfaz)", "SPRITE", COLOR_SPRITE, ["res://assets/ui/rpg/coin.png"])
	for m in GameState.MAPS:
		var d: Dictionary = GameState.MAPS[m]
		_card(_icon_preview(_tex(d["tileset"]), 180.0), "Mapa · " + d["name"], "SPRITE (tiles)" if d.get("image", "") == "" else "IMAGEN PINTADA", COLOR_SPRITE,
			[_short(d["tileset"]), d["desc"]])

# ── ÍCONOS ───────────────────────────────────────────────────────

## ruta del ícono -> [nombres de lo que lo usa]
func _icon_uses() -> Dictionary:
	var uses := {}
	var add := func(path: String, name: String) -> void:
		if path == "":
			return
		if not uses.has(path):
			uses[path] = []
		uses[path].append(name)
	for c in Upgrades.CARDS:
		add.call(c["icon"], "Carta " + c["title"])
	for e in Upgrades.EVOLUTIONS:
		add.call(Upgrades.EVOLUTIONS[e]["icon"], "Evolución " + Upgrades.EVOLUTIONS[e]["name"])
	for id in GameState.SKILL_TREE:
		add.call(GameState.SKILL_TREE[id]["icon"], "Árbol " + GameState.SKILL_TREE[id]["name"])
	for id in ShopMenu.POWER_ICONS:
		add.call(ShopMenu.POWER_ICONS[id], "Poder " + GameState.SHOP_POWERS.get(id, {}).get("name", id))
	for hero in Player.ACTIVE_SKILLS:
		add.call(Player.ACTIVE_SKILLS[hero]["icon"], "Habilidad " + Player.ACTIVE_SKILLS[hero]["name"])
	for k in Pickup.ICONS:
		add.call(Pickup.ICONS[k], "Premio " + k)
	add.call("res://assets/ui/weapon_icons/icon_43.png", "Proyectil flecha")
	add.call("res://assets/ui/weapon_icons/icon_15.png", "Proyectil espada")
	add.call("res://assets/ui/weapon_icons/icon_86.png", "Proyectil hacha")
	return uses

## Compartido = lo usan cosas con nombres distintos (el mismo poder en
## carta, tienda y resultados no cuenta).
func _is_shared(uses: Array) -> bool:
	var names := {}
	for u in uses:
		names[_norm(u)] = true
	return names.size() > 1

func _other_names(uses: Array, me: String) -> Array:
	var out: Array = []
	for u in uses:
		if _norm(u) != _norm(me):
			out.append(u)
	return out

func _shared_line(path: String, me: String) -> String:
	var uses: Array = _icon_uses().get(path, [])
	if not _is_shared(uses):
		return ""
	var head := ("Familia %s, con: " % ICON_FAMILIES[path]) if ICON_FAMILIES.has(path) else "CONFLICTO de ícono con: "
	return head + ", ".join(_other_names(uses, me))

## "Carta LLUVIA DE METEOROS" y "Poder Lluvia de meteoros" son lo mismo.
func _norm(s: String) -> String:
	var t := s.to_lower()
	for pre in ["carta ", "poder ", "evolución ", "árbol ", "habilidad ", "premio ", "proyectil "]:
		if t.begins_with(pre):
			t = t.substr(pre.length())
	return t.replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u").strip_edges()

## 2 = conflicto (cosas distintas con el mismo ícono), 1 = familia, 0 = único.
func _icon_rank(path: String, uses: Array) -> int:
	if not _is_shared(uses):
		return 0
	return 1 if ICON_FAMILIES.has(path) else 2

func _build_icons() -> void:
	var uses := _icon_uses()
	var paths: Array = uses.keys()
	paths.sort_custom(func(a, b):
		var ra := _icon_rank(a, uses[a])
		var rb := _icon_rank(b, uses[b])
		if ra != rb:
			return ra > rb
		return a < b)
	var conflicts := paths.filter(func(p): return _icon_rank(p, uses[p]) == 2).size()
	var families := paths.filter(func(p): return _icon_rank(p, uses[p]) == 1).size()
	_hint.text = "%d imágenes en uso · %d CONFLICTOS (rojo: cosas distintas con el mismo ícono) · %d FAMILIAS (violeta: el mismo concepto a propósito)." % [paths.size(), conflicts, families]
	for p in paths:
		var rank := _icon_rank(p, uses[p])
		var tag: String = ["único", "FAMILIA: " + ICON_FAMILIES.get(p, ""), "CONFLICTO"][rank]
		_card(_icon_preview(_tex(p), 64.0), _short(p), tag, [COLOR_ICON, COLOR_FAMILY, COLOR_SHARED][rank], uses[p])

func _short(path: String) -> String:
	return path.replace("res://assets/", "")

## Sprite que recorre sus cuadros (vistas previas de animación).
class AnimSprite extends Sprite2D:
	var _frames: Array = []
	var _fps: float = 8.0
	var _t: float = 0.0
	var _i: int = 0
	func set_frames(f: Array, fps: float) -> void:
		_frames = f
		_fps = fps
		_i = 0
		texture = _frames[0] if not _frames.is_empty() else null
	func _process(delta: float) -> void:
		if _frames.size() < 2:
			return
		_t += delta
		if _t >= 1.0 / _fps:
			_t = 0.0
			_i = (_i + 1) % _frames.size()
			texture = _frames[_i]
