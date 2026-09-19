extends Node

## Autoload "Audio" — controlador central de sonido.
##
## Uso:
##   Audio.play_sfx("player_hurt")                       # sonido global (UI)
##   Audio.play_sfx("monster_hit", global_position)      # sonido posicional 2D
##   Audio.play_music("gameplay_chill")                  # cross-fade a un track
##   Audio.stop_music()
##
## Tolerante a archivos faltantes: si el sound_id no existe o el
## archivo no está en disco, silenciosamente no hace nada. Podés meter
## los .wav/.ogg en assets/audio/ después sin romper el juego.
##
## Cada sound_id se mapea a un path (string) o a un array de paths
## (para variantes que se elijen al azar — mejor variedad audio).
##
## Los buses ("Music", "SFX", "Master") se definen en
## default_bus_layout.tres y se configuran desde el menú de opciones.

const SFX_LIBRARY: Dictionary = {
	# Player
	"player_shoot":    "res://assets/audio/sfx/player_shoot.wav",
	"player_hurt":     "res://assets/audio/sfx/player_hurt.wav",
	"player_death":    "res://assets/audio/sfx/player_death.wav",
	"player_melee":    "res://assets/audio/sfx/player_melee.wav",
	# Monsters
	"monster_hit":     "res://assets/audio/sfx/monster_hit.wav",
	"monster_death":   "res://assets/audio/sfx/monster_death.wav",
	"monster_windup":  "res://assets/audio/sfx/monster_windup.wav",
	# XP + coins
	"xp_pickup":       "res://assets/audio/sfx/xp_pickup.wav",
	"coin_pickup":     "res://assets/audio/sfx/coin_pickup.wav",
	# Progression
	"level_up":        "res://assets/audio/sfx/level_up.wav",
	"card_hover":      "res://assets/audio/sfx/card_hover.wav",
	"card_selected":   "res://assets/audio/sfx/card_selected.wav",
	# UI
	"ui_hover":        "res://assets/audio/sfx/ui_hover.wav",
	"ui_click":        "res://assets/audio/sfx/ui_click.wav",
	# Waves
	"wave_start":      "res://assets/audio/sfx/wave_start.wav",
	"wave_clear":      "res://assets/audio/sfx/wave_clear.wav",
	# Special weapons
	"meteor_whoosh":   "res://assets/audio/sfx/meteor_whoosh.wav",
	"meteor_impact":   "res://assets/audio/sfx/meteor_impact.wav",
	"sword_swing":     "res://assets/audio/sfx/sword_swing.wav",
	# Boss
	"boss_spawn":      "res://assets/audio/sfx/boss_spawn.wav",
	"boss_death":      "res://assets/audio/sfx/boss_death.wav",
}

const MUSIC_LIBRARY: Dictionary = {
	"menu":            "res://assets/audio/music/menu_theme.ogg",
	"gameplay_chill":  "res://assets/audio/music/gameplay_chill.ogg",
	"gameplay_intense":"res://assets/audio/music/gameplay_intense.ogg",
	"boss":            "res://assets/audio/music/boss_theme.ogg",
	"death":           "res://assets/audio/music/death.ogg",
}

# Cache de streams cargados. Evita re-cargar el mismo .wav 1000 veces
# en una wave llena.
var _sfx_cache: Dictionary = {}
var _current_music: AudioStreamPlayer = null
var _current_music_id: String = ""

func _ready() -> void:
	# Sonido debe seguir funcionando aunque el juego esté pausado
	# (level-up modal, etc.)
	process_mode = Node.PROCESS_MODE_ALWAYS

# ── SFX ─────────────────────────────────────────────────────────

## Reproduce un one-shot. pos = Vector2.INF para sonido global (UI/no
## posicional). pitch_variance añade jitter random para evitar la
## fatiga de escuchar el mismo sample 50 veces seguidas.
func play_sfx(id: String, pos: Vector2 = Vector2.INF, pitch_variance: float = 0.05) -> void:
	var stream: AudioStream = _get_sfx_stream(id)
	if stream == null:
		return
	var is_positional: bool = pos.x != INF and pos.y != INF
	if is_positional:
		var player_2d := AudioStreamPlayer2D.new()
		player_2d.bus = "SFX"
		player_2d.stream = stream
		player_2d.position = pos
		if pitch_variance > 0.0:
			player_2d.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
		add_child(player_2d)
		player_2d.finished.connect(player_2d.queue_free)
		player_2d.play()
	else:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.stream = stream
		if pitch_variance > 0.0:
			player.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
		add_child(player)
		player.finished.connect(player.queue_free)
		player.play()

func _get_sfx_stream(id: String) -> AudioStream:
	if not SFX_LIBRARY.has(id):
		return null
	if _sfx_cache.has(id):
		return _sfx_cache[id]
	var path: String = SFX_LIBRARY[id]
	if not ResourceLoader.exists(path):
		_sfx_cache[id] = null
		return null
	var stream: AudioStream = load(path)
	_sfx_cache[id] = stream
	return stream

# ── Música ──────────────────────────────────────────────────────

## Cross-fade a otro track. Si ya está sonando ese mismo id, no hace
## nada — evita reiniciar el track cuando cambiás de scene sin cambiar
## de contexto musical.
func play_music(id: String, fade_ms: int = 800) -> void:
	if _current_music_id == id and is_instance_valid(_current_music):
		return
	if not MUSIC_LIBRARY.has(id):
		return
	var path: String = MUSIC_LIBRARY[id]
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	# Fade out del track anterior
	if is_instance_valid(_current_music):
		var old_music: AudioStreamPlayer = _current_music
		var tw_out := create_tween()
		tw_out.tween_property(old_music, "volume_db", -60.0, fade_ms / 1000.0)
		tw_out.tween_callback(old_music.queue_free)
	# Fade in del nuevo
	var new_music := AudioStreamPlayer.new()
	new_music.stream = stream
	new_music.bus = "Music"
	new_music.volume_db = -60.0
	add_child(new_music)
	new_music.play()
	var tw_in := create_tween()
	tw_in.tween_property(new_music, "volume_db", 0.0, fade_ms / 1000.0)
	_current_music = new_music
	_current_music_id = id

func stop_music(fade_ms: int = 500) -> void:
	if not is_instance_valid(_current_music):
		return
	var old_music: AudioStreamPlayer = _current_music
	_current_music = null
	_current_music_id = ""
	var tw := create_tween()
	tw.tween_property(old_music, "volume_db", -60.0, fade_ms / 1000.0)
	tw.tween_callback(old_music.queue_free)

# ── Volumen ─────────────────────────────────────────────────────

## Setters expuestos al menu de opciones. bus_name es "Master",
## "Music" o "SFX". volume_linear va de 0.0 (mute) a 1.0 (full).
func set_bus_volume(bus_name: String, volume_linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clamp(volume_linear, 0.0, 1.0)))

func get_bus_volume(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))
