# Audio assets — Créditos y Licencias

## Kenney Interface Sounds (Audio/)
- Autor: Kenney (kenney.nl)
- Fuente: https://kenney.nl/assets/interface-sounds
- Licencia: CC-0 (Public Domain) — sin atribución requerida
- Uso comercial: sí, sin restricciones
- Contiene: click, back, confirmation, error, select, tick, toggle,
  pluck, bong, scratch, scroll, minimize, maximize, question, drop,
  glitch, glass, close, open, switch, footstep (múltiples superficies),
  impact (bell/generic/glass/metal/plank/plate/punch/soft/tin/wood).

## Kenney Impact Sounds (Audio/, mergeados)
- Autor: Kenney (kenney.nl)
- Fuente: https://kenney.nl/assets/impact-sounds
- Licencia: CC-0

## Kenney RPG Audio (Audio3/)
- Autor: Kenney (kenney.nl)
- Fuente: https://kenney.nl/assets/rpg-audio
- Licencia: CC-0
- Contiene: bookFlip, doorOpen/Close, drawKnife, dropLeather, chop,
  cloth, creak, handleCoins, handleSmallLeather, knifeSlice, metalPot,
  metalClick, metalLatch.

## Cómo funciona el mapeo en el juego

`autoload/audio.gd` mapea cada evento del juego (player_shoot,
monster_hit, level_up, etc.) a UNO o VARIOS archivos de estos packs.
Si es un array, elige uno al azar cada vez que suena — así los
enemigos no golpean todos con el mismo hit repetido.

Cuando agregues más audios, mantené el nombre exacto del archivo del
pack y editá `SFX_LIBRARY` en `autoload/audio.gd` para referenciarlo.

## Música (music/)

Tracks de **Kevin MacLeod** — https://incompetech.com — licencia
**CC-BY 4.0**. **REQUIERE ATRIBUCIÓN** en los créditos del juego.

| Archivo | Uso en el juego |
|---|---|
| `Comfortable Mystery 3.mp3` | Menú principal + death screen (fallback) |
| `Sneaky Adventure.mp3` | Gameplay chill (waves 1-4) |
| `Kick Shock.mp3` | Gameplay intenso (wave 5+) |
| `Voxel Revolution.mp3` | Boss theme (cada wave % 10 == 0) |

## Créditos obligatorios en el juego final

Al final del juego (créditos del ending, o menú de opciones → "About")
DEBE aparecer literalmente:

```
Music by Kevin MacLeod (incompetech.com)
Licensed under Creative Commons: By Attribution 4.0 License
http://creativecommons.org/licenses/by/4.0/

Tracks used:
- "Comfortable Mystery 3"
- "Sneaky Adventure"
- "Kick Shock"
- "Voxel Revolution"
```

Sound Effects: Kenney (kenney.nl) — CC-0, sin crédito requerido pero
igual les tiramos un guiño en los créditos.
