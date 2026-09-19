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

## Créditos que agregar al juego (final release)

- Sound Effects: Kenney (kenney.nl) — CC-0
- Music: (pendiente — quizás Kevin MacLeod si sumamos su música,
  requiere CC-BY)
