# Cómo pintar los mapas en Tiled

Hay tres mapas listos para pintar, uno por portón del pueblo:

| Mapa | Archivo | Pack |
|---|---|---|
| Bosque (reemplaza a la Pradera) | `assets/maps/bosque/bosque.tmx` | Forest |
| Desierto | `assets/maps/desierto/desierto.tmx` | Desert |
| Pantano | `assets/maps/pantano/pantano.tmx` | Swamp |

Ábrelos en Tiled con Archivo > Abrir. Cada uno mide 200 × 160 cuadros de 16 px, el tamaño de los mapas de hoy, a la escala de los héroes. Puedes cambiarlo en Mapa > Cambiar tamaño del mapa y el juego lo lee solo.

## La paleta del centro

Al centro está el mapa de ejemplo del pack, ya armado con todas sus capas. Úsalo para copiar piezas:

1. En el panel Capas, selecciona todas las capas (clic en la primera, Mayús+clic en la última).
2. Con la selección rectangular (tecla R), marca un trozo: un árbol, una laguna, un camino.
3. Ctrl+C y Ctrl+V donde quieras: se pega con todas sus capas.

Si se pega una sola capa, copia y pega capa por capa.

El resto del mapa ya tiene el suelo de base (pasto o arena) para pintar encima.

## Capas: piso y objetos

- **Piso:** todas las capas de abajo (agua, suelo, manchas, pasto, enredaderas…). El héroe camina encima.
- **Objetos:** desde la primera capa llamada `objects` (o `objects1`, `Objects4`…) hacia arriba. Cada objeto tiene altura: el héroe pasa por detrás de la copa de un árbol y por delante del tronco.
- **Un objeto por grupo:** el juego toma como un solo objeto las baldosas que se tocan en una misma capa. Si dos árboles se tocan, ponlos en capas de objetos distintas, como hace el ejemplo.

## Qué choca

Solo, sin pintar nada:
- **El agua**, también la de las orillas pintadas con baldosas de costa.
- **La base de los objetos de 32 px de alto o más:** troncos, rocas, ruinas. Los chicos (hongos, matas, flores) se atraviesan.

Con la capa **`choque`** (arriba de todo, medio transparente):
- **Cuadro rojo:** no se pasa. Úsalo para acantilados, paredes de mesetas o lo que se escape.
- **Cuadro verde:** sí se pasa, aunque algo choque ahí. El verde gana a todo.

## No cambiar

- El nombre de la capa `choque`.
- El mapa no infinito y las capas en formato CSV (vienen así).
- Las capas que ocultes en Tiled no van al juego.

## El héroe

Aparece en el centro del mapa. Si ahí hay agua o un árbol, aparece en el lugar libre más cercano.

## Ver el mapa en el juego

Guarda y avísame: lo importo. Para probarlo, en el pueblo ve a Opciones > **MAPAS DE TILED: SÍ** y sal por el portón; funciona también en la versión web. Cuando estén listos, pasan a ser los mapas de siempre.

Para importar a mano:

```
godot --headless --path . --script tools/import_tiled_map.gd -- bosque
```

Esto escribe `scenes/maps/bosque.scn`. Las plantillas se rearman con `tools/build_tiled_templates.py`, pero **eso borra lo pintado**.
