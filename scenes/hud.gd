extends CanvasLayer

## HUD estilo Vampire Survivors:
##   - HP arriba a la izquierda con barra + label
##   - Nivel + barra de XP debajo
##   - Timer del run centrado arriba
##   - Panel de wave debajo del XP (por ahora seguimos con oleadas
##     mezcladas — más adelante lo cambiamos a spawn continuo)
##   - Banner central "WAVE CLEARED" con fade

@onready var _hp_label: Label = $HPPanel/Margin/VBox/HPLabel
@onready var _hp_bar: ProgressBar = $HPPanel/Margin/VBox/HPBar
@onready var _level_label: Label = $LevelPanel/Margin2/VBox2/LevelLabel
@onready var _xp_bar: ProgressBar = $LevelPanel/Margin2/VBox2/XPBar
@onready var _wave_label: Label = $WavePanel/Margin4/VBox3/WaveLabel
@onready var _monsters_label: Label = $WavePanel/Margin4/VBox3/MonstersLabel
@onready var _timer_label: Label = $TimerPanel/Margin3/TimerLabel
@onready var _banner: Label = $BreakBanner

var _run_time: float = 0.0
var _running: bool = true

func _process(delta: float) -> void:
	if not _running: return
	_run_time += delta
	var mins := int(_run_time) / 60
	var secs := int(_run_time) % 60
	_timer_label.text = "%02d:%02d" % [mins, secs]

func on_hp_changed(current: float, max_hp: float) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = current
	_hp_label.text = "HP  %d / %d" % [int(round(current)), int(round(max_hp))]

func on_xp_changed(current: int, needed: int, level: int) -> void:
	_xp_bar.max_value = needed
	_xp_bar.value = current
	_level_label.text = "LVL %d" % level

func set_wave(n: int, remaining: int) -> void:
	_wave_label.text = "WAVE %d" % n
	_monsters_label.text = "Monsters %d" % remaining

func show_wave_break(_duration: float) -> void:
	_banner.text = "WAVE %d CLEARED" % int(_wave_label.text.trim_prefix("WAVE "))
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.3)
	tw.tween_interval(1.2)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.5)

func stop_timer() -> void:
	_running = false
