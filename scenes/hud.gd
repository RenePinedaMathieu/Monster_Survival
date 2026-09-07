extends CanvasLayer

## HUD del player local — barra + label de HP. main.gd conecta la
## señal `hp_changed` del player a `on_hp_changed`.

@onready var _label: Label = $Panel/MarginContainer/VBox/HPLabel
@onready var _bar: ProgressBar = $Panel/MarginContainer/VBox/HPBar

func on_hp_changed(current: float, max_hp: float) -> void:
	_label.text = "HP  %d / %d" % [int(round(current)), int(round(max_hp))]
	_bar.max_value = max_hp
	_bar.value = current
