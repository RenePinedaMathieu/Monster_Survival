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

El resto del mapa ya tiene el suelo de base (pasto o arena) para pintar encima, y agua debajo de todo.

## Agua (lagos, ríos, charcos)

Debajo de todo el mapa hay agua (la capa `water`). El suelo se pinta encima, y donde se abre un hueco en el suelo se ve el agua. Las orillas salen solas con el **pincel de terreno**:

1. **Abre los terrenos:** Ver > Vistas y barras de herramientas > **Conjuntos de terrenos**.
2. **Elige la capa** del suelo en el panel Capas:
   - Bosque y pantano: `main_space` (el pasto).
   - Desierto: `sand` (la primera, la de arena).
3. **Elige el terreno:** en Conjuntos de terrenos, toca la pestaña del tileset **Water_coasts**. Elige **Pasto y agua** (en el desierto, **Arena y agua**) y haz clic en el color **Sin pasto** (o **Sin arena**).
4. **Pinta:** con el pincel de terreno (tecla **T**) pinta donde quieras el agua. Se abre el hueco con su orilla.
5. **Corrige:** para rellenar, elige el color **Pasto** (o **Arena**) y pinta encima.

**Orilla de tierra** (bosque y pantano, como en el ejemplo), entre el pasto y el agua:
1. En la capa `ground`, con **Tierra y agua > Tierra**, pinta un poco más grande que el lago.
2. Con **Sin tierra**, pinta el agua un poco más chica que el hueco del pasto.

**Caminos de tierra:**
1. Capa `ground`, **Tierra**, por donde va el camino.
2. Capa `main_space`, **Sin pasto**, encima del mismo camino.

El agua choca sola; la orilla de tierra se camina.

## Capas: piso y objetos

- **Piso:** todas las capas de abajo (agua, suelo, manchas, pasto, enredaderas…). El héroe camina encima. Las capas de agua se llaman `water…` o `Agua…`.
- **Piso por nombre:** las capas con `hongo`, `pasto`, `grass` o `flor` en el nombre se dibujan siempre debajo de los personajes y no chocan, aunque estén arriba de las de objetos. Ahí van los hongos, matas y flores que se pisan.
- **Zona lenta:** las capas con `slow` o `lento` en el nombre (como `Pasto_slow`) frenan a la mitad a todo lo que camina: héroe y monstruos terrestres. Los voladores no se frenan.
- **Objetos:** desde la primera capa llamada `objects`, `objects1`, `Objects4`, `Objetos` o `Arboles` hacia arriba. Cada objeto tiene altura: el héroe pasa por detrás de la copa de un árbol y por delante del tronco.
- **Un objeto por grupo:** el juego toma como un solo objeto las baldosas que se tocan en una misma capa. Si dos árboles se tocan, ponlos en capas de objetos distintas, como hace el ejemplo.

## Qué choca

Solo, sin pintar nada:
- **El vacío:** donde ninguna capa de piso tiene nada (afuera de la isla).
- **El agua**, también la de las orillas pintadas con baldosas de costa.
- **Según la capa del objeto:**
  - `Arboles`: choca la base de todo lo que pongas ahí (troncos, cactus, palmeras, rocas).
  - `Objetos`: no choca nada (hongos, pasto, flores, huesos chicos).
  - Las capas `objects…` de los packs: choca la base de lo grande.

**Para cambiar algo:** muévelo a la capa `Arboles` u `Objetos`, o usa la capa **`choque`** (arriba de todo, medio transparente):
- **Cuadro rojo:** no se pasa. Úsalo para acantilados, rocas en `Objetos`, lo que se escape.
- **Cuadro verde:** sí se pasa, aunque algo choque ahí. El verde gana a todo.

**Para ver qué choca:** la capa **`vista choque`** (la última, bloqueada) pinta de rojo exactamente lo que no se camina. Se actualiza cada vez que se importa el mapa; si Tiled no la refresca, cierra y vuelve a abrir el mapa.

## Archivos y carpetas

- **Un mapa por carpeta:** cada uno con su nombre (`bosque/bosque.tmx`, `desierto/desierto.tmx`, `pantano/pantano.tmx`). Para empezar uno desde otro, avísame y lo copio con las rutas bien.
- **No uses "Guardar como" hacia otra carpeta:** el mapa sigue apuntando a las baldosas de la carpeta vieja y se rompe.
- **No renombres ni muevas las carpetas `tiles`:** el juego busca ahí las imágenes.

## No cambiar

- El nombre de la capa `choque`. Si tu mapa no la tiene, agrégala: una capa de patrones llamada `choque`, con el tileset `tiles/choque.tsx` (Mapa > Agregar conjunto de patrones externo).
- El mapa no infinito.
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
