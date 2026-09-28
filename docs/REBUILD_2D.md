# The 2D rebuild: architecture and contracts

The street game moves from 3D to **top-down 2D** (GTA 1/2, Hotline Miami, Door Kickers): you
see the city from straight above, walk into shops (their roof fades away), and deal with people
face to face instead of through menus. Think *The Godfather II*, but 2D. This file is the
contract between the pieces: if you build one piece, build it to this, and don't touch the others'
files.

The simulation (`scripts/core/game.gd`, `syndicate.gd`), the networking (`scripts/net/net.gd`),
the city plan (`scripts/world/city_plan.gd`) and the save format stay. The old 3D world
(`scripts/world/*.gd` other than `city_plan.gd`) is being replaced; the last 3D version is
commit `e9dd6d7` (`git show e9dd6d7:game/scripts/ui/hud.gd` etc. for reference).

## 1. Look and feel

- **Lower Manhattan, 1929, from a rooftop.** Muted warm brick and tar roofs; cool slate
  asphalt and Belgian-block cobbles; pale concrete sidewalks with curbs; cream and oxblood awnings;
  black cars; men in dark suits and fedoras. At night: deep blue, amber lamp pools, lit windows
  spilling onto the sidewalks, wet streets shining in the rain.
- **Dense and lived-in.** Every sidewalk has something on it: lamps, hydrants, mailboxes,
  police call boxes, ash cans, newsstands, benches, pushcarts, crates. Every shop shows its trade
  on the street: fruit stands, a barber pole, café tables, fish on ice. Roofs have chimneys, water
  towers, skylights, laundry lines. Nothing floats, nothing overlaps wrongly, edges line up.
- **Readable first.** The player, their men, cops and doors must pop at a glance. Family
  colours are the main code (awnings, hat bands, crew rings).
- **Light from the north-west.** Every shadow falls down-right (+x, +y). Buildings cast
  shadows proportional to their floors; props and people cast small soft ones.
- **No outlines everywhere.** Shapes are flat colours with a slightly darker edge and a soft
  shadow, plus a highlight on top where it helps. Use `Draw.*` helpers: the renderer has no 2D
  MSAA, so filled shapes need the anti-aliased edge they add.

## 2. Units, layers, drawing

- `W.M = 48` pixels per metre. The plan is in metres (x east, z south); the world is in pixels:
  `W.p(x, z)`, `W.pa([x, z])`, `W.door(biz)`, `W.lot_rect(lot)`, `W.front_dir(yaw)`.
- Facing: node `rotation` 0 = east (+x). Characters and cars are drawn facing +x.
- **Canvas layers** (the World sets them up):
  - `0` world: ground, interiors, props, items, people, cars, awnings. At night it is multiplied by
    the lightmap (layer 1).
  - `1` the lightmap overlay (World's `Lighting`): ambient colour plus every light's glow.
  - `2` roofs: roof shadows, roofs, roof props. Not lit by lamps; `CityRoofs.set_night()` tints it.
  - `3` weather (screen space), `5+` the HUD.
- **z_index on layer 0** (`W.Z_*`): ground −100, road marks −96, sidewalk −92, interior floor −80,
  interior walls −70, low props −60, furniture −50, items −30, people 0, cars 10, high props
  (lamp heads) 20, awnings 30.
- **Lights** are data, not nodes: components return `lights()`, an Array of
  `{"pos": Vector2 px, "r": radius px, "color": Color, "e": 0..1.5, "shape": "round"|"rect"|"cone",
  "size": Vector2 (rect), "rot": float (cone direction), "flicker": bool}`. The World's lighting
  draws them into the lightmap. Draw the *lamp itself* (the bulb, the glass) in your own art, and
  brighten it with `set_night(night, wet)`.
- **Fonts in the world**: `W.font("serif"|"cond"|"sans"|"semi"|"deco"|"fell"|"fell_sc")`
  (MSDF, crisp at any zoom). In Controls: `W.ui_font(name)`.
- **Colours**: `Pal.*` (`scripts/world2d/pal.gd`). Shade them freely (`darkened`, `lightened`,
  `lerp`), but don't invent a new palette.
- **Performance**: static art draws once in `_draw()` (no `queue_redraw()` every frame). Split
  big static art into child `Node2D` chunks (about one per block) so Godot can cull them. Only
  small animated bits (water glints, flickering signs, smoke) redraw per frame. Target 60 fps with
  the whole city loaded on a laptop GPU.
- **Determinism**: decoration comes from `W.rng(seed)` or `Draw.hash01(x, y, s)` seeded by lot
  ids/positions, never `randf()`, so every player sees the same city.

## 3. The city plan (read `scripts/world/city_plan.gd`)

- 6 × 4 blocks, street centre lines every `PITCH = 48 m` (`x = i·48`, `z = j·48`), streets
  `STREET = 12 m` wide, sidewalks `SIDEWALK = 3.5 m` (the outer band *inside* each block rect).
  `plan.blocks[k] = {i, j, rect: [x0, z0, x1, z1], district}`: the block including its sidewalk.
- `plan.lots[k] = {id, kind, block, side (N/S/E/W/C/Q), center [x, z], size [width along the street, depth],
  yaw, floors (1..6), style (0..3), door [x, z] (on the sidewalk 1.2 m outside the front), shop: bool, district}`.
  Kinds: `tenement` (homes: roof only, not enterable), `courtyard` (the backyard in the middle of a
  block, ground level, fenced), `warehouse` (two on the quay), and businesses: `club`, `poolhall`,
  `precinct`, and the trades `bakery butcher grocer tailor barber cobbler pawnshop laundry restaurant cafe candy hardware drugstore cigar fish`.
- Street names: `NS_STREETS[i]` on `x = i·48`, `EW_STREETS[j]` on `z = j·48` (Bowery is `i = 2`:
  it has streetcar tracks; Orchard St. `i = 4` has the pushcart market). West St. is the quay.
- Waterfront: `plan.quay_rect = [x0, z0, x1, z1]` (planks), `plan.water_x` (the river starts), 
  `plan.piers[k] = {x0, x1, z0, z1, tip}`, the rum boat ties up at `piers[1]` at night. `plan.bounds` (Rect2, metres).
- Businesses: `Game.biz[k] = {id, lot, name, kind, owner_name, address, district, door, yaw,
  protector (family id or -1), owned_by, rate, value, speak (speakeasy in the back), stock, fear,
  defiance, envelope, unpaid, closed_until (>= Game.month: padlocked), hq_of, broken [item ids], weak}`.
  `Game.fam(id)["color"]` is a family's colour.

## 4. Component contracts

Each component is one file (or two) you own. The stub in the repo shows the exact API; keep
the signatures, replace the insides.

### Person2D: `scripts/world2d/person2d.gd`
A person from above. `setup(kind, look, family_color, extra)`, `set_motion(Anim, speed m/s)`
every frame, `action(name)`, `play(Anim)`, `carry(on)`, `set_weapon("" | "pistol" | "tommy" | "bat")`.
- Kinds: `boss` (you: dark three-piece, fedora with a hat band in the family colour, a white
  scarf or a flower), `aiboss` (a rival don: older, heavier, homburg), `crew` (suits or shirtsleeves
  and braces, flat caps or fedoras, a family-colour tie or armband), `cop` (NYPD 1929 navy tunic, peaked
  cap, brass buttons, nightstick), `fed` (trench coat, grey fedora), `ped` (men: caps and coats;
  vary a lot by `look`), `woman` (cloche hat, coat or dress), `kid` (newsboy cap, short), `newsboy`
  (with a bundle of papers), `shop` (shopkeeper: `extra.trade` picks white apron and baker's hat,
  butcher's striped apron, barber's white jacket, tailor's tape and waistcoat...), `recruit` (tough:
  rolled sleeves, flat cap), `smuggler` (peacoat, watch cap), `dealer` (Izzy: loud checked suit),
  `docker` (work clothes, cap, hook), `unionboss` (Red Mulrooney: red hair, no hat, big), `consigliere`
  (the mentor: old, grey hair, glasses, cardigan or dark suit), `bartender` (white shirt, vest,
  bow tie), `patron` (speakeasy crowd: flapper dresses, evening suits).
- Anims: IDLE (breathing), WALK/RUN (legs step out from under the body, arms swing; stride from
  speed), CARRY (both arms forward, a crate in front), TALK (gesturing hand), ARMS (arms crossed,
  loitering), DOWN (lying on the ground, dazed), DEAD (lying still, a dark pool spreading), SIT.
- Actions: `punch` (right arm jabs), `hit` (recoil), `shoot` (arm out, gun, muzzle flash),
  `yes`, `no`, `interact` (reach), `pickup`, `down`, `die`, `smash` (swing at an object), `threaten`
  (grab / point), `talk`.
- Size: shoulders ~26 px across. Hats matter most from above: fedora = brim ring + crown + band.
- Shadow: soft ellipse down-right in world space (undo the node's rotation for it).

### Portrait: `scripts/ui/portrait.gd`
`Portrait.draw(ci, rect, kind, look, family_color, extra, mood)` draws a head-and-shoulders bust
(front view) in the same style and from the same look seed as Person2D (same skin, hat, clothes),
on a painted backdrop. Moods: `""`, `angry`, `scared`, `happy`, `smug`. `Portrait.control(...)`
returns a Control that shows one. Used in dialogs (about 160 px), the family book (64–96 px), the
tutorial mentor (120 px).

### CarArt: `scripts/world2d/car_art.gd`
A 1920s vehicle from above, nose to +x. `setup(kind, body_color, family_color, seed)`, `size_m()`,
`set_load(0..10)` (crates on the bed, stacked in rows), `set_lights(night)` (lamps glow on the car),
`set_motion(speed, steer)` (front wheels turn, a little body roll).
Kinds: `truck` (the family truck: stake-bed Ford AA, cab in the family colour), `sedan` (Model A
Tudor, mostly black), `touring` (open top: seats and the driver's hat visible), `taxi` (Checker
yellow, roof light), `police` (black and white, a bell or lamp on top), `van` (panel van), `delivery`
(box truck with a painted trade sign). 1920s shapes: separate fenders over the wheels, running
boards, a long hood, a spare tyre on the back, headlamps on stalks.

### CityGround: `scripts/world2d/city_ground.gd`
`build(plan)`, `set_night(night, wet)`, `lights()`, `solids()`. Everything on the ground outside
the buildings:
- Streets: asphalt with worn patches and tar seams; the older streets (Mott, Mulberry, Eldridge)
  in Belgian block; streetcar tracks down the Bowery; crossings at every corner; manholes (steam
  at night), storm drains at the curbs; the odd pothole and puddle (shiny when wet).
- Sidewalks: concrete slabs with joints, a lighter curb and a gutter shadow, cellar doors and
  coal chutes in front of buildings, gratings, stoops where tenements are.
- Street furniture on every block, placed so it never blocks a shop door (`lot.door`) or a
  crossing: lamp posts (the light is in `lights()`), hydrants, mailboxes, police call boxes, fire
  alarm boxes, ash cans, benches, newsstands, a horse trough, trees here and there, pushcarts along
  Orchard St. (the market).
- Courtyards (`kind == "courtyard"`): dirt and weeds, fences, laundry lines, sheds, a privy, a cat.
- The waterfront: the quay's heavy planks and stone edge, bollards and cleats, rope coils,
  cargo nets, crate stacks, a derrick crane, the piers on pilings over the water, and the river
  (animated glints; darker at night; the rain dimples it).

### CityRoofs: `scripts/world2d/city_roofs.gd` (layer 2)
`build(plan)`, `update_owners()`, `set_night(night, wet)`, `set_inside(lot_id)`. Every non-courtyard
lot gets a roof: tar paper in strips or gravel, a parapet (brick or stone coping), chimneys with
soot, water towers on the taller ones (4+ floors), skylights, roof hatches, vents, pigeon coops,
laundry lines strung between roofs, fire escapes on the side-street faces (grated platforms and
ladders sticking out over the sidewalk). Each roof casts a shadow down-right, longer for more
`floors`. `set_inside(id)` fades that lot's roof (and its shadow) to ~10% over ~0.25 s so the interior
shows; `-1` brings it back. Taller neighbours stay solid.

### Shopfronts: `scripts/world2d/shopfronts.gd` (layer 0, `W.Z_AWNING`)
`build(plan)`, `update_owners()`, `set_night(night, wet)`, `lights()`, `solids()`. For every business
(`Game.biz`): an awning over the sidewalk in front of it, striped (cream and a colour), in the colour
of the family that protects or owns it (neutral when nobody); the shop's name painted on the awning's
valance and readable from above; the display windows' glow onto the sidewalk at night (`lights()`);
padlocked shops get a shutter and a "CLOSED BY ORDER" notice; your speakeasy shows a discreet door
and a man by it at night. And the trade's clutter in front: fruit and vegetable stands (grocer),
bread racks (bakery), barber pole (barber), café tables with chairs (cafe, restaurant: under
parasols in summer), fish on ice (fish), hanging meat hooks in the window (butcher), three brass
balls (pawnshop), laundry carts and bundles (laundry), a cigar-store Indian or a newspaper rack
(cigar), brooms and barrels (hardware), a gumball machine and kids (candy), the mortar and pestle
sign (drugstore), a tailor's dummy (tailor), a shoe on a bracket (cobbler). Clubs: a canopy, two
chairs out front, the family's colours. The pool hall: a "BILLIARDS" sign. The precinct: blue globe
lamps either side of the steps, "14TH PRECINCT". Keep the door (`lot.door`) and a 1.6 m path to it clear.

### Interiors (data): `scripts/world2d/interiors.gd` · InteriorArt (drawing): `scripts/world2d/interior_art.gd`
`Interiors.layout(lot, kind)` returns the floor plan (format documented at the top of the stub:
walls, doors, rooms, owner spot, items with ids, named spots). The stub is a working minimum; make every
kind its own place: the bakery (ovens and bread racks in back, a glass case of pastries), the butcher
(chopping block, a cold room with hanging sides of beef), the barber (chairs, mirrors, sinks),
the tailor (bolts of cloth, a cutting table, mannequins), the laundry (tubs, a mangle, pressing irons,
steam), the restaurant (tables with checked cloths, the kitchen), the café (espresso machine, small round
tables), the candy store (jars, a soda fountain), the drugstore (soda fountain, pharmacy counter, shelves of
bottles), the cigar store (humidor cases, newspapers, the back room with the numbers bank), the
pawnshop (cases of watches, instruments on the walls, the back room where Izzy keeps guns), hardware,
cobbler, fish market, grocer; the pool hall (four tables, a bar, a back room card game), the precinct
(the desk sergeant's high desk, benches, the captain's office, two cells), the warehouses (pallets of
crates by bay, a freight elevator, the office), the social clubs (espresso bar, card tables, the back
office: desk, safe, the map table, the phone, the family's portrait on the wall). Keep the item types
the game uses (listed in the stub) and their meaning; ids are indexes into `items`.
`InteriorArt`: `build(plan)` (lays out every `Game.biz` lot), `layout_of(lot_id)`,
`update_from_game()` (broken items shown smashed: shards, spilled goods, a cracked case; the back room
turned speakeasy: a bar, stools, a piano, tables, bottles; padlocked: dust sheets, dark), `set_night`,
`lights()` (ceiling lamps, a lit bar).

### HUD: `scripts/ui/hud.gd` (+ `scripts/ui/hud/*` for pieces)
A CanvasLayer the World creates (`hud.world = self`). What it shows, and the API the World calls:
- `refresh()`: re-read Game: family crest and name, **Wallet** (cash on you), **Stash** (dirty
  money at the club), **Bank** (clean money), men, guns and ammo, **Heat** (a police-badge style
  meter; at 100 the feds raid), date and time of day (sun/moon icon), weather, sit-down requests waiting.
- `toast(text, kind)`: kinds `info good bad warn deal money`, stacked, fade out after ~6 s, with an icon.
- `set_prompt(text, world_pos := Vector2.INF, key := "E")`: a small key-cap bubble ("[E] Talk to
  Izzy") floating over `world_pos` (convert with `world.get_viewport().get_canvas_transform()`), or
  bottom-centre when INF; `""` hides it.
- `converse(conv)`: the talk box (modal: the player stops): portrait on the left, name and role, the
  line in quotes, a few fact lines, an optional meter, numbered options. `conv = {"name", "role",
  "portrait": {"kind", "look", "color", "extra"}, "mood", "line", "info": [String], "meter":
  {"label", "value" 0..1, "mark" 0..1} (optional), "options": [{"text", "sub" (cost/effect, small),
  "icon" ("talk" "money" "fist" "gun" "leave" "crew" "buy" "booze" "badge" "deal"), "enabled",
  "action": Callable, "keep_open": bool}]}`. Keys 1–9 pick, Esc closes. `close_conversation()`.
- `set_meter(id, world_pos, value 0..1, mark 0..1, label, color)` / `clear_meter(id)`: small bars
  floating over people in the world (the shakedown fear meter over a shop owner, a crewman's health).
- `set_objective({"title", "detail", "target": Vector2 px or INF, "step", "of"})` and
  `clear_objective()`: the current goal, top-left under the money, plus an arrow at the screen edge
  pointing to `target` when it's off screen, and a marker on the minimap.
- `mentor_say(name, text, portrait, seconds := 8.0)`: the tutorial mentor's line, bottom-left, not modal.
- A **minimap** bottom-right: streets, blocks, businesses coloured by family, the player, their men,
  cops nearby, the objective, the boat when it's in; north up; rotates never.
- Modal panels it owns and toggles: `toggle_family()` (FamilyBook), `toggle_map()` (Don's View),
  `toggle_nation()` (the existing `scripts/ui/nation_map.gd`), `toggle_help()` (How to play: short
  illustrated cards, not a wall of text), `show_newspaper(month)` (the Daily Ledger), `show_arrest(cop_key, price)`
  (bribe / go quietly / run), `show_final()`, the pause menu (`escape()`: Resume, How to play,
  Settings, Save, Quit to menu). `is_modal()`, `in_jail()`, `jail_until` (seconds, `Time.get_ticks_msec()/1000`),
  `escape()`, `modal_key(keycode)` (the World forwards keys while a modal is open).
- Controls strip bottom-left (tiny, fades after a minute): `E use · F punch · G shoot · R sic ·
  V car · Tab family · M map · J country`.

### FamilyBook: `scripts/ui/family_book.gd` · Don's View: `scripts/ui/city_map.gd`
- **FamilyBook** (Tab; also the desk in your club): a leather-bound book, tabs down the side.
  *Family*: crew cards (portrait, name, rank, specialty `Rackets.TRAITS`, loyalty bar, wage, what he's
  doing, buttons for orders). *Rackets*: every shop that pays you or you own (trade icon, district,
  what it brings a month, envelope waiting, speakeasy stock), and the **crime rings**
  (`Rackets.ring_progress(family)`: own or protect every shop of a trade to get the perk).
  *Heat*: the case against you as a Bureau file (cards per piece of evidence, how to fix each, the
  buttons that exist: cleanup crew, reach the rat). *Rivals*: each family (colour, boss, men,
  shops, truce/war, word kept/broken) and sit-down offers waiting (shake hands / refuse); propose a
  deal. *Money*: last month in and out (bars), laundering switch, the legacy ranking.
- **Don's View** (M; also the map table in your club): the whole city from above, stylised like a
  planning map on the desk: blocks, streets with names, every business as a trade icon in its
  family's colour, clubs, the precinct, your men, rival crews, cops, the boat at night. Hover: a
  card (name, owner, pays who, how much). Click a business: actions: **Set waypoint**
  (`hud.set_waypoint(px)`), **Send a man to take it** (`Net.to_host("crew_task", [crew_id, "take", biz_id])`),
  **Guard it**, **Collect here**. Filters (all / mine / rivals / for sale). Pan and zoom. District names.
- Both read only `Game` and the world (`world.actors`, `world.local_actor`, `world.plan`) and act
  only through `Net.to_host(...)` requests (list in section 5).

### MainMenu: `scripts/ui/main_menu.gd` (+ `scenes/main.tscn`) · Settings: `scripts/core/settings.gd`
A title screen that sells the mood: a night street in the rain, lamps, a car passing, lit windows,
the title FAMIGLIA in Art Deco (`W.ui_font("deco")`), gentle music (`assets/audio/night.ogg`). Big
simple buttons: **New game**, **Continue** (if a save exists), **Play with friends** (host / join),
**How to play**, **Settings**, **Quit**. New game: name, family name, colour, rival families (1–7),
campaign length, pace, and a **Tutorial on/off** switch (default on; stored as `Game.cfg["tutorial"]`).
Settings (`Settings`, a static class saved to `user://settings.cfg`): master, music and effects volume
(create "Music" and "SFX" audio buses at start), fullscreen, UI scale, show controls strip. Keep every
flow and command-line switch the old menu had (`--autotest`, `--autohost`, `--players=`, `--autojoin=`,
`--name=`, `--family=`), and `Game.new_campaign` / `Net.*` calls the same way.

## 5. The World (agent A) and what it offers the UI

`World` (`scripts/world/world.gd`, a `Node2D`) builds the city from the pieces above, spawns
people (`Actor`, a `CharacterBody2D` with a `Person2D`) and vehicles (`Vehicle`, with a `CarArt`), runs
the host simulation and the networking. For the UI:
- `world.plan`, `world.actors` (key → Actor: `.position` px, `.kind`, `.family`, `.ref_id`, `.key`),
  `world.vehicles`, `world.local_actor`, `world.local_vehicle`, `world.cam` (Camera2D),
  `world.audio.ui(name, db)` (UI sounds: `tick`, `paper_open`, `paper_close`, `page_turn`,
  `coins_pay`, `coin`, `click_wood`, `chest_open`, `discover`, `whistle`), `world.interiors` (InteriorArt).
- Requests the UI may send (`Net.to_host(method, args)`):
  `crew_task [crew_id, task, target]` (tasks: `follow`, `guard` (target = biz id), `collect` (biz id:
  that district), `booze` (crates a month), `idle` (back to the club), `take` (biz id: go and shake it
  down / take it from a rival)); `toggle ["support_jailed" | "launder_on"]`; `respond [deal_id, accept]`;
  `propose [family_id, terms]` (terms `{kind: "truce"|"tribute"|"alliance", months, amount, against}`);
  `cleanup [evidence_id]`; `reach [evidence_id]`; `nation [...]` (see `World._nation`); `save []`.

## 6. Wording (every string a player reads)

Short, plain, second person, present tense. One idea per sentence. Numbers with `$` and commas.
Say what a thing does, not how the system works. The same words everywhere:
**Wallet** (cash on you, lost if you're knocked down), **Stash** (the family's dirty money, at the club),
**Bank** (clean money: buys businesses), **Heat** (how much the law has on you), **Men**, **Rackets**
(shops that pay you), **Fronts** (shops you own: they launder the Stash into the Bank), **Speakeasy**.
Good: "Offer protection · $90 a month". "He won't pay. Scare him: break something." Bad: "Protection
pitch success probability depends on fear and reputation."

## 7. Testing your piece

Godot 4.7.1 is at `/usr/local/bin/godot` (or download `Godot_v4.7.1-stable_linux.x86_64.zip` from the
godotengine/godot GitHub releases). In a fresh checkout run `godot --headless --path game --import`
once (20 s). Then render a test scene to PNG and look at it:

```
xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --path game res://tools/test/test_<piece>.tscn
```

Put your test scene and script in `game/tools/test/` (`test_<piece>.tscn` + `.gd`): set up what
you need (`Game.new_campaign({"seed": 1923, "families": 4}, [{"peer": 1, "name": "Alex",
"family_name": "Vitale", "color": "#c42828"}])` gives you a city and businesses), wait ~20
frames, save `get_viewport().get_texture().get_image().save_png(path)`, quit. Look at every shot
critically and iterate: alignment, overlaps, readability, consistency with the palette, at day
and at night, zoomed in (`Camera2D.zoom = 1.4`) and out (`0.6`). Check the output for
`SCRIPT ERROR` and warnings. Software rendering is slow: keep test scenes small.

GDScript style: Godot 4 typed GDScript, tabs, `class_name` for shared classes, no new autoloads,
no edits outside your own files (ask in COORDINATION.md "Requests" instead). Commit with a clear
message when your piece works.
