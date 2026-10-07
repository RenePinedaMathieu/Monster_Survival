extends "res://scenes/training_dummy.gd"

## Blanco del banco de DPS: además suma todo el daño recibido por arma
## en `sink` (el de training_dummy.gd sólo guarda los últimos segundos).

var sink: Dictionary = {}

func take_damage(amount: float, source: String = "", show_number: bool = true) -> void:
	var s := source if source != "" else "?"
	sink[s] = float(sink.get(s, 0.0)) + amount
	super(amount, source, false)
