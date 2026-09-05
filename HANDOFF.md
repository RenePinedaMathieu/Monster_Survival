# Caelvar — Handoff from Echora (React) to Godot 4

Context: prior project lived at `c:\proyectos\Echora` — same Supabase
backend, same Vercel deploy, same design intent. React frontend
retired because iso tile rendering + Wang autotile ended up being a
constant fight in Canvas 2D. Godot handles all of that natively.

This doc captures what I learned iterating that project so you don't
have to relive the same debugging sessions here.

## 1. Backend (unchanged — reuse the same Supabase project)

**Credentials live in the Supabase dashboard, NOT in a local file.**
The React project had `.env` with only `DISABLE_ESLINT_PLUGIN=true`;
the real vars (`REACT_APP_SUPABASE_URL`, `REACT_APP_SUPABASE_ANON_KEY`)
sit in the Vercel dashboard.

Grab them from:
- **Supabase dashboard** → Settings → API → Project URL + anon public key
- OR **Vercel dashboard** → project → Settings → Environment Variables

Put them in `autoload/supabase.gd` (constants at the top). The anon
key is safe to bundle client-side; the service_role key is NOT.

**Anonymous auth is intentional during alpha** — no passwords, no
email. If a Godot login flow is needed, keep it that way (memory
note preserved from the React project).

**Tables** (existing schema, don't recreate):
- `profiles(id uuid PK, username text)` — one row per user
- `pets(user_id uuid PK, name, level, upgrade_points, type)` — legacy
  from an even earlier iteration; the sprite render pulls `type`
  ("HYPE" / "CHILL" / …) to choose a pet variant

RLS: users can only read/write their own rows. Anon signups need
to be enabled in dashboard → Authentication → Providers → Anonymous.

## 2. Realtime multiplayer

**The one lesson worth ANY debugging time:** never call `track()` at
broadcast frequency. Presence ACKs pile up and the channel dies at
~7Hz. Correct split:

- Position, attacks, lobby ready → `broadcast` (fire-and-forget)
- Identity (name, outfit, gender) → `track()` once + on real changes

Throttle position broadcasts to ~130ms. Anything faster kills the
socket on Supabase's free tier.

The React version used a single channel called `world` with these
broadcast events:
- `move` `{ uid, x, y, facing, dir, running, gender }`
- `attack` `{ uid, facing, dir }`
- `lobby` `{ uid, ready, gender }`

Same protocol works verbatim from Godot — the WS payload is the
same JSON, just spoken by `WebSocketPeer` instead of the JS SDK.
`autoload/realtime.gd` in this repo implements it.

## 3. Deploy

**Vercel** worked fine for the React SPA. For Godot HTML5 exports
it still works BUT you need CORS headers for `SharedArrayBuffer`
(WASM threading). Put this at the repo root:

```json
{
  "headers": [
    { "source": "/(.*)",
      "headers": [
        { "key": "Cross-Origin-Opener-Policy", "value": "same-origin" },
        { "key": "Cross-Origin-Embedder-Policy", "value": "require-corp" }
      ]
    }
  ]
}
```

Without those headers, Godot Web crashes on start with `SharedArrayBuffer
is not defined`.

For desktop-only Godot builds, skip Vercel entirely — export .exe /
.app and ship via itch.io.

Alternative for hosting: Cloudflare Pages, Netlify, GitHub Pages all
support the same COOP/COEP headers.

## 4. Assets

Everything in `assets/` was copied from the Echora repo. Ready to
import into Godot as TileSets / AnimatedSprites.

### `assets/sprites/`

- **`Man/`** — man character, 8 directions × animations.
  - `animations/idle_v4/<dir>/frame_00X.png` — 8 frames per direction
  - `animations/walk_v4/<dir>/frame_00X.png` — 8 frames per direction
  - `animations/run_v4/<dir>/frame_00X.png` — 8 frames per direction
  - `animations/atk_sword_v4/<dir>/frame_00X.png` — 8 frames per direction
  - `animations/death/south/frame_00X.png` — 5 frames, south-only
  - Direction folders: `south, south-east, east, north-east, north,
    north-west, west, south-west`. Watch out for PixelLab export
    quirks — some directions have hash-suffix duplicate folders
    (`north-02363d1a`) — pick the alphabetically-first if a canonical
    one is missing. This bit me hard.
  - Frame size 112×112. Feet Y in-frame ≈ 88.

- **`woman/`** — woman character, same layout. Older sheets:
  - idle: 1 frame per dir (static — the man v4 sheets went animated)
  - walk/run: 6 frames per dir (man is 8)
  - atk: 7 frames per dir
  - death: 4 frames south
  - Frame size 108×108. Feet Y ≈ 86.

- **`wolf/`** — wolf enemy, 8 directions × animations.
  - idle static, walk 8f, run 6f, atk 8f, death 5f south
  - Frame 108×108, feet Y ≈ 86
  - Alpha variant is rendered at 1.4× the base size in-game.

- **`tent.png` / `tent_roof.png`** — tent, 2-layer Tibia-style:
  base is baked into the world (always visible), roof is a separate
  entity drawn per-frame that hides when the local player is inside
  the footprint. This trick is essential for the "walking into a
  tent reveals the interior" effect.

### `assets/tiles/`

Two new top-down tilesets (the iso sets from earlier didn't work
out — kept fighting Wang bit ordering). These:

- **`pretty_grass_to_water._grass_color_3F9B0B.png`** — 4×4 grid of
  96×72 tiles with a 1px gap. Grass↔water transitions. Each tile
  is 48px of "top face" (grass or water surface) + 24px of "front
  face" (dark strip that reads as a cliff / shore).
- **`pretty_grass_3F9B0B_to_stone.png`** — same layout, grass↔stone
  for cliff terrain later.

**Wang bit indexing**: PixelLab lays these tilesets out
**column-major** — tile mask N is at (col=N//4, row=N%4). This
took me an embarrassing amount of iteration to figure out. Do NOT
assume row-major or you'll get transitions in the wrong positions.

For Godot: import the PNG as a TileSetAtlasSource with 96×72 cells,
1px separation. Then set up a Terrain in the TileSet — Godot 4's
Wang autotile is a 3×3 or 2×2 mode, way cleaner than doing this
by hand. The 4-corner mask maps to Godot's peering bits.

### `assets/layouts/current.json`

The last map painted in the React painter tool. Format:
```json
{ "cols": 80, "rows": 60, "cells": "0100..." }
```
Each cell: 0=void, 1=grass, 2=water. Row-major.

You can convert this to a Godot TileMap layer with a small tool
script if you want the same island shape as a starting point.

### `tools/painter.html`

The painter tool from the React project — standalone artifact. Open
locally with any browser and it works. Kept because Godot's built-
in TileMap editor is fine, but this one might still be useful for
sketching layouts quickly outside the editor.

## 5. Game design (values I iterated hard on)

### Combat (feel took a long time to tune)

```
Player:
  HP 100, iframes 600ms
  Stamina 100 max
    Attack costs 22, roll 32, parry 18
    Regen 45/s idle, 18/s moving, 0 while rolling
  Dodge roll: 280ms, 360 px/s burst, 650ms cooldown
  Parry: 220ms window, 700ms cooldown
    On success: bite whiffs, wolf stunned 1200ms
    Opens riposte window: next attack lands 2× damage for 700ms
  Combo: 3 hits within 800ms of each other → finisher 1.5×
    Riposte + finisher stack (2 × 1.5 = 3× on a landed 3rd)
```

Attack window 380ms (frame count driven by CHAR_SPECS per gender).
Run speed = walk × 1.65.

### Wolves

```
Base: 2 HP, patrol 32 / chase 90 / flee 110 px/s
Alpha (last wave, first slot): 5 HP, 1.4× sprite, 1.5× bite damage
Bite: 18 dmg (normal), 27 (alpha)
Detect radius 260, aggro radius 120
Attack cooldown 280ms, stun on parry 1200ms
Pounce: 340ms committed lunge. LUNGE_OVERSHOOT=0 (landing exactly
  on the target's start position); JUMP_PEAK=5. Anything higher
  reads as "frog" instead of "wolf" — I got this feedback twice
  and only got it right on the 3rd try.
Death: 5-frame anim over 600ms, then hold on last frame 3.5s
  before disappearing.
```

Wave system: 3 waves × 4 wolves. Wave clears → 2.2s pause → next
wave spawns. Alpha only in wave 3.

### NPC ally (Mira)

```
60 HP, i-frames 500ms
Speeds: follow 150 / chase 210 px/s
  She always uses the run animation (outfit.running = true)
Chase radius 260, attack range 34px
Follow band 70-140px from player (dead zone stops the follow bob)
Attacks: 1 damage per swing, 520ms swing over 7 frames
Speech triggers:
  "Hi!" — once when player is nearby at match start
  "Wolf over there!" — edge trigger when a wolf enters chase range
    (4s cooldown)
  "Ugh..." — on death
```

### Wolves target the nearest live target (player OR NPC)

Refactored `stepWolves` to take a targets list not just the player.
Each wolf picks the nearest and aggros on it. Bites route damage
to the right kind via `onHit(wolf, target)` callback.

### Walkability

For iso-with-water: pre-baked a walkable mask via python. Sampled
the composite pixel colors — a pixel is walkable when it's NOT
water (teal, G≈B). Grass, cliff lines, dirt paths all counted as
walkable so terraces read like ramps.

In Godot: use TileSet's physics layers directly on tiles. Water
tiles get a `collision_polygon`, grass doesn't. Much cleaner than
the pixel-sampling hack I did in the React project.

### Camera

Dead-zone follow: player can move inside a 180×120 box centered
in viewport before the camera moves. Lerp factor 0.15. Screen
shake on hit (amp 6, ms 180 for player hit; amp 5, ms 160 for
swing landing).

## 6. Suggested Godot scene structure

```
Main.tscn
├── World (Node2D)
│   ├── TileMap (ground: grass + water via terrain)
│   ├── TileMap (decorations, occluders — trees etc.)
│   └── EntitiesLayer (YSort2D)
│       ├── Player (CharacterBody2D + AnimatedSprite2D)
│       ├── NPC/Mira (CharacterBody2D + AnimatedSprite2D)
│       └── Wolves (spawned by WaveSpawner)
├── UI (CanvasLayer)
│   ├── HPBar, StaminaBar, ComboCounter, WaveBanner
│   └── LobbyOverlay
└── Camera2D (drag_left=0.6 etc for dead-zone)
```

Enable **Autoloads** in Project Settings:
- `Supabase` → `res://autoload/supabase.gd`
- `Realtime` → `res://autoload/realtime.gd`

## 7. First milestone to hit

Before porting anything, prove the risky bits work:

1. Load Supabase creds into `autoload/supabase.gd`
2. Autoloads registered in Project Settings
3. Empty scene with a ColorRect + one line: `Supabase.sign_in_anonymous("test")`
4. See `[supabase] auth ok, uid=<id>` in the Godot output
5. Two Godot instances open → each moves a rectangle → the other
   sees it move via `Realtime.remote_move` signal

Once that works, the rest is fun (assets, tilesets, combat port).
The scary part was always auth + realtime working from a non-JS
client, and this repo already has the working code for that.

## 8. Things to NOT re-litigate

Absorbed from painful iteration:

- Anonymous auth for now. No password/email. Store the intent.
- Wang tilesets from PixelLab are **column-major** indexed.
- Wolf pounce doesn't overshoot. Peak jump 5. Not higher.
- Idle sprite has to check an explicit `moving` bool — frame index
  going through 0 does NOT mean "idle" during walk cycle (it's just
  the 0th walk frame). This caused visible mid-walk flicker.
- `track()` at broadcast frequency = dead channel. Don't.
- The Tibia-style tent needs TWO layers (base + roof), roof hides
  when the local player is inside the footprint.
- Test movement in-browser (via `run` skill or equivalent). Type-
  checking and unit tests confirm code shape, not feel.

## 9. Files still on the old repo worth grepping

`c:\proyectos\Echora\src\components\world\entities.js` has the full
wolf + NPC state machines. Not GDScript, but the STATE ORDER and
threshold values are drop-in.

`c:\proyectos\Echora\src\pages\WorldMap.js` lines 14-53 have every
combat tuning constant with the reasoning as comments.

`c:\proyectos\Echora\scripts\build_from_layout.py` shows the Wang
mask → tile lookup with the correct column-major indexing.

Godot's built-in Terrain will replace these procedural bakes, but
the intended VALUES translate directly.
