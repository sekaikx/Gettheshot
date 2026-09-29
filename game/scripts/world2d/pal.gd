class_name Pal
extends RefCounted
## The colours of the 2D city: Lower Manhattan, 1920s, seen from above. Muted, warm brick and tar
## against cool slate streets; amber lamps at night. Use these (or shades of them) so every
## piece of the city looks like one place.

# streets
const ASPHALT := Color("3a3c40")
const ASPHALT_WORN := Color("45464a")
const COBBLE := Color("4d4843")          # Belgian block on the older streets
const COBBLE_JOINT := Color("2f2c29")
const TRACK := Color("8a8680")           # streetcar rails
const PAINT := Color("d8d2c2")           # crossings, the odd painted line
const MANHOLE := Color("2a2a2c")
const GUTTER := Color("26272a")

# sidewalks
const SIDEWALK := Color("a59c8e")
const SIDEWALK_DARK := Color("8f8679")
const SLAB_JOINT := Color("7d7569")
const CURB := Color("c7bfb1")

# buildings, from above
const TAR := Color("3b3532")             # tar-paper roofs
const TAR_2 := Color("463e38")
const TAR_3 := Color("2f2c2a")
const GRAVEL := Color("5b534b")
const PARAPET_BRICK := Color("6e4636")
const PARAPET_STONE := Color("8c8478")
const BRICK := Color("7a4a3a")
const BRICK_DARK := Color("5a3629")
const PLASTER := Color("b8a58a")
const CHIMNEY := Color("7a5242")
const WATER_TOWER := Color("6b5238")     # cedar staves
const SKYLIGHT := Color("7f8f96")
const SHADOW := Color(0.02, 0.02, 0.05, 0.34)

# shopfronts
const AWNING_CREAM := Color("e9dfc7")
const AWNING_COLORS := [Color("7a2e2a"), Color("2e4a3a"), Color("2a3a5a"), Color("8a6a2a"), Color("5a3a5a"), Color("3a5a5a")]
const GLASS := Color("9fb4bd")
const GLASS_LIT := Color("ffd48a")
const SIGN_GOLD := Color("d9b25a")
const SIGN_BLACK := Color("1c1916")

# interiors
const FLOOR_WOOD := Color("7a5a3e")
const FLOOR_TILE := Color("c9c2b2")
const FLOOR_TILE_2 := Color("8a3a32")     # black-and-white or red-and-white tile
const WALL_IN := Color("d9ccb0")
const COUNTER := Color("5a3e2a")
const MARBLE := Color("dcd6cc")
const BRASS := Color("c9a54a")
const FELT := Color("2f5a3a")            # pool tables, card tables
const LEATHER := Color("5a2e22")

# the waterfront
const WATER := Color("20394a")
const WATER_DEEP := Color("16293a")
const WATER_NIGHT := Color("0b141c")
const PLANKS := Color("6b5642")
const PLANKS_DARK := Color("4e3e30")
const QUAY_STONE := Color("6e6a64")
const ROPE := Color("b59a6a")
const RUST := Color("7a4a2e")

# light
const LAMP := Color(1.0, 0.82, 0.55)     # sodium-ish incandescent
const WINDOW_WARM := Color(1.0, 0.78, 0.48)
const NEON_RED := Color(1.0, 0.3, 0.25)
const MOON := Color(0.55, 0.62, 0.85)
const NIGHT_AMBIENT := Color(0.16, 0.18, 0.32)

# people and cars (1920s): mostly dark cloth, a few browns and greys
const SUITS := [Color("25262b"), Color("2f2a26"), Color("3a3d45"), Color("4a4037"), Color("2a3040"), Color("5a5048"), Color("6a6258")]
const SKIN := [Color("f0c8a0"), Color("e0b088"), Color("c89468"), Color("a8744a"), Color("7a5234")]
const CAR_BLACK := Color("18181a")

# UI (shared with the HUD and menus)
const INK := Color("efe6d2")
const MUTE := Color("9b907c")
const GOLD := Color("d4a532")
const GOLD2 := Color("f0d58a")
const PAPER := Color("e6dcc3")
const PAPER_INK := Color("1c140c")
const UI_RED := Color("ff6b5b")
const UI_GREEN := Color("8fd19e")
const PANEL := Color(0.075, 0.063, 0.052, 0.94)
const PANEL_LINE := Color("4a3d2c")
