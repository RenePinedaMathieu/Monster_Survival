# Audio assets

El engine ya está integrado — el juego llama a `Audio.play_sfx("id")` en
cada evento (disparo, hit, level up, etc.) y `Audio.play_music("id")`
para los tracks. **Mientras no haya archivos en disco, no suena nada
pero tampoco crashea**. Podés dropear archivos de a poco.

## Buses de audio

Configurados en `res://default_bus_layout.tres`:
- **Master** (fader global)
- **Music** — para BGM (arranca -4dB para no tapar los SFX)
- **SFX** — para one-shots

El menú de opciones (`main_menu.gd`) ya tiene un slider Master. Después
agregamos sliders separados para Music/SFX.

## Fuentes CC-0 recomendadas (safe para Steam)

Todo esto es Public Domain, no requiere atribución (pero es bueno
darla igual en los créditos).

- **Kenney.nl "Interface Sounds"** — https://kenney.nl/assets/interface-sounds
  - Para UI hover/click, level up, card selected
- **Kenney.nl "Impact Sounds"** — https://kenney.nl/assets/impact-sounds
  - Para monster hit, player hurt, meteor impact
- **Kenney.nl "RPG Audio"** — https://kenney.nl/assets/rpg-audio
  - Para coin pickup, sword swing, XP pickup
- **Kenney.nl "Sci-Fi Sounds"** — https://kenney.nl/assets/sci-fi-sounds
  - Alternativa/complemento para shots
- **Freesound.org** (filtrar por CC0) para death cries, growls, ambient

**Música**:
- **Kevin MacLeod (incompetech.com)** — CC-BY (crédito requerido).
  Buenos temas: "Sneaky Adventure", "Comfortable Mystery", "Fluffing a Duck"
- **OpenGameArt.org** → filtrar por CC-0 loops. Buscar "adventure" o "action".

## Archivos que espera el sistema

Poné el archivo con el nombre exacto en la carpeta correcta. Cualquier
formato que Godot 4 acepte anda (`.wav`, `.ogg`, `.mp3`).

### Música (`assets/audio/music/`)

| Archivo | Cuándo suena |
|---|---|
| `menu_theme.ogg` | Menú principal, char select, shop |
| `gameplay_chill.ogg` | Waves 1-4, ritmo calmo |
| `gameplay_intense.ogg` | Wave 5+ |
| `boss_theme.ogg` | Wave con boss (cada 10) |
| `death.ogg` | (opcional) Death screen |

### SFX (`assets/audio/sfx/`)

**Player**
| Archivo | Cuándo |
|---|---|
| `player_shoot.wav` | Cada disparo del coin (KAY / LINA / Man ranged) |
| `player_melee.wav` | Cada swing de AXEL |
| `player_hurt.wav` | Cuando recibís daño |
| `player_death.wav` | Muerte del player |

**Monsters**
| Archivo | Cuándo |
|---|---|
| `monster_hit.wav` | Cada golpe recibido |
| `monster_death.wav` | Muerte de enemigo regular |
| `monster_windup.wav` | (opcional) Telegraph antes del ataque |
| `boss_spawn.wav` | Cuando aparece un boss |
| `boss_death.wav` | Cuando muere el boss |

**XP + Coins**
| Archivo | Cuándo |
|---|---|
| `xp_pickup.wav` | Recoger orb de XP |
| `coin_pickup.wav` | (futuro) Recoger monedas |

**Progression**
| Archivo | Cuándo |
|---|---|
| `level_up.wav` | Al subir de nivel (mientras aparece el modal) |
| `card_hover.wav` | (opcional) Hover sobre carta de upgrade |
| `card_selected.wav` | Al elegir una carta |

**UI**
| Archivo | Cuándo |
|---|---|
| `ui_hover.wav` | Mouse encima de botón |
| `ui_click.wav` | Botón presionado |

**Waves**
| Archivo | Cuándo |
|---|---|
| `wave_start.wav` | Al arrancar una wave |
| `wave_clear.wav` | Al limpiar todos los monstruos de una wave |

**Special weapons (futuro)**
| Archivo | Cuándo |
|---|---|
| `meteor_whoosh.wav` | Meteoro cayendo |
| `meteor_impact.wav` | Impacto del meteoro |
| `sword_swing.wav` | Espada voladora atacando |

## Prioridad para arrancar

Si querés escuchar algo AHORA con mínimo esfuerzo, bastan estos 8:

1. `player_shoot.wav` (Kenney Interface o Sci-Fi)
2. `player_hurt.wav` (Kenney Impact)
3. `monster_hit.wav` (Kenney Impact)
4. `monster_death.wav` (Kenney Impact — algún crunch)
5. `xp_pickup.wav` (Kenney Interface o RPG — algún "coin" bell)
6. `level_up.wav` (Kenney Interface — arpegio o power-up)
7. `ui_hover.wav` + `ui_click.wav` (Kenney Interface)
8. `gameplay_chill.ogg` (Kevin MacLeod, agregar CC-BY a créditos)

## Formatos

- **SFX**: `.wav` (no comprimido, mejor calidad para archivos cortos)
  - Godot importa por default como Sample (bien para one-shots)
- **Música**: `.ogg` (Vorbis, comprimido, para loops largos)
  - En Godot: seleccionar el `.ogg` → panel Importar → marcar **"Loop"** → Re-import

## Créditos

Cuando publiques agregá al ending / créditos del juego:
- Los packs de Kenney (con licencia CC-0)
- Los tracks de Kevin MacLeod (con licencia CC-BY 4.0)
