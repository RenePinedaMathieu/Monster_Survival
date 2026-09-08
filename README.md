# Monster Survival

Survival estilo Vampire Survivors, Godot 4.7.2 + Web export, con multiplayer via Supabase Realtime. Auto-deploya a Vercel en cada push a `main`.

**Jugalo ya**: https://monster-survival.vercel.app · https://i-hear-you-delta.vercel.app

---

## Stack

- **Engine**: Godot 4.7.2 (GL Compatibility, renderer mobile-friendly)
- **Lenguaje**: GDScript
- **Backend**: Supabase (auth anónima + Realtime WebSocket para multiplayer)
- **Deploy**: GitHub Actions → Vercel (`i-hear-you`), same URL sirve web y mobile
- **Controles**: WASD/flechas en PC, joystick táctil dinámico en teléfono

---

## Arrancar en local

Necesitás **Godot 4.7.2** (los templates de export para Web si vas a exportar).

```bash
git clone https://github.com/RenePinedaMathieu/Monster_Survival.git
cd Monster_Survival
```

Abrí Godot → *Import* → apuntá a `Monster_Survival/project.godot` → *Run* (F5).

La scene raíz es `res://scenes/main.tscn`. Se auto-conecta a Supabase con las credenciales que están en `autoload/supabase.gd`.

---

## Estructura

```
scenes/
  main.tscn              # Scene raíz. Orquesta waves, multiplayer, wire de signals.
  player.tscn            # CharacterBody2D, auto-fire, XP, level-up.
  monster.tscn           # State machine: wander → chase → windup → strike → cooldown.
  world.tscn             # Genera tiles + props (arbol/piedra) + border walls.
  hud.tscn               # HP, XP, wave, timer, minimap.
  minimap.tscn           # Radar top-right, centrado en el player.
  touch_controls.tscn    # Joystick dinámico para mobile.
  level_up_menu.tscn     # Modal con 3 cartas de upgrade random.
  xp_orb.tscn            # Gema que dropea al matar monster.
  coin_projectile.tscn   # Proyectil que dispara el auto-attack.
  remote_player.tscn     # Otro player conectado via Realtime.

autoload/
  supabase.gd            # Auth anónima + REST helpers. Registrado como global.
  realtime.gd            # WebSocket a canal "world". Signals de move/join/leave.

assets/
  sprites/Man/           # Personaje 8-direcciones (idle + run).
  sprites/monsters/      # Pipoya monster pack.
  tiles/                 # Tileset base.
  props/                 # Arbol, piedra, chest, skull, sign.
  ui/                    # ui_coin.png (usado como proyectil y XP orb).

.github/workflows/
  deploy.yml             # Instala Godot, exporta Web, pushea a Vercel.
```

---

## Loop del juego (Vampire Survivors)

- **Movimiento**: WASD/flechas o joystick táctil.
- **Ataque**: auto-fire al monster más cercano cada 0.65s. Sin botones.
- **XP**: los monsters droppean orbs (azul/verde/morado según tier). Al entrar al magnet radius del player vuelan hacia él.
- **Level up**: al llenar la barra aparece un modal con 3 upgrades random (damage, atk_speed, move_speed, max_hp, hp_regen, magnet, multishot). Elegís uno.
- **Waves**: base 8 + 4 por wave. Cada 5 waves cae un boss.
- **Muerte**: pantalla se reload con delay corto.

---

## Multiplayer

Cada cliente maneja SUS PROPIOS monstruos (no hay servidor autoritativo). Realtime sólo broadcastea:

- `move`: posición + facing dir cada 130ms
- `attack`: dispara animación
- `presence`: quién está en el canal

Los otros players son cosmético/compañía, no comparten enemigos. Esto simplifica mucho el netcode y evita necesidad de rollback.

**Signals importantes en `autoload/realtime.gd`**:
- `remote_join(uid, meta)`
- `remote_leave(uid)`
- `remote_move(uid, x, y, facing, dir)`

---

## Deploy

Cada `git push origin main` dispara el workflow:

1. Descarga Godot 4.7.2 headless en Ubuntu
2. Descarga export templates de Web
3. Corre `godot --headless --export-release Web build/index.html`
4. Post-procesa `index.html` para inyectar viewport meta + touch-action:none (mobile)
5. Copia `vercel.json` con headers COOP/COEP (necesarios para SharedArrayBuffer)
6. `vercel deploy --prod`

Requiere 3 secrets en el repo (`Settings → Secrets → Actions`):

- `VERCEL_TOKEN` — token de Vercel con acceso al team `renepinedamathieus-projects`
- `VERCEL_ORG_ID` — `team_iNgM1K9AbtTsPphE982x9bUT`
- `VERCEL_PROJECT_ID` — `prj_OnCGWd2ij6v5gY7OKx4rTXv4V338`

---

## Colisión / layers

- **Layer 1**: player
- **Layer 2**: monster
- **Layer 4**: world statics (árboles, piedras solidas, border walls)

Player mask = 4 (choca con world). Monster mask = 4 (choca con world). Player attack area mask = 2 (detecta monsters). Coin projectile mask = 2 (mismo).

---

## Convenciones al contribuir

- Escenas en `scenes/`, autoloads en `autoload/`, assets nunca sueltos en root.
- Comentarios en el `.gd` con `##` cuando el comportamiento no es obvio del nombre.
- Signals con nombres en pasado (`died`, `hp_changed`, `leveled_up`).
- **No pushear directo a `main` con features grandes** — abrí PR así corre el workflow y vemos el preview antes de mergear.
- Nada de commits que rompan el build de Web (rompe el deploy).

---

## Roadmap corto

- [ ] Meta-progression: coins persistentes + hub de upgrades entre runs
- [ ] Weapon evolutions (arma nivel max + item = evolucionada)
- [ ] 3+ personajes con stats/arma inicial distinta
- [ ] Boss cada 5 min con música y telegraph propio
- [ ] Coop 2p refinado (revives, XP share)
- [ ] Death screen con stats + leaderboard (Supabase)
- [ ] Daily run con seed fijo

Steam release cuando la retención esté sólida.
