class_name UiKit
extends RefCounted
## The Famiglia UI kit: 1920s printed ephemera instead of a dark web UI.
##
## Everything here is static; nothing needs to be instanced:
##   var t := UiKit.theme()             # a whole Theme (buttons, labels, fields, tabs, bars...)
##   panel.add_theme_stylebox_override("panel", UiKit.card())
##   add_child(UiKit.key_prompt(["E"], "Talk to Sammy"))
##
## Textures live in res://assets/ui (made by tools/ui/make_ui_art.py, seeded). The 9-patch
## table NINE mirrors the margins that script prints. All 9-patches tile their middle
## (AXIS_STRETCH_MODE_TILE_FIT), so paper grain and deckled edges never blur or smear.
## Draw textures at 1:1 wherever possible (key caps 48 px, icons 32/64/128, portraits
## 120/168/240 wide) so the print stays crisp.
##
## Theme type variations (set Control.theme_type_variation):
##   Label: "DisplayLabel" (Limelight), "HeadlineLabel" (Playfair Black), "SubheadLabel"
##   (Playfair Bold), "TypeLabel" (Special Elite), "LedgerLabel" / "FigureLabel" (Courier
##   Prime), "EngraveLabel" (IM Fell English SC), "CaptionLabel" (IM Fell italic), "BodyLabel"
##   (IM Fell DW Pica, newspaper text), "SignLabel" (Rye), "PaperLabel" (cream ink for dark grounds).
##   PanelContainer: "CardPanel", "LedgerPanel", "LeatherPanel", "TelegramPanel", "DecoPanel",
##   "DecoNavyPanel", "NewsPanel", "SlipPanel", "StripPanel".
##   Button: "OptionRow" (a numbered dialog choice: bare typed text, pencil highlight on hover),
##   "TypeButton" (typed link, no stamp).
##   ProgressBar: "LedgerBar" (green ink hatch), "InkBar".

# ------------------------------------------------------------------------ palette
const PAPER := Color("e9dfc7")          ## aged paper
const PAPER_DARK := Color("d9ccae")     ## darker paper / manila
const MANILA := Color("cdb27e")         ## folder stock
const LEDGER_PAPER := Color("ece5cb")
const TELEGRAM_PAPER := Color("ecdcaa")
const NEWSPRINT := Color("ddd5bf")
const INK := Color("1e140a")            ## brown-black ink
const INK_SOFT := Color("4a3a28")       ## faded ink for secondary text
const INK_FADED := Color(0.118, 0.078, 0.039, 0.45)
const SEPIA := Color("5a3f24")
const OXBLOOD := Color("8b1e1a")
const OXBLOOD_DARK := Color("5e1411")
const NAVY := Color("2b3a55")
const BRASS := Color("b08d57")
const BRASS_LIGHT := Color("d6b67e")
const GREEN := Color("2f4a38")          ## bottle green (ledger ink, clean money)
const RULE_GREEN := Color("5c8c85")     ## printed ledger rules
const HIGHLIGHT := Color(0.84, 0.66, 0.30, 0.28)  ## pencil / highlighter wash

const UI_DIR := "res://assets/ui/"
const FONT_DIR := "res://assets/fonts/"

## Font roles -> files. font(role) returns these (cached).
const FONT_FILES := {
	"display": "Limelight-Regular.ttf",          # Art Deco display, posters, the title
	"headline": "PlayfairDisplay-Variable.ttf@900",      # newspaper headlines, names (Black)
	"headline_bold": "PlayfairDisplay-Variable.ttf@700", # subheads (Bold)
	"type": "SpecialElite-Regular.ttf",          # typewriter body text
	"ledger": "CourierPrime-Regular.ttf",        # figures, tables
	"ledger_bold": "CourierPrime-Bold.ttf",      # buttons, totals
	"engrave": "IMFellEnglishSC-Regular.ttf",    # small caps captions, map labels, tabs
	"body": "IMFellDWPica-Regular.ttf",          # newspaper columns
	"italic": "IMFellDWPica-Italic.ttf",         # captions, bylines
	"sign": "Rye-Regular.ttf",                   # hand-painted signs, adverts
}

## 9-patch table: texture, texture margins [l,t,r,b], expand margins [l,t,r,b] (the
## transparent shadow room outside the paper edge), content margins [l,t,r,b].
const NINE := {
	"card": {"tex": "panels/card.png", "m": [40, 40, 40, 40], "x": [16, 16, 16, 16], "c": [26, 22, 26, 24]},
	"paper": {"tex": "panels/paper.png", "m": [32, 32, 32, 32], "x": [12, 12, 12, 12], "c": [20, 16, 20, 18]},
	"slip": {"tex": "panels/slip.png", "m": [14, 14, 14, 14], "x": [6, 6, 6, 6], "c": [10, 7, 10, 8]},
	"newsprint": {"tex": "panels/newsprint.png", "m": [28, 28, 28, 28], "x": [10, 10, 10, 10], "c": [20, 14, 20, 16]},
	"ledger": {"tex": "panels/ledger.png", "m": [96, 64, 48, 40], "x": [10, 10, 10, 10], "c": [80, 50, 30, 26]},
	"ledger_strip": {"tex": "panels/ledger_strip.png", "m": [84, 12, 24, 16], "x": [6, 10, 6, 8], "c": [64, 6, 16, 8]},
	"leather": {"tex": "panels/leather.png", "m": [48, 48, 48, 48], "x": [10, 10, 10, 10], "c": [34, 34, 34, 34]},
	"telegram": {"tex": "panels/telegram.png", "m": [28, 56, 28, 28], "x": [11, 11, 11, 11], "c": [22, 46, 22, 20]},
	"deco": {"tex": "panels/deco_frame.png", "m": [96, 96, 96, 96], "x": [10, 10, 10, 10], "c": [70, 66, 70, 66]},
	"deco_navy": {"tex": "panels/deco_frame_navy.png", "m": [96, 96, 96, 96], "x": [10, 10, 10, 10], "c": [70, 66, 70, 66]},
	"photo": {"tex": "photos/photo_frame.png", "m": [16, 16, 16, 16], "x": [4, 4, 4, 4], "c": [9, 9, 9, 9]},
	"stamp_normal": {"tex": "buttons/stamp_normal.png", "m": [16, 14, 16, 14], "x": [3, 3, 3, 3], "c": [14, 7, 14, 8]},
	"stamp_hover": {"tex": "buttons/stamp_hover.png", "m": [16, 14, 16, 14], "x": [3, 3, 3, 3], "c": [14, 7, 14, 8]},
	"stamp_pressed": {"tex": "buttons/stamp_pressed.png", "m": [16, 14, 16, 14], "x": [3, 3, 3, 3], "c": [14, 8, 14, 7]},
	"stamp_disabled": {"tex": "buttons/stamp_disabled.png", "m": [16, 14, 16, 14], "x": [3, 3, 3, 3], "c": [14, 7, 14, 8]},
	"stamp_focus": {"tex": "buttons/stamp_focus.png", "m": [16, 14, 16, 14], "x": [3, 3, 3, 3], "c": [14, 7, 14, 8]},
	"tab_selected": {"tex": "tabs/tab_selected.png", "m": [18, 12, 18, 6], "x": [3, 3, 3, 0], "c": [14, 6, 14, 4]},
	"tab_unselected": {"tex": "tabs/tab_unselected.png", "m": [18, 12, 18, 6], "x": [3, 3, 3, 0], "c": [14, 6, 14, 4]},
	"tab_hover": {"tex": "tabs/tab_hover.png", "m": [18, 12, 18, 6], "x": [3, 3, 3, 0], "c": [14, 6, 14, 4]},
	"field_normal": {"tex": "fields/field_normal.png", "m": [10, 10, 10, 10], "x": [2, 2, 2, 2], "c": [8, 4, 8, 5]},
	"field_focus": {"tex": "fields/field_focus.png", "m": [10, 10, 10, 10], "x": [2, 2, 2, 2], "c": [8, 4, 8, 5]},
	"bar_bg": {"tex": "bars/bar_bg.png", "m": [6, 6, 6, 6], "x": [0, 0, 0, 0], "c": [2, 2, 2, 2]},
	"bar_fill": {"tex": "bars/bar_fill.png", "m": [2, 2, 2, 2], "x": [-2, -2, -2, -2], "c": [0, 0, 0, 0]},
	"bar_fill_green": {"tex": "bars/bar_fill_green.png", "m": [2, 2, 2, 2], "x": [-2, -2, -2, -2], "c": [0, 0, 0, 0]},
	"bar_fill_ink": {"tex": "bars/bar_fill_ink.png", "m": [2, 2, 2, 2], "x": [-2, -2, -2, -2], "c": [0, 0, 0, 0]},
	"scroll_track": {"tex": "bars/scroll_track.png", "m": [0, 4, 0, 4], "x": [0, 0, 0, 0], "c": [0, 0, 0, 0]},
	"scroll_track_h": {"tex": "bars/scroll_track_h.png", "m": [4, 0, 4, 0], "x": [0, 0, 0, 0], "c": [0, 0, 0, 0]},
	"scroll_grabber": {"tex": "bars/scroll_grabber.png", "m": [4, 12, 4, 12], "x": [0, 0, 0, 0], "c": [0, 0, 0, 0]},
	"scroll_grabber_h": {"tex": "bars/scroll_grabber_h.png", "m": [12, 4, 12, 4], "x": [0, 0, 0, 0], "c": [0, 0, 0, 0]},
	"stamp_frame": {"tex": "stamps/stamp_frame.png", "m": [18, 18, 18, 18], "x": [0, 0, 0, 0], "c": [16, 8, 16, 8]},
	"key_wide": {"tex": "keys/key_blank_wide.png", "m": [24, 0, 24, 0], "x": [0, 0, 0, 0], "c": [18, 0, 18, 0]},
}

## Icons available to icon(name): white linocut glyphs (tint with modulate).
const ICONS := ["fedora", "badge", "pistol", "tommy_gun", "barrel", "crate", "anchor", "warehouse", "still",
	"brewery", "locomotive", "envelope", "ledger", "handshake", "skull", "eye", "cop_cap", "truck", "ship",
	"money_bag", "banknotes", "car", "telephone"]
## Portrait kinds available to portrait(kind).
const PORTRAITS := ["boss", "crewman", "cop", "shopkeeper", "woman", "dockworker", "smuggler", "union_boss",
	"arms_dealer", "priest", "agent"]
## Pre-printed rubber stamps (anything else is set in type inside a stamp frame).
const STAMPS := ["paid", "confidential", "overdue", "seized", "case_file", "received", "urgent"]
## Pre-baked typewriter keys (single letters/digits use key_<X>.png, words key_<word>.png).
const WIDE_KEYS := ["tab", "esc", "alt", "shift", "space", "enter", "ctrl"]

const MONTHS := ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER",
	"OCTOBER", "NOVEMBER", "DECEMBER"]

static var _fonts := {}
static var _tex := {}
static var _theme: Theme = null


# ------------------------------------------------------------------------ fonts / textures

## Returns the cached Font for a role: "display", "headline", "headline_bold", "type",
## "ledger", "ledger_bold", "engrave", "body", "italic", "sign". Unknown roles fall back to "type".
static func font(role: String) -> Font:
	if _fonts.has(role):
		return _fonts[role]
	var file: String = FONT_FILES.get(role, FONT_FILES["type"])
	var f: Font
	if "@" in file:
		# a weight on a variable font (Playfair Display ships as one variable file)
		var parts := file.split("@")
		var fv := FontVariation.new()
		fv.base_font = load(FONT_DIR + parts[0])
		var ts := TextServerManager.get_primary_interface()
		fv.variation_opentype = {ts.name_to_tag("wght"): int(parts[1])}
		f = fv
	else:
		f = load(FONT_DIR + file)
	_fonts[role] = f
	return f


## Loads (and caches) a texture from res://assets/ui/<path>. Returns null if missing.
static func tex(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	var full := UI_DIR + path
	var t: Texture2D = null
	if ResourceLoader.exists(full):
		t = load(full)
	_tex[path] = t
	return t


## Builds a StyleBoxTexture from the NINE table. `tint` multiplies the texture.
static func nine(key: String, tint := Color.WHITE) -> StyleBoxTexture:
	var spec: Dictionary = NINE[key]
	var sb := StyleBoxTexture.new()
	sb.texture = tex(spec["tex"])
	var m: Array = spec["m"]
	var x: Array = spec["x"]
	var c: Array = spec["c"]
	sb.texture_margin_left = m[0]
	sb.texture_margin_top = m[1]
	sb.texture_margin_right = m[2]
	sb.texture_margin_bottom = m[3]
	sb.expand_margin_left = x[0]
	sb.expand_margin_top = x[1]
	sb.expand_margin_right = x[2]
	sb.expand_margin_bottom = x[3]
	sb.content_margin_left = c[0]
	sb.content_margin_top = c[1]
	sb.content_margin_right = c[2]
	sb.content_margin_bottom = c[3]
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.modulate_color = tint
	return sb


# ------------------------------------------------------------------------ style boxes

## Plain manila paper panel, trimmed straight, soft shadow. The default PanelContainer look.
static func paper_panel() -> StyleBoxTexture:
	return nine("paper")


## Cream card with deckled (torn-by-hand) edges and a physical drop shadow: dialogs, notes.
static func card() -> StyleBoxTexture:
	return nine("card")


## A small paper slip (tooltips, prompts, captions).
static func slip() -> StyleBoxTexture:
	return nine("slip")


## Ledger page: green ruled lines every 32 px, red double margin at the left, header rule.
## Content starts right of the red margin.
static func ledger() -> StyleBoxTexture:
	return nine("ledger")


## A strip torn from a ledger page (fixed 70 px tall visible, 84 px texture): the HUD bar.
static func ledger_strip() -> StyleBoxTexture:
	return nine("ledger_strip")


## Oxblood-brown leather book cover with a stitched edge and blind-tooled groove.
static func leather() -> StyleBoxTexture:
	return nine("leather")


## Yellow-cream telegram form with the printed header rule (put a "TELEGRAM" label in the
## 46 px top content margin, see telegram_note()).
static func telegram() -> StyleBoxTexture:
	return nine("telegram")


## Newsprint sheet for the newspaper.
static func newsprint() -> StyleBoxTexture:
	return nine("newsprint")


## Art Deco poster frame: stepped corners, sunburst fans, brass band. navy=true for the dark
## printed poster (main menu), otherwise cream.
static func deco_frame(navy := false) -> StyleBoxTexture:
	return nine("deco_navy" if navy else "deco")


## White photo border with a keyline; the middle is transparent (put the photo underneath).
static func photo_frame() -> StyleBoxTexture:
	return nine("photo")


## The rubber-stamp button styles: {"normal","hover","pressed","disabled","focus"}.
static func stamp_button_styles() -> Dictionary:
	return {
		"normal": nine("stamp_normal"), "hover": nine("stamp_hover"), "pressed": nine("stamp_pressed"),
		"disabled": nine("stamp_disabled"), "focus": nine("stamp_focus"),
	}


## Applies the stamp styles (and fonts/colours) to one Button without a theme.
static func style_button(b: Button, size := 17) -> void:
	var st := stamp_button_styles()
	for k in st:
		b.add_theme_stylebox_override(k, st[k])
	b.add_theme_stylebox_override("hover_pressed", st["pressed"])
	b.add_theme_font_override("font", font("ledger_bold"))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", OXBLOOD)
	b.add_theme_color_override("font_pressed_color", PAPER)
	b.add_theme_color_override("font_hover_pressed_color", PAPER)
	b.add_theme_color_override("font_focus_color", INK)
	b.add_theme_color_override("font_disabled_color", Color(INK, 0.4))


static func _empty(l := 0.0, t := 0.0, r := 0.0, b := 0.0) -> StyleBoxEmpty:
	var s := StyleBoxEmpty.new()
	s.content_margin_left = l
	s.content_margin_top = t
	s.content_margin_right = r
	s.content_margin_bottom = b
	return s


static func _wash(col: Color, l := 6.0, t := 2.0, r := 6.0, b := 2.0) -> StyleBoxFlat:
	# a pencil/highlighter wash: flat on purpose, slightly skewed corners
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.corner_radius_top_left = 2
	s.corner_radius_bottom_right = 5
	s.corner_radius_top_right = 1
	s.corner_radius_bottom_left = 3
	s.content_margin_left = l
	s.content_margin_top = t
	s.content_margin_right = r
	s.content_margin_bottom = b
	return s


# ------------------------------------------------------------------------ theme

## The whole kit as a Theme (cached; call theme().duplicate() if you want to edit it).
## Covers Button, Label, RichTextLabel, Panel/PanelContainer, LineEdit, TextEdit, OptionButton
## (+PopupMenu), SpinBox, CheckBox/CheckButton, ProgressBar, ScrollContainer/scroll bars,
## TabBar/TabContainer, HSeparator/VSeparator, tooltips and the type variations listed at the top.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font("type")
	t.default_font_size = 18

	# Label + variations
	t.set_color("font_color", "Label", INK)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	t.set_font_size("font_size", "Label", 18)
	var labels := {
		"DisplayLabel": ["display", 44, INK], "HeadlineLabel": ["headline", 30, INK],
		"SubheadLabel": ["headline_bold", 20, INK], "TypeLabel": ["type", 18, INK],
		"LedgerLabel": ["ledger", 17, INK], "FigureLabel": ["ledger_bold", 24, INK],
		"EngraveLabel": ["engrave", 15, SEPIA], "CaptionLabel": ["italic", 15, INK_SOFT],
		"BodyLabel": ["body", 15, INK], "SignLabel": ["sign", 26, OXBLOOD], "PaperLabel": ["type", 18, PAPER],
	}
	for k in labels:
		var spec: Array = labels[k]
		t.set_type_variation(k, "Label")
		t.set_font("font", k, font(spec[0]))
		t.set_font_size("font_size", k, spec[1])
		t.set_color("font_color", k, spec[2])

	# RichTextLabel
	t.set_font("normal_font", "RichTextLabel", font("type"))
	t.set_font("bold_font", "RichTextLabel", font("ledger_bold"))
	t.set_font("italics_font", "RichTextLabel", font("italic"))
	t.set_font("bold_italics_font", "RichTextLabel", font("headline_bold"))
	t.set_font("mono_font", "RichTextLabel", font("ledger"))
	for fs in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		t.set_font_size(fs, "RichTextLabel", 17)
	t.set_font_size("italics_font_size", "RichTextLabel", 18)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_color("font_selected_color", "RichTextLabel", INK)
	t.set_color("selection_color", "RichTextLabel", HIGHLIGHT)
	t.set_stylebox("normal", "RichTextLabel", _empty())
	t.set_stylebox("focus", "RichTextLabel", _empty())

	# Panels
	t.set_stylebox("panel", "Panel", paper_panel())
	t.set_stylebox("panel", "PanelContainer", paper_panel())
	var panels := {"CardPanel": "card", "LedgerPanel": "ledger", "LeatherPanel": "leather",
		"TelegramPanel": "telegram", "DecoPanel": "deco", "DecoNavyPanel": "deco_navy", "NewsPanel": "newsprint",
		"SlipPanel": "slip", "StripPanel": "ledger_strip", "PhotoPanel": "photo"}
	for k in panels:
		t.set_type_variation(k, "PanelContainer")
		t.set_stylebox("panel", k, nine(panels[k]))

	# Button (rubber stamps)
	var st := stamp_button_styles()
	for bt in ["Button", "OptionButton", "MenuButton"]:
		for k in st:
			t.set_stylebox(k, bt, st[k])
		t.set_stylebox("hover_pressed", bt, st["pressed"])
		t.set_font("font", bt, font("ledger_bold"))
		t.set_font_size("font_size", bt, 17)
		t.set_color("font_color", bt, INK)
		t.set_color("font_hover_color", bt, OXBLOOD)
		t.set_color("font_pressed_color", bt, PAPER)
		t.set_color("font_hover_pressed_color", bt, PAPER)
		t.set_color("font_focus_color", bt, INK)
		t.set_color("font_disabled_color", bt, Color(INK, 0.4))
		t.set_color("icon_normal_color", bt, INK)
		t.set_color("icon_hover_color", bt, OXBLOOD)
		t.set_color("icon_pressed_color", bt, PAPER)
		t.set_constant("h_separation", bt, 8)
	t.set_icon("arrow", "OptionButton", tex("small/arrow_down.png"))
	t.set_constant("arrow_margin", "OptionButton", 10)
	t.set_constant("modulate_arrow", "OptionButton", 1)

	# OptionRow: a numbered choice in a dialog (typed text, highlight wash on hover)
	t.set_type_variation("OptionRow", "Button")
	t.set_stylebox("normal", "OptionRow", _empty(8, 3, 8, 3))
	t.set_stylebox("hover", "OptionRow", _wash(HIGHLIGHT, 8, 3, 8, 3))
	t.set_stylebox("pressed", "OptionRow", _wash(Color(OXBLOOD, 0.22), 8, 3, 8, 3))
	t.set_stylebox("hover_pressed", "OptionRow", _wash(Color(OXBLOOD, 0.22), 8, 3, 8, 3))
	t.set_stylebox("focus", "OptionRow", _wash(Color(NAVY, 0.10), 8, 3, 8, 3))
	t.set_stylebox("disabled", "OptionRow", _empty(8, 3, 8, 3))
	t.set_font("font", "OptionRow", font("type"))
	t.set_font_size("font_size", "OptionRow", 18)
	t.set_color("font_color", "OptionRow", INK)
	t.set_color("font_hover_color", "OptionRow", OXBLOOD_DARK)
	t.set_color("font_pressed_color", "OptionRow", OXBLOOD_DARK)
	t.set_color("font_hover_pressed_color", "OptionRow", OXBLOOD_DARK)
	t.set_color("font_focus_color", "OptionRow", INK)
	t.set_color("font_disabled_color", "OptionRow", Color(INK, 0.35))
	t.set_constant("align_to_largest_stylebox", "OptionRow", 0)
	# TypeButton: a typed link (no stamp), underlined by a wash on hover
	t.set_type_variation("TypeButton", "OptionRow")
	t.set_font("font", "TypeButton", font("ledger_bold"))
	t.set_font_size("font_size", "TypeButton", 16)

	# PopupMenu (OptionButton lists)
	t.set_stylebox("panel", "PopupMenu", slip())
	t.set_stylebox("hover", "PopupMenu", _wash(HIGHLIGHT, 4, 1, 4, 1))
	t.set_font("font", "PopupMenu", font("type"))
	t.set_font_size("font_size", "PopupMenu", 17)
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", OXBLOOD_DARK)
	t.set_color("font_disabled_color", "PopupMenu", Color(INK, 0.4))
	t.set_icon("radio_checked", "PopupMenu", tex("small/radio_on.png"))
	t.set_icon("radio_unchecked", "PopupMenu", tex("small/radio_off.png"))
	t.set_icon("checked", "PopupMenu", tex("small/check_on.png"))
	t.set_icon("unchecked", "PopupMenu", tex("small/check_off.png"))
	t.set_constant("v_separation", "PopupMenu", 6)
	var sep := StyleBoxLine.new()
	sep.color = Color(INK, 0.5)
	sep.thickness = 1
	t.set_stylebox("separator", "PopupMenu", sep)

	# LineEdit / TextEdit: a typed form blank
	for le in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", le, nine("field_normal"))
		t.set_stylebox("focus", le, nine("field_focus"))
		t.set_stylebox("read_only", le, nine("field_normal", Color(1, 1, 1, 0.6)))
		t.set_font("font", le, font("type"))
		t.set_font_size("font_size", le, 18)
		t.set_color("font_color", le, INK)
		t.set_color("font_placeholder_color", le, Color(INK, 0.38))
		t.set_color("font_uneditable_color", le, Color(INK, 0.5))
		t.set_color("caret_color", le, OXBLOOD)
		t.set_color("selection_color", le, HIGHLIGHT)
		t.set_color("font_selected_color", le, INK)
		t.set_constant("caret_width", le, 2)
	t.set_icon("clear", "LineEdit", tex("small/check_on.png"))

	# SpinBox
	t.set_icon("updown", "SpinBox", tex("small/updown.png"))

	# CheckBox / CheckButton: ballot boxes
	for cb in ["CheckBox", "CheckButton"]:
		for k in ["normal", "pressed", "hover", "hover_pressed", "focus", "disabled"]:
			t.set_stylebox(k, cb, _empty(2, 2, 4, 2))
		t.set_stylebox("hover", cb, _wash(HIGHLIGHT, 2, 2, 4, 2))
		t.set_stylebox("hover_pressed", cb, _wash(HIGHLIGHT, 2, 2, 4, 2))
		t.set_font("font", cb, font("type"))
		t.set_font_size("font_size", cb, 18)
		t.set_color("font_color", cb, INK)
		t.set_color("font_hover_color", cb, OXBLOOD_DARK)
		t.set_color("font_pressed_color", cb, INK)
		t.set_color("font_hover_pressed_color", cb, OXBLOOD_DARK)
		t.set_color("font_focus_color", cb, INK)
		t.set_color("font_disabled_color", cb, Color(INK, 0.4))
		t.set_constant("h_separation", cb, 8)
	t.set_icon("checked", "CheckBox", tex("small/check_on.png"))
	t.set_icon("unchecked", "CheckBox", tex("small/check_off.png"))
	t.set_icon("checked_disabled", "CheckBox", tex("small/check_on_disabled.png"))
	t.set_icon("unchecked_disabled", "CheckBox", tex("small/check_off_disabled.png"))
	t.set_icon("radio_checked", "CheckBox", tex("small/radio_on.png"))
	t.set_icon("radio_unchecked", "CheckBox", tex("small/radio_off.png"))
	t.set_icon("checked", "CheckButton", tex("small/check_on.png"))
	t.set_icon("unchecked", "CheckButton", tex("small/check_off.png"))
	t.set_icon("checked_disabled", "CheckButton", tex("small/check_on_disabled.png"))
	t.set_icon("unchecked_disabled", "CheckButton", tex("small/check_off_disabled.png"))
	t.set_icon("checked_mirrored", "CheckButton", tex("small/check_on.png"))
	t.set_icon("unchecked_mirrored", "CheckButton", tex("small/check_off.png"))

	# ProgressBar: a ruled box with hatched ink
	t.set_stylebox("background", "ProgressBar", nine("bar_bg"))
	t.set_stylebox("fill", "ProgressBar", nine("bar_fill"))
	t.set_font("font", "ProgressBar", font("ledger_bold"))
	t.set_font_size("font_size", "ProgressBar", 13)
	t.set_color("font_color", "ProgressBar", INK)
	t.set_color("font_outline_color", "ProgressBar", PAPER)
	t.set_constant("outline_size", "ProgressBar", 4)
	t.set_type_variation("LedgerBar", "ProgressBar")
	t.set_stylebox("fill", "LedgerBar", nine("bar_fill_green"))
	t.set_type_variation("InkBar", "ProgressBar")
	t.set_stylebox("fill", "InkBar", nine("bar_fill_ink"))

	# Scroll bars / ScrollContainer
	t.set_stylebox("panel", "ScrollContainer", _empty())
	t.set_stylebox("focus", "ScrollContainer", _empty())
	t.set_stylebox("scroll", "VScrollBar", nine("scroll_track"))
	t.set_stylebox("scroll_focus", "VScrollBar", nine("scroll_track"))
	t.set_stylebox("grabber", "VScrollBar", nine("scroll_grabber"))
	t.set_stylebox("grabber_highlight", "VScrollBar", nine("scroll_grabber", Color(1.25, 1.1, 1.0)))
	t.set_stylebox("grabber_pressed", "VScrollBar", nine("scroll_grabber", Color(0.8, 0.7, 0.65)))
	t.set_stylebox("scroll", "HScrollBar", nine("scroll_track_h"))
	t.set_stylebox("scroll_focus", "HScrollBar", nine("scroll_track_h"))
	t.set_stylebox("grabber", "HScrollBar", nine("scroll_grabber_h"))
	t.set_stylebox("grabber_highlight", "HScrollBar", nine("scroll_grabber_h", Color(1.25, 1.1, 1.0)))
	t.set_stylebox("grabber_pressed", "HScrollBar", nine("scroll_grabber_h", Color(0.8, 0.7, 0.65)))

	# TabBar / TabContainer: index tabs on a ledger page
	for tb in ["TabBar", "TabContainer"]:
		t.set_stylebox("tab_selected", tb, nine("tab_selected"))
		t.set_stylebox("tab_unselected", tb, nine("tab_unselected"))
		t.set_stylebox("tab_hovered", tb, nine("tab_hover"))
		t.set_stylebox("tab_disabled", tb, nine("tab_unselected", Color(1, 1, 1, 0.55)))
		t.set_stylebox("tab_focus", tb, _empty())
		t.set_font("font", tb, font("engrave"))
		t.set_font_size("font_size", tb, 18)
		t.set_color("font_selected_color", tb, INK)
		t.set_color("font_unselected_color", tb, Color("4a3620"))
		t.set_color("font_hovered_color", tb, OXBLOOD_DARK)
		t.set_color("font_disabled_color", tb, Color(INK, 0.35))
		t.set_constant("h_separation", tb, 6)
	t.set_constant("tab_separation", "TabBar", 2)
	t.set_stylebox("panel", "TabContainer", ledger())
	t.set_stylebox("tabbar_background", "TabContainer", _empty())
	t.set_constant("side_margin", "TabContainer", 30)

	# Separators: printed rules
	var hs := StyleBoxLine.new()
	hs.color = Color(INK, 0.75)
	hs.thickness = 2
	t.set_stylebox("separator", "HSeparator", hs)
	var vs := StyleBoxLine.new()
	vs.color = Color(RULE_GREEN, 0.9)
	vs.thickness = 1
	vs.vertical = true
	t.set_stylebox("separator", "VSeparator", vs)
	t.set_constant("separation", "HSeparator", 10)
	t.set_constant("separation", "VSeparator", 16)

	# Tooltip: a slip of paper
	t.set_stylebox("panel", "TooltipPanel", slip())
	t.set_font("font", "TooltipLabel", font("type"))
	t.set_font_size("font_size", "TooltipLabel", 15)
	t.set_color("font_color", "TooltipLabel", INK)

	_theme = t
	return t


# ------------------------------------------------------------------------ labels & rules

## A Label in a role font. role: see font(). size 0 = the role's default from the theme.
static func label(text: String, role := "type", size := 18, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(role))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## A horizontal printed rule: "double" (thick-thin), "thin", "dots" (leader) or "deco"
## (centred Art Deco ornament, 360 px). White-free: tinted with `color`.
static func rule(kind := "double", color := INK) -> Control:
	var r := TextureRect.new()
	match kind:
		"deco":
			r.texture = tex("rules/deco_divider.png")
			r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			r.custom_minimum_size = Vector2(0, 20)
		"thin":
			r.texture = tex("rules/rule_thin.png")
			r.stretch_mode = TextureRect.STRETCH_TILE
			r.custom_minimum_size = Vector2(0, 3)
		"dots":
			r.texture = tex("rules/leader_dots.png")
			r.stretch_mode = TextureRect.STRETCH_TILE
			r.custom_minimum_size = Vector2(0, 4)
		_:
			r.texture = tex("rules/rule_double.png")
			r.stretch_mode = TextureRect.STRETCH_TILE
			r.custom_minimum_size = Vector2(0, 8)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.modulate = color if kind != "deco" else Color(color.r, color.g, color.b, color.a)
	return r


## Formats an amount the way a bookkeeper writes it: "$12,450" (negative: "($1,200)").
static func money(amount: int) -> String:
	var neg := amount < 0
	var s := str(absi(amount))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	out = "$" + s + out
	return "(" + out + ")" if neg else out


# ------------------------------------------------------------------------ images

## A linocut icon (white on transparent; tint with modulate). size 32, 64 or 128.
static func icon(name: String, size := 64) -> Texture2D:
	var suffix := "" if size == 64 else ("_32" if size <= 32 else "_128")
	return tex("icons/%s%s.png" % [name, suffix])


## An icon ready to place: TextureRect tinted `color`, shown at `size` px (uses the nearest
## baked size, so 32/64/128 are pixel-exact).
static func icon_rect(name: String, size := 32, color := INK) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon(name, 32 if size <= 40 else (64 if size <= 80 else 128))
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.modulate = color
	return r


## An engraved portrait medallion (oval, cross-hatched, on cream). size: "lg" 240x300,
## "md" 168x210, "sm" 120x150. Unknown kinds fall back to "crewman".
static func portrait(kind: String, size := "md") -> Texture2D:
	if not kind in PORTRAITS:
		kind = "crewman"
	var suffix := "" if size == "lg" else "_" + size
	return tex("portraits/%s%s.png" % [kind, suffix])


## A portrait as a TextureRect at its native size.
static func portrait_rect(kind: String, size := "md") -> TextureRect:
	var r := TextureRect.new()
	r.texture = portrait(kind, size)
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	return r


## A halftone newspaper photo ("skyline", "pier") inside a white photo border. The raw
## halftone textures (photos/halftone_*.png) are white dots: tint them with modulate.
static func photo(name: String, caption := "") -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", photo_frame())
	var img := TextureRect.new()
	img.texture = tex("photos/halftone_%s.png" % name)
	img.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	img.modulate = INK
	frame.add_child(img)
	box.add_child(frame)
	if caption != "":
		var c := label(caption, "italic", 14, INK_SOFT)
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.custom_minimum_size.x = 200
		box.add_child(c)
	return box


## A tileable background (paper_cream, paper_manila, paper_newsprint, desk_wood).
static func background(name := "paper_cream") -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex("paper/%s.png" % name)
	r.stretch_mode = TextureRect.STRETCH_TILE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# ------------------------------------------------------------------------ small controls

## A typewriter key (chrome ring, black glass top) showing `text` ("E", "Tab", "Esc", "1"...).
## Baked keys are pixel-exact at size 48; other text is set on a blank key.
static func key_cap(text: String, size := 48) -> Control:
	var k := text.strip_edges()
	var lower := k.to_lower()
	var path := ""
	if k.length() == 1:
		path = "keys/key_%s.png" % k.to_upper()
	elif lower in WIDE_KEYS:
		path = "keys/key_%s.png" % lower
	var t: Texture2D = tex(path) if path != "" else null
	var sc := size / 48.0
	if t:
		var r := TextureRect.new()
		r.texture = t
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.custom_minimum_size = t.get_size() * sc
		r.tooltip_text = k
		return r
	var pc := PanelContainer.new()
	var single := k.length() <= 1
	if single:
		var sb := StyleBoxTexture.new()
		sb.texture = tex("keys/key_blank.png")
		pc.add_theme_stylebox_override("panel", sb)
		pc.custom_minimum_size = Vector2(48, 48) * sc
	else:
		pc.add_theme_stylebox_override("panel", nine("key_wide"))
		pc.custom_minimum_size = Vector2(0, 48 * sc)
	var l := label(k.to_upper(), "ledger_bold", int((22 if single else 14) * sc), Color("f2ead6"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position.y -= 2
	pc.add_child(l)
	return pc


## A key prompt: key caps followed by a typed instruction, e.g. key_prompt(["E"], "Talk").
static func key_prompt(keys: Array, text: String, size := 48, color := INK) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for k in keys:
		h.add_child(key_cap(str(k), size))
	var l := label(text, "type", 19, color)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sp := Control.new()
	sp.custom_minimum_size.x = 4
	h.add_child(sp)
	h.add_child(l)
	return h


## A wax seal pressed with `letter`, tinted `color` (e.g. the family colour).
static func wax_seal(color: Color, letter := "", size := 96.0) -> Control:
	var s := WaxSeal.new()
	s.seal_color = color
	s.letter = letter
	s.custom_minimum_size = Vector2(size, size)
	return s


## A rubber stamp impression. Known words (PAID, CONFIDENTIAL, OVERDUE, SEIZED, CASE FILE,
## RECEIVED, URGENT) are pre-inked; any other text is set inside an inked frame.
## `angle` in degrees; the stamp rotates about its centre (layout keeps its unrotated box).
static func stamp(text: String, color := OXBLOOD, angle := -8.0, scale_ := 1.0) -> Control:
	var key := text.strip_edges().to_lower().replace(" ", "_")
	var inner: Control
	var sz := Vector2.ZERO
	if key in STAMPS:
		var r := TextureRect.new()
		r.texture = tex("stamps/%s.png" % key)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sz = r.texture.get_size() * scale_
		inner = r
	else:
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", nine("stamp_frame"))
		var l := label(text.to_upper(), "headline", int(30 * scale_), Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pc.add_child(l)
		sz = pc.get_combined_minimum_size()
		inner = pc
	# the holder keeps the layout box; the inked impression inside it is rotated freely
	var holder := Control.new()
	holder.custom_minimum_size = sz
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(inner)
	inner.size = sz
	inner.pivot_offset = sz * 0.5
	inner.rotation_degrees = angle
	inner.modulate = Color(color.r, color.g, color.b, 0.88 * color.a)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.resized.connect(func() -> void:
		inner.position = (holder.size - sz) * 0.5)
	return holder


## The heat meter: a mercury thermometer on an enamel card. Set `.value` (0..100).
static func heat_meter(value := 0.0) -> HeatMeter:
	var h := HeatMeter.new()
	h.value = value
	return h


## A tear-off calendar leaf: month in the red band, the day big, year/weekday below.
static func calendar(month: int, day: int, year: int, note := "") -> Control:
	var c := CalendarLeaf.new()
	c.month = month
	c.day = day
	c.year = year
	c.note = note
	return c


## A bookkeeper's figure: small-caps caption over a typed amount with a ruled underline.
## kind: "dirty" (ink), "clean" (green), "debt" (oxblood), "plain". If `amount` is a String
## it is shown as-is (e.g. "0 · 11").
static func ledger_figure(caption: String, amount: Variant, kind := "plain", size := 24) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	var cap := label(caption.to_upper(), "engrave", 13, SEPIA)
	v.add_child(cap)
	var col := INK
	match kind:
		"clean":
			col = GREEN
		"debt":
			col = OXBLOOD
	var txt := ""
	if amount is int:
		txt = money(amount) if kind != "plain" else str(amount)
		if amount < 0:
			col = OXBLOOD
	else:
		txt = str(amount)
	var fig := label(txt, "ledger_bold", size, col)
	v.add_child(fig)
	var ul := rule("thin", Color(col, 0.7))
	v.add_child(ul)
	return v


## A ledger ProgressBar (ruled box, hatched ink fill). kind: "red", "green", "ink".
static func ledger_bar(value: float, max_value := 100.0, kind := "green", width := 140.0) -> ProgressBar:
	var p := ProgressBar.new()
	p.max_value = max_value
	p.value = value
	p.show_percentage = false
	p.custom_minimum_size = Vector2(width, 14)
	match kind:
		"green":
			p.theme_type_variation = "LedgerBar"
		"ink":
			p.theme_type_variation = "InkBar"
	return p


## A telegram: printed TELEGRAM head, the sender and the typed body (upper case, STOPs).
static func telegram_note(from: String, body: String, width := 380.0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := telegram()
	sb.content_margin_top = 3  # the head sits above the printed rule, in the top margin
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size.x = width
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.custom_minimum_size.y = 24
	var t := label("TELEGRAM", "display", 20, INK)
	head.add_child(t)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var fl := label(from.to_upper(), "engrave", 14, SEPIA)
	fl.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(fl)
	v.add_child(head)
	var gap := Control.new()
	gap.custom_minimum_size.y = 14
	v.add_child(gap)
	var b := label(body.to_upper(), "type", 17, INK)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(b)
	return p


# ------------------------------------------------------------------------ inner controls

## Wax seal control (see wax_seal()). The seal art is greyscale: it is multiplied by the
## colour, then a white specular layer and the impressed letter are drawn on top.
class WaxSeal extends Control:
	var seal_color := OXBLOOD:
		set(v):
			seal_color = v
			queue_redraw()
	var letter := "":
		set(v):
			letter = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var base: Texture2D = UiKit.tex("seal/wax_seal.png")
		var hi: Texture2D = UiKit.tex("seal/wax_seal_hi.png")
		var s := minf(size.x, size.y)
		var r := Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s))
		var c := seal_color
		var lit := Color(minf(c.r * 1.55 + 0.04, 1.6), minf(c.g * 1.55 + 0.03, 1.6), minf(c.b * 1.55 + 0.03, 1.6), c.a)
		draw_texture_rect(base, r, false, lit)
		draw_texture_rect(hi, r, false, Color(1, 0.95, 0.85, 0.75))
		if letter != "":
			var f: Font = UiKit.font("headline")
			var fs := int(s * 0.3)
			var tw := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var centre := r.position + Vector2(s * 0.5, s * 0.47)
			var p := centre + Vector2(-tw.x * 0.5, f.get_ascent(fs) * 0.5 - f.get_descent(fs) * 0.35)
			# impressed: light lip below-right, dark edge above-left, face in between
			draw_string(f, p + Vector2(1.2, 1.4), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(c.lightened(0.45), 0.8))
			draw_string(f, p + Vector2(-0.8, -0.8), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(c.darkened(0.75), 0.9))
			draw_string(f, p, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c.darkened(0.25))


## Mercury thermometer (see heat_meter()). Stretches with the control; natural size 250x44.
class HeatMeter extends Control:
	const COL_X0 := 24.0
	const COL_Y := 19.8
	const COL_H := 4.4
	const SCALE_X0 := 32.0
	const SCALE_X1 := 230.0
	var value := 0.0:
		set(v):
			value = clampf(v, 0.0, 100.0)
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(250, 44)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var t: Texture2D = UiKit.tex("misc/thermometer.png")
		var ts := t.get_size()
		var k := size / ts
		draw_texture_rect(t, Rect2(Vector2.ZERO, size), false)
		var x1 := SCALE_X0 + (SCALE_X1 - SCALE_X0) * value / 100.0
		var r := Rect2(Vector2(COL_X0, COL_Y) * k, Vector2(x1 - COL_X0, COL_H) * k)
		var hot := value >= 75.0
		draw_rect(r, UiKit.OXBLOOD if not hot else Color("a3221c"))
		draw_line(Vector2(r.position.x, r.position.y + 1.2 * k.y), Vector2(r.end.x, r.position.y + 1.2 * k.y),
			Color(1.0, 0.78, 0.72, 0.55), maxf(1.0, k.y))
		draw_circle(Vector2(r.end.x, r.get_center().y), COL_H * 0.5 * k.y, UiKit.OXBLOOD if not hot else Color("a3221c"))


## Tear-off calendar leaf (see calendar()). Natural size 92x108.
class CalendarLeaf extends Control:
	var month := 1
	var day := 1
	var year := 1929
	var note := ""

	func _init() -> void:
		custom_minimum_size = Vector2(92, 108)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_texture(UiKit.tex("misc/calendar_page.png"), Vector2.ZERO)
		var mname: String = UiKit.MONTHS[clampi(month - 1, 0, 11)]
		var fb: Font = UiKit.font("ledger_bold")
		var fh: Font = UiKit.font("headline")
		var fe: Font = UiKit.font("engrave")
		var w := 92.0
		var fs := 13 if mname.length() <= 6 else 11
		draw_string(fb, Vector2(5, 21 + 14.5), mname, HORIZONTAL_ALIGNMENT_CENTER, w - 10, fs, UiKit.PAPER)
		draw_string(fh, Vector2(5, 45 + 38), str(day), HORIZONTAL_ALIGNMENT_CENTER, w - 10, 42, UiKit.INK)
		var sub := str(year) if note == "" else note
		draw_string(fe, Vector2(5, 45 + 53), sub, HORIZONTAL_ALIGNMENT_CENTER, w - 10, 13, UiKit.SEPIA)
