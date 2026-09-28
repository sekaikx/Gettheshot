# Famiglia (prototype)

A grounded Mafia-empire game for **1 to 8 players**, made in **Godot 4.7**. You walk the
streets of 1920s New York as the boss of a crime family, top-down. Every door and every person
is something you can deal with. Past New York there's the country: cities to take, smuggling
routes to buy, convoys to run and hijack.

Solo play puts you against AI families. With friends, each player founds a family (or joins
a friend's as underboss), and AI families fill the rest of the city. Players who join a
running campaign take over an AI family. Rejoining with the same name gives you your seat back.

## Run it

1. Install **Godot 4.7** (standard, not .NET).
2. Import `game/project.godot` and let it import once, then press **F5**.
3. **PLAY SOLO**, or **HOST A GAME** (friends use **JOIN** with your IP; the port is 24880,
   so forward it for internet play), or **CONTINUE** the saved campaign.

Campaign length: *1929 to 1933* (the Crash and Repeal, about 2.5 hours at the default pace) or
*1923 to 1933* (all of Prohibition). The host autosaves every three months and on quit.

## Controls

| Key | |
|---|---|
| WASD | walk (Shift sprint, Alt stroll) |
| E | talk / use: shop doors, cops, recruits, rival bosses, your men, crates, the truck, the river |
| F | punch · **G** pistol (needs a gun and ammo, and it's loud) · **R** send your men at the person you face |
| V | get in / out of the truck (W/S drive, A/D steer, Space brake) · **Q** drop a crate |
| Z / C, scroll, right-drag | turn and zoom the camera |
| Tab | the family: crew orders, businesses, **THE CASE** (evidence), sit-downs, the books |
| J | the country: cities, routes, capos |
| M | the city map · **N** the newspaper · **H** help · Esc menu |

## What's in it

**The street (New York, walked in person)**
- A generated Lower Manhattan: 24 blocks in five districts (Hell's Kitchen, Garment District,
  Little Italy, Lower East Side, Waterfront), with brick and plaster tenements, lit windows,
  water towers, fire escapes, street lamps, piers, warehouses and the river. Day and night run
  once a month, with rain and fog.
- About 60 shops with owners who remember you. You can **offer protection** (men standing behind
  you help), **lean on them** (the window gets smashed and people see it), **collect the
  envelope**, **buy the business** with clean money, or open a **speakeasy** in the back.
  Awnings take the colour of the family a shop pays.
- **Dirty and clean money**: the stash pays wages and bribes, and you buy property with clean
  money. Every shop you own launders a set amount a month. Cash you carry can be stolen if
  you're knocked down.
- **Booze**: at night a boat ties up at the middle pier. Buy crates, carry them to your truck,
  drive to your speakeasy and unload. Cops who aren't paid chase contraband.
- **Men**: hire muscle outside the pool halls. They follow you, fight for you, collect and
  guard. Unpaid men leave, and a jailed man whose family you don't support may flip.
- **The law**: patrolmen chase what they see (bribe, go quietly or run), you can buy them one
  at a time or buy the precinct captain, and the feds raid at 100 heat.
- **Guns**: Izzy outside the pawnshop sells .38s, ammo and, from 1928, Thompsons.
- **Evidence** (Tab → THE CASE): heat is the sum of a real file. The file holds named witnesses
  (the shopkeeper who saw it), a patrolman's notebook, your gun, the books, bodies and informants.
  - Pay or scare a witness at his shop.
  - Buy the cop and his notebook disappears.
  - Throw the gun in the river at the end of a pier.
  - Burn the books at your club.
  - Send a cleanup crew for a body.
  - Reach a rat in custody.

**The country (J)**
- Nine cities: Chicago, Detroit, Atlantic City, Philadelphia, Boston, Cleveland, Kansas City,
  New Orleans, plus New York itself. Each has a local outfit and a ring showing who holds how
  much of it. Send men, guns and a capo; buy the local police; order hits on rival capos.
  Holding a city pays every month.
- Ten smuggling routes from Montreal, Windsor, Rum Row and Havana. Run convoys (New York crates
  fill your cellars, elsewhere they sell wholesale), buy the customs men and sheriffs so the
  route is yours (rivals pay a toll or get turned back), or put men on the road to hijack
  rivals' convoys. Prohibition agents seize some convoys.

**Rivals and diplomacy**
- AI families expand, retaliate, buy fronts, open speakeasies, run routes, send men to other
  cities and order hits. They hold grudges and offer (or demand) deals.
- Sit-downs with any boss, AI or human: truces, paying for peace, demanding tribute,
  alliances against a third family. Nothing is enforced; broken deals are remembered and
  printed in the paper.
- History: the Crash (October 1929) and Repeal (December 1933), when the scoring ends. Legacy =
  clean money, what you own, who pays you, the cities and routes you hold, your name, minus
  the case against you.

## Multiplayer

Host-authoritative ENet (`scripts/net/net.gd`, modelled on Keep Rolling's). The host runs the
rules and the AI and sends the campaign state when it changes, plus position snapshots at 10 Hz.
Each client moves its own boss and truck and asks the host to act. Solo uses the same code
path with an offline peer. Tested with 1, 2 and 3 players on one machine. Steam lobbies aren't
wired in yet: Keep Rolling's `steamworks.gd` + GodotSteam slot into `Net` the same way.

## Code map

| File | |
|---|---|
| `scripts/core/game.gd` | autoload `Game`: the campaign, economy, law, evidence, guns, deals, AI families, save/load |
| `scripts/core/syndicate.gd` | the country: cities, routes, convoys, ambushes, capos, hits |
| `scripts/net/net.gd` | autoload `Net`: solo / host / join, lobby, requests, state and snapshots |
| `scripts/world/world.gd` | the street: spawning, host simulation, crimes and witnesses, cops, requests |
| `scripts/world/city_plan.gd`, `city_builder.gd` | the city as data (seeded), then built as meshes |
| `scripts/world/actor.gd`, `person.gd` | people: movement, brains, fights / the dressed Woods models and their clips |
| `scripts/world/vehicle.gd`, `player_controller.gd`, `camera_rig.gd`, `ambience.gd` | trucks and traffic, your input, the camera, sound |
| `scripts/ui/*` | HUD and dialogs, family ledger, city map, country map, main menu |

**Tests**: `godot res://scenes/main.tscn -- --autotest --shot=/tmp/f` plays solo and exercises the
systems (protection, vandalism, a shooting, convoys, an ambush, a route, a hit, months passing),
saving screenshots. Networking: `-- --autohost --players=2 --mptest` in one instance and
`-- --autojoin=127.0.0.1 --mptest` in another.

## Assets and licences

- People, hats aside: the owner's own low-poly villager, woman and elder from **Woods**
  (`assets/models/characters/LICENSE_Villager.txt`), rigged on the KayKit skeleton, with the
  **Quaternius Universal Animation Library** (CC0) retargeted in Woods.
- Rain, murmur, music, UI and fight sounds: the owner's own Woods / Keep Rolling audio. The
  gunshot, glass, engine and whistle were synthesised for this game.
- City props, cars, lamps, crates: **Kenney** City Kits, Car Kit, Mini Market (CC0, `assets/kenney/*/License.txt`).
- Asphalt, pavement, brick, plaster, planks, concrete, corrugated iron: **Poly Haven** (CC0,
  `assets/textures/LICENSE_*.txt`).
- Fonts: Fraunces and Barlow (SIL OFL, `assets/fonts/OFL_*.txt`).
- Deliberately **not used**: Keep Rolling's *Low Poly Megapolis* city models (Unity Asset Store
  licence; they can't sit in a public repository) and the Sketchfab fan model in Woods.
