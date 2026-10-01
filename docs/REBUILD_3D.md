# The 3D rebuild: architecture and contracts

The street game is drawn in **real 3D, seen from a tilted overhead camera** (GTA 2 meets *The Godfather II*'s
Don's View, closer in). The 2D world (`scripts/world/*`, `scripts/world2d/*`) is still the
**simulation**: positions, physics, AI, shakedowns, networking, saves. It no longer draws. A 3D layer
(`scripts/world3d/*`) mirrors it every frame.

Why: all the game rules, the multiplayer sync and the headless autotests stay exactly as they are, while the
picture becomes 3D. Run `--view2d` to get the old picture back (handy for comparing and for bugs).

```
World (Node2D, the simulation)  ──mirrors──▶  View3D (Node3D, the picture)
  Actor  (CharacterBody2D)  ───────────────▶   Puppet3D  (wraps Person, the Quaternius cast)
  Vehicle (CharacterBody2D) ───────────────▶   Car3D     (period car meshes, scripts/cine/car_models.gd)
  Crate  (items)            ───────────────▶   Item3D
  plan + Interiors layouts  ───────────────▶   City3D, Interiors3D   (built once)
  CameraRig (Camera2D)      ───────────────▶   Camera3D  (focus + zoom copied, tilted)
  day/night/weather         ───────────────▶   View3D.set_light(...)
```

HUD panels, menus, the family book, maps, talk boxes: unchanged (Control nodes over the 3D picture).
Things that float over the street (prompts, meters, "!" marks, floating text) are placed with
`world.to_screen(px, height)`.

## 1. Coordinates

- The plan and `Game.biz` are in **metres**, x east, z south. The 2D world is in **pixels**
  (`W.M = 48` px per metre). **3D uses plan metres: x east, z south, y up.** A 2D point `p` is the 3D
  point `V3.pos(p)` = `(p.x/48, 0, p.y/48)`. Plan points `[x, z]` are 3D `(x, 0, z)` directly.
- Headings: 2D `rotation`/`yaw` 0 = east, increasing clockwise on screen. A model that faces **+Z**
  (every model in `scripts/cine`) gets `rotation.y = V3.yaw_y(yaw2d)`.
- The camera looks **north** (down -z) from the south at pitch 58 degrees: screen up = north. WASD stays
  world-aligned. `View3D.yaw` can turn the camera (not used yet).
- Light comes from the north-west: shadows fall to the south-east (`V3.SUN_DIR`).
- `V3` (`scripts/world3d/v3.gd`) has the conversions, `FLOOR_H`, `lot_height`, `mat()`, `glow()`.

## 2. The pieces and their contracts

| Piece | Files | Interface |
|---|---|---|
| **View3D** (glue) | `view3d.gd` | `setup(world)`, `to_screen(px, h)`, `to_world(screen)`, `metre_px(px)`, `set_light(night, dusk, wet, weather)`, `set_inside(lot)`, `state_changed()`, `begin_cinematic()` / `end_cinematic()`, `snap()` |
| **City3D** | `city3d.gd` (+ new files) | `build(plan)`, `set_night(night, wet)`, `set_inside(lot)`, `update_owners()`, `lot_height(lot)` |
| **Interiors3D** | `interiors3d.gd` (+ new files) | `build(layouts)` (the dictionaries of `Interiors.build`, pixels), `update_from_game()`, `set_night`, `set_inside` |
| **Puppet3D / Person** | `puppet3d.gd`, `scripts/cine/person3d.gd` (class `Person`) | `Person2D` forwards `set_motion / play / action / carry / set_weapon / set_ring` to `Person2D.mirror` |
| **Car3D** | `car3d.gd`, `scripts/cine/car_models.gd` | `sync_from(vehicle, delta)`, `set_load`, `set_night` |
| **Item3D** | `item3d.gd` | crates and cash on the ground |
| **Weather3D** | `weather3d.gd` | `set_kind(kind, night)`; rain, splashes, fog; the 2D lightning flash stays |
| **Marks** (HUD) | `scripts/ui/hud/world_marks.gd`, `float_text.gd`, `World._draw_marks` | use `world.to_screen` / `world.metre_px` |

How the World talks to the 3D layer: `World._enter_3d()` (builds `view3d`, hides the 2D art),
`_day_light()` (calls `view3d.set_light`), `_track_inside()` (`view3d.set_inside(lot)`),
`_on_state_changed()` (`view3d.state_changed()`). `world.to_screen(p, h)`, `world.mouse_world()` and
`world.metre_px(p)` work in both views.

## 3. Rules

- **Do not touch other people's files.** Shared files (`world.gd`, `person2d.gd`, `actor.gd`, `hud.gd`):
  only small, additive edits, noted in your final report.
- **The simulation is never in 3D.** No gameplay logic in `world3d/*`; it reads the World and draws.
  Everything must also work with `--view2d` and headless.
- **Determinism.** Decoration comes from `W.rng(seed)` or `V3.hash01`/`Draw.hash01` seeded by lot ids and
  positions, never `randf()`, so every machine builds the same city.
- **Performance.** Target 60 fps on a laptop with the whole city loaded, Compatibility renderer (no SSAO,
  no SDFGI, limited lights). Use `MultiMeshInstance3D` for repeated props (lamps, hydrants, windows,
  crates), merge static meshes per block, keep real `OmniLight3D`s to a pool that follows the camera
  (about 12) and fake the rest with emissive materials. Directional shadow only for the sun.
- **Read the data, don't copy it.** Rooms are drawn from the layout dictionary (`Interiors`), shops from
  `Game.biz`, so a smashed window or a new padlock shows without extra plumbing.
- **Look.** Lower Manhattan 1929: warm brick and tar, slate asphalt, Belgian block cobbles, cream and
  oxblood awnings, black cars, men in dark suits and fedoras; at night deep blue with amber lamp pools,
  lit windows, wet streets in the rain. Dense and lived in: every sidewalk has something on it. Family
  colours are the main code (awnings, hat bands, rings). Readable first: the player, their men, cops and
  doors must pop at a glance from the overhead camera.
- Keep GDScript typed where the code around you is typed; `godot --headless --path game
  res://tools/dev/check_scripts.tscn` must print `CHECK OK`.

## 4. Testing

```
# compile everything + the autotests, headless (run before every commit)
bash game/tools/dev/test_all.sh

# one real rendered run with screenshots (software GL, about 2 minutes): a_street.png, a_inside.png, ...
cd game
xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --resolution 1600x900 \
  --path . res://scenes/main.tscn -- --autotest --shot=/tmp/out/a
```

Give your piece its own test scene under `tools/test3d/` that builds just what it needs (see
`tools/test/test_ground.gd` for the 2D equivalents), renders a few shots to PNG, and quits. **Look at your
own screenshots** (open the PNGs) and fix what looks wrong before you report; then have a critical look at
the whole frame, not only your piece.
`Game.new_campaign({"seed": 1923, "families": 4}, [{"peer": 1, "name": "Alex", "family_name": "Vitale",
"color": "#c42828"}])` makes a campaign in a test scene.
