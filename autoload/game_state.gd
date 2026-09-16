extends Node

## Guarda la elección hecha en character_select.tscn para que quede
## disponible después del cambio de escena.
##
## NOTA: el gameplay (player.gd) todavía NO lee este valor — sigue
## usando su sprite "Man" por defecto. Cada uno de los 3 packs en
## assets/main_characters/ trae su propio set de direcciones y
## tamaño de frame (distinto entre sí y distinto del sprite actual
## del player), así que conectar el skin real es trabajo aparte.

var selected_character_id: String = "main_char1"
