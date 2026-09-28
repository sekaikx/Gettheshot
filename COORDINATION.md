# Agent coordination: READ THIS FIRST

Two AI agents are working on this game at the same time. This file keeps us from doing the
same work twice or breaking each other's code. **Read it before you start, and again every
time you pull.** Update it (and push) whenever you claim, finish or hand back an area.

How to read the latest copy from any branch:

```
git fetch origin
git show origin/claude/gallant-volta-285f43:COORDINATION.md
```

## Who is who

| Agent | Branch | Status |
|---|---|---|
| **A: "gallant-volta"** (Claude Code, cloud) | `claude/gallant-volta-285f43` | active: 2D rebuild of the street game (see below) |
| **B: the other agent** | *please write your branch here* | *please write what you are doing here* |

**The repo's default branch is `claude/compassionate-lamport-0fmgxa`** (there is no `main`). The
owner merges finished work into it (PR #3 brought this file in). Branch from it, and merge it into
your branch before you open a PR.

## The rules

1. **Claim before you edit.** Put your name next to an area in the table below and push this
   file *before* you start on it. If the other agent already claimed it, pick something else, or
   write a request under "Requests" and wait.
2. **Push small and often.** Commit and push after every working change, so the other agent can see
   what you're doing and nothing gets lost.
3. **Files owned by the other agent: don't touch them.** Need a change there? Add a line under
   "Requests".
4. **Shared files** (marked *shared*): only small, additive edits (new functions, new fields
   with defaults). No renames, no reformatting, no moving code around. Note each edit in the log.
5. **Pull the other branch before you finish a task** (`git fetch origin`), and check for
   conflicts with your work.
6. Game data stays plain Dictionaries and Arrays (saves are JSON; the network sends
   `var_to_bytes`). New fields get defaults, so old saves and the other agent's code keep working.

## The plan (agent A)

The user asked for: better menus, simpler wording, a real tutorial, a city with props and
businesses you can *walk into* instead of menus, "Godfather 2 but 2D", a full game.

Agent A is rebuilding the street as a **top-down 2D game** (GTA 1/2 / Hotline Miami style):
- 2D city drawn from the existing `CityPlan`: streets, sidewalks, props, roofs with shadows,
  awnings and signs, and shop **interiors** you walk into (the roof fades when you're inside).
- Godfather 2-style shakedowns inside the shop: talk to the owner; if he refuses, smash his stuff
  or rough him up until his fear meter tips; every owner has a weak spot.
- The club as your office: the safe (stash), the desk (the family book), the map table (Don's View
  and the country), the phone.
- New HUD, dialogs with portraits, a minimap, a mission-style tutorial with a mentor, a
  Don's View city map, a new main menu, crew specialties, crime rings, favors, and taking down
  rival families.
- The simulation (`Game`, `Syndicate`), networking (`Net`) and save format stay. The 2D world
  replaces the 3D one.

## Who owns what

| Area | Files | Owner |
|---|---|---|
| 2D street world: rendering, people, cars, props, interiors, camera, controls, lighting, weather | `scripts/world/*`, `scripts/world2d/*` (new), `scenes/world.tscn` | **A** |
| HUD, dialogs, portraits, minimap, prompts, pause menu | `scripts/ui/hud.gd`, `scripts/ui/hud/*` (new), `scripts/ui/portrait.gd` (new) | **A** |
| Tutorial and objectives | `scripts/ui/tutorial.gd` (new), `scripts/core/objectives.gd` (new) | **A** |
| City map (Don's View), family book (Tab) | `scripts/ui/city_map.gd`, `scripts/ui/family_book.gd` (new) | **A** |
| Main menu, settings, lobby | `scripts/ui/main_menu.gd`, `scenes/main.tscn`, `scripts/core/settings.gd` (new) | **A** |
| New street mechanics: shakedowns, weak spots, crime rings, crew specialties, favors, taking down a family | `scripts/core/rackets.gd` (new), `scripts/core/favors.gd` (new) | **A** |
| Campaign rules and AI families | `scripts/core/game.gd` | *shared*: A adds hooks for the mechanics above |
| Names | `scripts/core/names.gd` | *shared* |
| Country layer: cities, routes, convoys, rail freight | `scripts/core/syndicate.gd` | *unclaimed*: B, take it if you like |
| Country map (J) | `scripts/ui/nation_map.gd`, `scripts/core/map_projection.gd` (new), `tools/map/*`, `assets/map/*` | **A** (claimed 2026-09-28 after nobody took it: baking the atlas plate from `tools/map/build_map.py`, putting it under the map, simpler panel wording). B: want it? Say so under Requests and A hands it over. |
| Networking | `scripts/net/net.gd` | *unclaimed* (A may need small additive changes for 2D snapshots) |
| Audio, music | `scripts/world/ambience.gd`, `assets/audio/*` | A for now (it lives in `scripts/world`) |
| Docs, README, trailer | `README.md`, `game/README.md`, `docs/*`, `trailer/*` | *unclaimed* (A updates the controls section at the end) |
| Balance and economy numbers | constants in `game.gd` and `syndicate.gd` | *unclaimed* |

**Agent B: please claim areas from the unclaimed rows** (or propose a different split under
"Requests") and push this file, so A sees it on the next fetch.

## Requests

*(to the other agent: "B → A: please add X to Y", with the date)*

- A → B: please tell us your branch and what you're working on in the table at the top.

## Log

*(newest first, one line per event: date, agent, what)*

- 2026-09-28 · A · Merged the finished 2D people (`scripts/world2d/person2d.gd`, `people/*`, `scripts/ui/portrait.gd`) and
  streets (`scripts/world2d/city_ground.gd`, `ground/*`). Still being built: shop interiors, shopfronts and roofs, cars,
  the HUD, the family book and Don's View, the main menu. Solo play now pauses while a panel is open.
  `game/tools/dev/test_all.sh` runs every check headless: run it before you push.
- 2026-09-28 · A · Claimed the country map (J): the atlas plate generator from the earlier session works; A is baking
  `assets/map/country_map.png`, adding `scripts/core/map_projection.gd` and simplifying `nation_map.gd`.
- 2026-09-28 · A · Pushed the playable 2D street: shakedowns, favors, the tutorial, raids, speakeasy nightlife, crew
  specialties, crime-ring perks (`scripts/world/*`, `scripts/core/rackets.gd`, `favors.gd`, small hooks in `game.gd`).
- 2026-09-28 · A · Pushed the 2D skeleton: `docs/REBUILD_2D.md` (architecture + contracts), `scripts/world2d/*` stubs,
  `scripts/core/rackets.gd`, new fields in `game.gd` (`biz.broken`, `biz.weak`, `crew.trait`, all with defaults for old
  saves), a plain HUD with the new API, and the Compatibility renderer. 8 builders are filling in the art and UI
  pieces; A is writing the 2D World (`scripts/world/*`).
- 2026-09-28 · A · Created this file. Starting the 2D rebuild on `claude/gallant-volta-285f43`.
