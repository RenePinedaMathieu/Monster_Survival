extends CanvasLayer

## HUD — HP bar arriba a la izq, panel de Wave debajo, y un banner
## grande de "WAVE CLEARED" en el medio de la pantalla que aparece
## y desaparece con fade durante los breaks entre waves.

@onready var _hp_label: Label = $HPPanel/Margin/VBox/HPLabel
@onready var _hp_bar: ProgressBar = $HPPanel/Margin/VBox/HPBar
@onready var _wave_label: Label = $WavePanel/Margin2/VBox2/WaveLabel
@onready var _monsters_label: Label = $WavePanel/Margin2/VBox2/MonstersLabel
@onready var _break_banner: Label = $BreakBanner

func on_hp_changed(current: float, max_hp: float) -> void:
	_hp_label.text = "HP  %d / %d" % [int(round(current)), int(round(max_hp))]
	_hp_bar.max_value = max_hp
	_hp_bar.value = current

func set_wave(wave: int, monsters_left: int) -> void:
	_wave_label.text = "WAVE  %d" % wave
	_monsters_label.text = "Monsters  %d" % monsters_left

func show_wave_break(duration: float) -> void:
	_break_banner.text = "WAVE %d CLEARED" % int(_wave_label.text.trim_prefix("WAVE  "))
	# Fade in → hold → fade out
	var tween := create_tween()
	tween.tween_property(_break_banner, "modulate", Color(1, 1, 1, 1), 0.25)
	tween.tween_interval(max(0.5, duration - 0.75))
	tween.tween_property(_break_banner, "modulate", Color(1, 1, 1, 0), 0.4)
