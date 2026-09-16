# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Vampire-Survivors-style survival game, Godot 4.7.2 (GL Compatibility renderer, mobile-friendly), Web export, with cosmetic multiplayer via Supabase Realtime. Auto-deploys to Vercel on every push to `main`. GDScript throughout, no external package manager.

Live: https://monster-survival.vercel.app · https://i-hear-you-delta.vercel.app

## Running / developing

There is no CLI build/test/lint toolchain — this is a Godot editor project.

- Open in Godot 4.7.2: *Import* → point at `project.godot` → Run (F5).
- Root scene is `res://scenes/main.tscn` (set via `run/main_scene` in `project.godot`).
- The game auto-connects to Supabase on boot using the credentials hardcoded in `autoload/supabase.gd` (anon key — safe to bundle client-side, this is intentional).
- To test multiplayer locally, run two Godot instances (Debug → run multiple instances, or open two editor windows) — each should see the other move via `Realtime.remote_move`.
- To test mobile controls without a device, use Godot's remote debug on a phone, or a browser dev-tools touch emulation on a Web export — `touch_controls.tscn` only receives events when `DisplayServer.is_touchscreen_available()` triggers touch-specific behavior (camera zoom).
- There are no automated tests. Verify gameplay changes by running the game in the editor.

### Deploy

`git push` to `main` triggers `.github/workflows/deploy.yml`, which headlessly exports a Web build with Godot 4.7.2, patches `index.html` with mobile viewport/touch-action meta tags, writes `vercel.json` with COOP/COEP headers (required for `SharedArrayBuffer`/WASM threading), and deploys to Vercel (project `i-hear-you`, team `renepinedamathieus-projects`). Docs-only changes (`**.md`, `.gitignore`, `LICENSE`) are excluded from triggering it. Requires repo secrets `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`.

**A broken Web export build breaks the live deploy** — be careful with anything that could fail `godot --headless --export-release`.

## Architecture

### Scene orchestration

`scenes/main.gd` (attached to `main.tscn`) is the top-level orchestrator. It:
- Kicks off Supabase anonymous auth and wires `Realtime` signals to spawn/move/despawn `remote_player.tscn` instances.
- Runs the wave loop directly (no separate wave-manager class): wave N spawns `BASE_MONSTERS + N * MONSTERS_PER_WAVE` monsters in a ring around the player, plus a boss every 5th wave. When `_monsters_alive` hits 0, it waits `WAVE_BREAK_SEC` and starts the next wave.
- Wires `player.gd` signals (`hp_changed`, `xp_changed`, `leveled_up`, `died`) to the HUD and to spawning `level_up_menu.tscn`.
- Sets `monster.target` directly to the local `Player` node at spawn time — monsters chase the player unconditionally from spawn, not only once they enter their `DetectionArea` (that Area2D is only a fallback if `target` is unset).

### Multiplayer model — client-authoritative, no shared enemies

Each client simulates its **own** monsters entirely locally; there is no authoritative server for game state. `Realtime` (`autoload/realtime.gd`) only broadcasts cosmetic state over one Supabase Realtime channel (`"world"`): `move` (position + facing, throttled to 130ms), `attack`, `presence` (join/leave). Other players you see are visual/companion only — they don't share your enemies or affect your run.

**Hard constraint carried over from a prior project (see `HANDOFF.md` §2 and §8): never call Supabase Realtime `track()` at broadcast frequency.** Presence ACKs pile up and kill the channel above ~7Hz. `track()` is called once for identity at channel join; everything per-frame (position) goes through `broadcast` instead, throttled to ~130ms in `send_move`.

`autoload/supabase.gd` handles anonymous auth (`sign_in_anonymous`) and generic PostgREST helpers (`rest_get`/`rest_upsert`). Anonymous-only auth is intentional for the alpha — no login flow.

### Player, combat, monsters

- `player.gd`: movement is manual (WASD/arrows, or the touch joystick via `TouchControls.move_input` → `set_touch_input`), but **attacking is fully automatic** — `_auto_fire()` targets the nearest monster in `AUTO_FIRE_RANGE` every `AUTO_FIRE_INTERVAL` (scaled by `atk_speed_mult`) and spawns `coin_projectile.tscn`. There are no manual attack inputs in the current loop despite `attack`/`shoot` InputMap actions still existing in `project.godot`.
- XP orbs (`xp_orb.tscn`) drop on monster death and fly to the player once inside `magnet_radius` (`_magnet_orbs`, polled every physics frame against the `"xp_orb"` group).
- Leveling triggers `level_up_menu.tscn`, which offers 3 random upgrades from `apply_upgrade()` (damage, atk_speed, move_speed, max_hp, hp_regen, magnet, multishot) — stats are multiplicative on top of the base constants at the top of `player.gd`.
- `monster.gd` runs an explicit state machine (`IDLE_WANDER → CHASE → WINDUP → STRIKE → COOLDOWN`) with a telegraphed windup (red tint, 400ms) before it can land a hit — this is the core "dodge the windup" combat feel and should stay legible if timings change.
- Direction/animation system is 8-directional (`DIR_NAMES`/`DIR_VECTORS` in `player.gd`, mirrored in sprite folder names under `assets/sprites/Man/`). `_vec_to_dir()` is the canonical angle→direction-index mapping; reuse it rather than re-deriving direction logic elsewhere.

### World generation

`world.gd` builds the map procedurally in code at `_ready()` (no baked TileMap): tiles a grass region as individual `Sprite2D`s across an 80×80 grid, scatters props (trees/stones/etc.) randomly outside a no-spawn radius around the origin, and builds 4 invisible `StaticBody2D` border walls at `WORLD_BOUND`. Solid props get a `StaticBody2D` + `CircleShape2D` anchored at the sprite's base for collision.

### Collision layers

- Layer 1: player
- Layer 2: monster
- Layer 4: world statics (trees, solid rocks, border walls)

Player and monster physics masks target layer 4 (world collision). Player attack area and coin projectiles mask layer 2 (hit monsters).

## Conventions (from README)

- Scenes live in `scenes/`, autoloads in `autoload/`, assets never loose at repo root.
- Use `##` doc-comments in `.gd` files when behavior isn't obvious from the name (this repo leans on them heavily for non-obvious game-feel decisions — follow that pattern rather than leaving tuning constants unexplained).
- Signals are named in past tense (`died`, `hp_changed`, `leveled_up`).
- Don't push large features directly to `main` — open a PR so the deploy workflow runs a preview first.
- Never land a commit that breaks the Web export build.

## Context worth knowing before touching certain areas

`HANDOFF.md` documents hard-won lessons from a prior React/Canvas iteration of this same game (same Supabase backend) and is worth reading before touching Realtime, tilesets, or the wolf/monster AI tuning — notably: Wang-tileset assets from PixelLab are column-major indexed (not row-major), and specific combat tuning values (windup/pounce timings) were iterated on hard and shouldn't be re-guessed from scratch.

`tools/painter.html` is a standalone (non-Godot) map-layout painter tool from the prior project, kept for quickly sketching tile layouts; `assets/layouts/current.json` is a layout it can produce (row-major cell grid, `0`=void/`1`=grass/`2`=water) — not currently wired into `world.gd`'s procedural generation.
