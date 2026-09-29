extends Control
## UI kit demo: four screens that show the printed-ephemera kit in realistic arrangements.
##   godot --path game res://tools/ui/kit_demo.tscn                 (keys 1-4 switch screens)
##   godot --rendering-driver opengl3 --resolution 1600x900 --path game res://tools/ui/kit_demo.tscn -- --shots=/tmp/kit
## writes /tmp/kit_hud.png, _ledger.png, _menu.png, _kit.png and quits.

const PAGES := ["hud", "ledger", "menu", "kit"]

var _pages: Array[Control] = []
var _fits: Array[Control] = []


func _ready() -> void:
	theme = UiKit.theme()
	for p in PAGES:
		var c := Control.new()
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.visible = false
		add_child(c)
		_pages.append(c)
		call("_page_" + p, c)
	_show(0)
	var shots := ""
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
		elif a.begins_with("--page="):
			only = a.substr(7)
	if shots != "":
		for role in UiKit.FONT_FILES:
			var f: Font = UiKit.font(role)
			var ok := f != null and f.get_string_size("Famiglia", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x > 10
			print("KIT FONT %s -> %s %s" % [role, UiKit.FONT_FILES[role], "OK" if ok else "MISSING"])
		for i in PAGES.size():
			if only != "" and PAGES[i] != only:
				continue
			_show(i)
			for f in 6:
				await get_tree().process_frame
			var img := get_viewport().get_texture().get_image()
			img.save_png("%s_%s.png" % [shots, PAGES[i]])
			print("KIT SHOT ", shots, "_", PAGES[i], ".png")
		get_tree().quit()


func _show(i: int) -> void:
	for j in _pages.size():
		_pages[j].visible = j == i
	for c in _fits:
		if c.is_visible_in_tree():
			_refit(c)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		var k: int = e.keycode - KEY_1
		if k >= 0 and k < _pages.size():
			_show(k)


# ------------------------------------------------------------------------ helpers

func _place(parent: Control, c: Control, pos: Vector2, size := Vector2.ZERO, rot := 0.0) -> Control:
	parent.add_child(c)
	c.position = pos
	if size != Vector2.ZERO:
		c.size = size
	else:
		_fit_later(c)
	if rot != 0.0:
		c.rotation_degrees = rot
		c.pivot_offset = c.size * 0.5
		c.resized.connect(func() -> void: c.pivot_offset = c.size * 0.5)
	return c


func _fit_later(c: Control) -> void:
	_fits.append(c)


func _refit(c: Control) -> void:
	# autowrapped labels only know their height once they have a width: shrink after layout
	await get_tree().process_frame
	c.reset_size()
	await get_tree().process_frame
	c.reset_size()
	c.pivot_offset = c.size * 0.5


func _screenshot_bg(name: String) -> TextureRect:
	var r := TextureRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var path := ProjectSettings.globalize_path("res://").path_join("../docs/screenshots/" + name)
	var img := Image.load_from_file(path) if FileAccess.file_exists(path) else null
	if img:
		r.texture = ImageTexture.create_from_image(img)
	else:
		r.texture = UiKit.tex("paper/desk_wood.png")
		r.stretch_mode = TextureRect.STRETCH_TILE
	return r


func _hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func _vbox(sep := 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func _vrule(color := UiKit.RULE_GREEN) -> VSeparator:
	var s := VSeparator.new()
	var sb := StyleBoxLine.new()
	sb.vertical = true
	sb.color = color
	sb.thickness = 1
	s.add_theme_stylebox_override("separator", sb)
	return s


func _wrap(l: Label, w := 0.0) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if w > 0:
		l.custom_minimum_size.x = w
	return l


# ------------------------------------------------------------------------ 1: the street HUD

func _page_hud(root: Control) -> void:
	root.add_child(_screenshot_bg("01_street_day.png"))
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.12, 0.08, 0.04, 0.18)
	root.add_child(dim)

	# --- the ledger strip across the top
	var strip := PanelContainer.new()
	strip.theme_type_variation = "StripPanel"
	var ssb: StyleBoxTexture = UiKit.ledger_strip()
	ssb.content_margin_left = 96
	ssb.content_margin_right = 132
	strip.add_theme_stylebox_override("panel", ssb)
	_place(root, strip, Vector2(0, 0), Vector2(1600, 70))
	var row := _hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	strip.add_child(row)
	var name_box := _vbox(-4)
	name_box.add_child(UiKit.label("The Vitale Family", "headline", 25, UiKit.INK))
	name_box.add_child(UiKit.label("Little Italy  ·  est. 1923  ·  Don Alex Vitale", "italic", 15, UiKit.INK_SOFT))
	row.add_child(name_box)
	row.add_child(_vrule())
	row.add_child(UiKit.ledger_figure("Stash (dirty)", 586, "dirty"))
	row.add_child(UiKit.ledger_figure("Clean money", 7500, "clean"))
	row.add_child(UiKit.ledger_figure("On you", 2650, "dirty"))
	row.add_child(UiKit.ledger_figure("Men", "2"))
	row.add_child(UiKit.ledger_figure("Guns · Ammo", "1 · 11"))
	row.add_child(_vrule())
	var heat := _vbox(-6)
	var hl := _hbox(6)
	hl.add_child(UiKit.label("HEAT", "engrave", 13, UiKit.SEPIA))
	hl.add_child(UiKit.label("24 of 100  ·  three witnesses", "italic", 13, UiKit.INK_SOFT))
	heat.add_child(hl)
	heat.add_child(UiKit.heat_meter(24))
	row.add_child(heat)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var when := _vbox(-4)
	var wl := UiKit.label("Friday, evening", "headline_bold", 18, UiKit.INK)
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	when.add_child(wl)
	var wl2 := UiKit.label("rain off the river", "italic", 15, UiKit.INK_SOFT)
	wl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	when.add_child(wl2)
	row.add_child(when)
	# crest pressed into the margin, and the calendar pinned on the right
	_place(root, UiKit.wax_seal(Color("a32420"), "V", 88), Vector2(2, -6), Vector2(88, 88))
	_place(root, UiKit.calendar(6, 14, 1929), Vector2(1494, 2), Vector2(92, 108), 2.0)

	# --- telegram stack (right)
	var notes := [
		["Chicago, Ill.", "Convoy arrived Calumet docks stop 120 crates in the warehouse stop Moran boys asking questions stop"],
		["Atlantic City", "Nucky sends regards stop Absecon landing clear Tuesday stop bring the money stop"],
		["Windsor, Ont.", "Customs man wants 400 more stop river freezes in six weeks stop advise stop"],
	]
	var ys := [118, 262, 408]
	var rots := [-1.6, 1.2, -0.6]
	for i in notes.size():
		var n: Array = notes[i]
		var tn := UiKit.telegram_note(n[0], n[1], 372)
		_place(root, tn, Vector2(1196 - i * 8, ys[i]), Vector2.ZERO, rots[i])
	var pinned := UiKit.stamp("RECEIVED", UiKit.NAVY, 9.0, 0.8)
	_place(root, pinned, Vector2(1400, 478))

	# --- the dialog card
	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	_place(root, card, Vector2(318, 522), Vector2(860, 0))
	var ch := _hbox(22)
	card.add_child(ch)
	var pv := _vbox(4)
	pv.add_child(UiKit.portrait_rect("shopkeeper", "md"))
	var who := UiKit.label("SAMMY GALLO", "engrave", 15, UiKit.SEPIA)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(who)
	ch.add_child(pv)
	var dv := _vbox(4)
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ch.add_child(dv)
	dv.add_child(UiKit.label("Gallo's Pawn & Loan", "headline", 28, UiKit.INK))
	dv.add_child(UiKit.label("Mulberry Street  ·  pays the Russo family $40 a week", "italic", 16, UiKit.INK_SOFT))
	dv.add_child(UiKit.rule("thin", Color(UiKit.INK, 0.6)))
	var speech := _wrap(UiKit.label("\"Business is slow, Mr. Vitale. The Russos already come round Fridays. You want I should pay twice? I got a wife, I got a boy at St. Patrick's.\"", "type", 18, UiKit.INK))
	dv.add_child(speech)
	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	dv.add_child(gap)
	var opts := [
		"Offer protection  —  $40 a week, the Russos be damned",
		"Lean on him  (the window goes, people will see)",
		"Buy the shop  —  $3,200 clean",
		"Ask what he saw on Mulberry Street last night",
		"Tip your hat and leave",
	]
	for i in opts.size():
		var orow := _hbox(2)
		var num := UiKit.label("%d." % (i + 1), "ledger_bold", 18, UiKit.OXBLOOD)
		num.custom_minimum_size.x = 24
		orow.add_child(num)
		var b := Button.new()
		b.theme_type_variation = "OptionRow"
		b.text = opts[i]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		orow.add_child(b)
		dv.add_child(orow)
		if i == 0:
			b.add_theme_stylebox_override("normal", b.get_theme_stylebox("hover"))
			b.add_theme_color_override("font_color", UiKit.OXBLOOD_DARK)
	var st := UiKit.stamp("OVERDUE", UiKit.OXBLOOD, -11.0, 0.9)
	_place(root, st, Vector2(975, 546))
	var pin := TextureRect.new()
	pin.texture = UiKit.tex("small/pin.png")
	_place(root, pin, Vector2(736, 516))

	# --- key prompt (bottom left) and key reference
	var slip := PanelContainer.new()
	slip.theme_type_variation = "SlipPanel"
	slip.add_child(UiKit.key_prompt(["E"], "Talk to Sammy Gallo"))
	_place(root, slip, Vector2(28, 790), Vector2.ZERO, -1.0)
	var keys := PanelContainer.new()
	keys.theme_type_variation = "SlipPanel"
	var kr := _vbox(4)
	for pair in [["TAB", "The family"], ["J", "The country"], ["M", "City map"], ["N", "The paper"], ["ESC", "Menu"]]:
		kr.add_child(UiKit.key_prompt([pair[0]], pair[1], 48))
	keys.add_child(kr)
	_place(root, keys, Vector2(1352, 590), Vector2.ZERO, 1.0)
	var kb := PanelContainer.new()
	kb.theme_type_variation = "SlipPanel"
	var krow := _hbox(4)
	for k in ["F", "G", "R", "V", "Q"]:
		krow.add_child(UiKit.key_cap(k))
	var kl := UiKit.label("punch · pistol · send men · truck · drop", "type", 16, UiKit.INK_SOFT)
	kl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	krow.add_child(kl)
	kb.add_child(krow)
	_place(root, kb, Vector2(24, 92), Vector2.ZERO, -0.6)


# ------------------------------------------------------------------------ 2: the family ledger + newspaper

func _page_ledger(root: Control) -> void:
	root.add_child(UiKit.background("desk_wood"))
	# the leather book with index tabs
	var book := PanelContainer.new()
	book.theme_type_variation = "LeatherPanel"
	_place(root, book, Vector2(34, 30), Vector2(930, 840))
	var tabs := TabContainer.new()
	book.add_child(tabs)
	for tname in ["The Family", "Businesses", "The Case", "Sit-downs", "The Books"]:
		var page := _vbox(8)
		page.name = tname
		tabs.add_child(page)
		if tname == "The Case":
			_case_page(page)
		elif tname == "The Family":
			page.add_child(UiKit.label("The family", "headline", 26))
	tabs.current_tab = 2
	var cf := UiKit.stamp("CASE FILE", UiKit.OXBLOOD, -7.0, 0.95)
	_place(root, cf, Vector2(690, 128))

	# the newspaper
	var paper := PanelContainer.new()
	paper.theme_type_variation = "NewsPanel"
	_place(root, paper, Vector2(996, 40), Vector2(570, 820), 1.2)
	var v := _vbox(4)
	paper.add_child(v)
	var top := _hbox(0)
	top.add_child(UiKit.label("LATE CITY EDITION", "engrave", 12, UiKit.INK))
	var s1 := Control.new()
	s1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(s1)
	top.add_child(UiKit.label("\"All the News That's Fit to Sell\"", "italic", 13, UiKit.INK))
	var s2 := Control.new()
	s2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(s2)
	top.add_child(UiKit.label("TWO CENTS", "engrave", 12, UiKit.INK))
	v.add_child(top)
	var mast := UiKit.label("The Evening Clarion", "headline", 56, UiKit.INK)
	mast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(mast)
	v.add_child(UiKit.rule("double"))
	var dl := _hbox(0)
	dl.add_child(UiKit.label("VOL. LXXVIII · No. 26,114", "engrave", 12))
	var s3 := Control.new()
	s3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dl.add_child(s3)
	dl.add_child(UiKit.label("NEW YORK, FRIDAY, JUNE 14, 1929", "engrave", 12))
	var s4 := Control.new()
	s4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dl.add_child(s4)
	dl.add_child(UiKit.label("RAIN TONIGHT", "engrave", 12))
	v.add_child(dl)
	v.add_child(UiKit.rule("thin"))
	var head := _wrap(UiKit.label("RUM ROW RAIDED; 400 CASES SEIZED OFF SANDY HOOK", "headline", 33, UiKit.INK))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var sub := _wrap(UiKit.label("Coast Guard Cutters Fire on a Speedboat in the Fog  —  Vitale Name Heard on Mulberry Street", "italic", 17, UiKit.INK))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(UiKit.rule("thin"))
	var cols := _hbox(10)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var lorem := [
		"SANDY HOOK, June 13.  Two cutters of the Coast Guard, running without lights, closed on the rum fleet beyond the twelve-mile limit shortly after midnight and seized the British schooner Mary Beatrice with four hundred cases of Scotch whisky aboard.",
		"A speedboat which had lately taken on cargo from the schooner ran for the Narrows and was fired upon. Her crew escaped in the fog; the boat was found this morning drifting off Red Hook with her tanks empty.",
		"Detectives of the Elizabeth Street station would say only that the boat's owner \"is known to them.\" Shopkeepers on Mulberry Street were unwilling to speak, and one, who would not give his name, said that he had seen nothing at all, and that he had seen it twice.",
		"The Prohibition Administrator for the district, Mr. Harold P. Crane, declared the night's work \"a warning to every family in the city,\" and promised further seizures before the Fourth.",
	]
	var c1 := _vbox(6)
	c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c1.add_child(UiKit.photo("pier", "The schooner's boats at the Red Hook pier this morning. — Clarion photograph."))
	c1.add_child(_news_text(lorem[0] + " " + lorem[1], 330))
	cols.add_child(c1)
	cols.add_child(_vrule(Color(UiKit.INK, 0.7)))
	var c2 := _vbox(6)
	c2.custom_minimum_size.x = 170
	var sh := _wrap(UiKit.label("MAYOR SILENT ON THE PRECINCT", "headline", 16, UiKit.INK))
	sh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c2.add_child(sh)
	c2.add_child(UiKit.rule("thin", Color(UiKit.INK, 0.6)))
	c2.add_child(_news_text(lorem[2], 170))
	cols.add_child(c2)

	# an advert box
	var ad := PanelContainer.new()
	var adsb := StyleBoxFlat.new()
	adsb.bg_color = Color(0, 0, 0, 0)
	adsb.border_color = UiKit.INK
	adsb.set_border_width_all(2)
	adsb.set_content_margin_all(8)
	ad.add_theme_stylebox_override("panel", adsb)
	var adv := _vbox(0)
	var a1 := UiKit.label("DR. MORROW'S", "sign", 17, UiKit.INK)
	a1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	adv.add_child(a1)
	var a2 := UiKit.label("Nerve Tonic", "headline", 20, UiKit.INK)
	a2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	adv.add_child(a2)
	var a3 := _wrap(UiKit.label("For the tired business man. 25¢ at all druggists. Strictly medicinal.", "italic", 13, UiKit.INK), 140)
	a3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	adv.add_child(a3)
	ad.add_child(adv)
	c2.add_child(ad)


func _news_text(t: String, w: float) -> Label:
	var l := _wrap(UiKit.label(t, "body", 15, UiKit.INK), w)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_FILL
	l.add_theme_constant_override("line_spacing", -2)
	return l


func _case_page(page: VBoxContainer) -> void:
	page.add_theme_constant_override("separation", 6)
	page.add_child(UiKit.label("What the Bureau has on the Vitale family", "headline", 26, UiKit.INK))
	page.add_child(_wrap(UiKit.label("At 100 the feds raid you. Everything here fades with time, unless you make it disappear first.", "italic", 16, UiKit.INK_SOFT), 700))
	var rows := [
		["eye", "WITNESS", "Sammy Gallo saw the shots fired by Alex", "Visit him at his shop: pay or scare him.", 9],
		["pistol", "WEAPON", "Your gun: bullets from it in Little Italy", "Throw it in the river at the end of a pier.", 5],
		["badge", "NOTEBOOK", "Patrolman Keane wrote down your plate", "Buy him, and the notebook disappears.", 4],
		["skull", "BODY", "Vinnie Romano, the Mulberry Street alley", "Send a cleanup crew before the morning.", 4],
		["ledger", "THE BOOKS", "The club's books show $2,400 unexplained", "Burn the books at your club.", 2],
	]
	for r in rows:
		var h := _hbox(12)
		h.add_child(UiKit.icon_rect(r[0], 32, UiKit.INK))
		var tv := _vbox(-3)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t1 := _hbox(8)
		t1.add_child(UiKit.label(r[1], "ledger_bold", 16, UiKit.OXBLOOD))
		t1.add_child(UiKit.label(r[2], "type", 17, UiKit.INK))
		tv.add_child(t1)
		tv.add_child(UiKit.label(r[3], "italic", 15, UiKit.INK_SOFT))
		h.add_child(tv)
		var fig := UiKit.label(str(r[4]), "ledger_bold", 22, UiKit.INK)
		fig.custom_minimum_size.x = 30
		fig.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(fig)
		h.add_child(UiKit.ledger_bar(float(r[4]), 10.0, "red", 90))
		page.add_child(h)
	page.add_child(UiKit.rule("double"))
	var tot := _hbox(12)
	tot.add_child(UiKit.label("THE FILE, IN ALL", "engrave", 17, UiKit.SEPIA))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tot.add_child(sp)
	tot.add_child(UiKit.label("24", "ledger_bold", 26, UiKit.OXBLOOD))
	tot.add_child(UiKit.heat_meter(24))
	page.add_child(tot)
	var g := Control.new()
	g.custom_minimum_size.y = 10
	page.add_child(g)
	page.add_child(UiKit.label("Orders", "headline_bold", 20, UiKit.INK))
	var act := _hbox(10)
	for bt in ["PAY HIM OFF", "SCARE HIM", "BURN THE BOOKS"]:
		var b := Button.new()
		b.text = bt
		act.add_child(b)
	var dis := Button.new()
	dis.text = "REACH THE RAT"
	dis.disabled = true
	act.add_child(dis)
	page.add_child(act)
	var form := GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 16)
	form.add_theme_constant_override("v_separation", 8)
	form.add_child(UiKit.label("Send", "engrave", 17, UiKit.SEPIA))
	var ob := OptionButton.new()
	for o in ["Tommy \"Two Hats\" Russo", "Little Nicky", "The Greek"]:
		ob.add_item(o)
	ob.custom_minimum_size.x = 300
	form.add_child(ob)
	form.add_child(UiKit.label("Men with him", "engrave", 17, UiKit.SEPIA))
	var spin := SpinBox.new()
	spin.min_value = 0
	spin.max_value = 8
	spin.value = 2
	form.add_child(spin)
	form.add_child(UiKit.label("The word", "engrave", 17, UiKit.SEPIA))
	var le := LineEdit.new()
	le.placeholder_text = "what he should tell the man…"
	le.custom_minimum_size.x = 420
	form.add_child(le)
	form.add_child(Control.new())
	var cbs := _hbox(20)
	var c1 := CheckBox.new()
	c1.text = "Bring the truck"
	c1.button_pressed = true
	cbs.add_child(c1)
	var c2 := CheckBox.new()
	c2.text = "Leave no witnesses"
	cbs.add_child(c2)
	form.add_child(cbs)
	page.add_child(form)


# ------------------------------------------------------------------------ 3: main menu poster

func _page_menu(root: Control) -> void:
	root.add_child(_screenshot_bg("04_whole_city.png"))
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.07, 0.05, 0.03, 0.72)
	root.add_child(dim)
	var poster := PanelContainer.new()
	poster.theme_type_variation = "DecoNavyPanel"
	_place(root, poster, Vector2(500, 26), Vector2(600, 848))
	var v := _vbox(6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	poster.add_child(v)
	var l1 := UiKit.label("NEW YORK  ·  MCMXXIX", "engrave", 20, UiKit.BRASS_LIGHT)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l1)
	var title := UiKit.label("FAMIGLIA", "display", 84, UiKit.BRASS_LIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	v.add_child(title)
	v.add_child(UiKit.rule("deco", UiKit.BRASS))
	var sky := TextureRect.new()
	sky.texture = UiKit.tex("photos/halftone_skyline.png")
	sky.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	sky.modulate = Color(UiKit.BRASS, 0.9)
	v.add_child(sky)
	var l2 := UiKit.label("A FAMILY BUSINESS IN THE YEARS OF PROHIBITION", "engrave", 17, UiKit.PAPER)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l2)
	var g := Control.new()
	g.custom_minimum_size.y = 6
	v.add_child(g)
	for bt in ["PLAY SOLO", "HOST A GAME", "JOIN A FRIEND", "CONTINUE  ·  JUNE 1929", "QUIT"]:
		var b := Button.new()
		b.text = bt
		b.custom_minimum_size = Vector2(300, 42)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.add_theme_font_size_override("font_size", 19)
		v.add_child(b)
	var g2 := Control.new()
	g2.custom_minimum_size.y = 4
	v.add_child(g2)
	v.add_child(UiKit.rule("deco", UiKit.BRASS))
	var l3 := UiKit.label("ONE TO EIGHT FAMILIES  ·  THE CRASH  ·  REPEAL", "engrave", 15, UiKit.BRASS_LIGHT)
	l3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l3)

	# new campaign card (left)
	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	_place(root, card, Vector2(56, 150), Vector2(392, 0), -1.4)
	var cv := _vbox(8)
	card.add_child(cv)
	cv.add_child(UiKit.label("A New Family", "headline", 28))
	cv.add_child(UiKit.label("Fill in, sign, and hand it to the Don.", "italic", 16, UiKit.INK_SOFT))
	cv.add_child(UiKit.rule("thin", Color(UiKit.INK, 0.6)))
	for pair in [["Your name", "Alex"], ["Family name", "Vitale"]]:
		cv.add_child(UiKit.label(pair[0].to_upper(), "engrave", 14, UiKit.SEPIA))
		var le := LineEdit.new()
		le.text = pair[1]
		cv.add_child(le)
	cv.add_child(UiKit.label("THE YEARS", "engrave", 14, UiKit.SEPIA))
	var ob := OptionButton.new()
	ob.add_item("1929 – 1933  ·  the Crash and Repeal")
	ob.add_item("1923 – 1933  ·  all of Prohibition")
	cv.add_child(ob)
	var hr := _hbox(10)
	hr.add_child(UiKit.label("RIVAL FAMILIES", "engrave", 14, UiKit.SEPIA))
	var sp := SpinBox.new()
	sp.min_value = 1
	sp.max_value = 7
	sp.value = 3
	hr.add_child(sp)
	cv.add_child(hr)
	var cb := CheckBox.new()
	cb.text = "Open the door to friends (LAN)"
	cb.button_pressed = true
	cv.add_child(cb)
	var seals := _hbox(4)
	for c in [Color("a32420"), Color("2b3a55"), Color("2f4a38"), Color("b08d57"), Color("5b2a6e")]:
		seals.add_child(UiKit.wax_seal(c, "", 56))
	cv.add_child(seals)
	var ok := Button.new()
	ok.text = "SIGN AND BEGIN"
	cv.add_child(ok)

	# join telegram (right)
	var tn := UiKit.telegram_note("Night letter", "Game on at my place stop port 24880 stop bring your own family stop", 380)
	_place(root, tn, Vector2(1156, 190), Vector2.ZERO, 1.3)
	var jv: VBoxContainer = tn.get_child(0)
	var ip := LineEdit.new()
	ip.text = "192.168.1.20"
	jv.add_child(ip)
	var jb := Button.new()
	jb.text = "JOIN THE GAME"
	jb.size_flags_horizontal = Control.SIZE_SHRINK_END
	jv.add_child(jb)
	var st := UiKit.stamp("URGENT", UiKit.OXBLOOD, 12.0, 0.8)
	_place(root, st, Vector2(1400, 150))


# ------------------------------------------------------------------------ 4: the kit sheet

func _page_kit(root: Control) -> void:
	root.add_child(UiKit.background("paper_cream"))
	var v := _vbox(10)
	_place(root, v, Vector2(30, 18), Vector2(1540, 860))
	var t := UiKit.label("The Famiglia printing office  —  specimen sheet", "headline", 30)
	v.add_child(t)
	v.add_child(UiKit.rule("double"))
	var ig := GridContainer.new()
	ig.columns = 23
	ig.add_theme_constant_override("h_separation", 2)
	for n in UiKit.ICONS:
		var iv := _vbox(0)
		iv.add_child(UiKit.icon_rect(n, 64, UiKit.INK))
		var nl := UiKit.label(n.replace("_", " "), "engrave", 11, UiKit.SEPIA)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		iv.add_child(nl)
		iv.custom_minimum_size.x = 64
		ig.add_child(iv)
	v.add_child(ig)
	var pr := _hbox(4)
	for k in UiKit.PORTRAITS:
		var pv := _vbox(0)
		pv.add_child(UiKit.portrait_rect(k, "sm"))
		var pl := UiKit.label(k.replace("_", " "), "engrave", 13, UiKit.SEPIA)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pv.add_child(pl)
		pr.add_child(pv)
	v.add_child(pr)
	var sr := _hbox(16)
	var cols := [UiKit.OXBLOOD, UiKit.NAVY, UiKit.GREEN, UiKit.OXBLOOD, UiKit.INK, UiKit.NAVY, UiKit.OXBLOOD]
	for i in UiKit.STAMPS.size():
		var holder := CenterContainer.new()
		holder.custom_minimum_size = Vector2(0, 76)
		holder.add_child(UiKit.stamp(UiKit.STAMPS[i].replace("_", " "), cols[i], [-6.0, 4.0, -3.0, 7.0, -5.0, 3.0, -8.0][i], 0.72))
		sr.add_child(holder)
	var custom := CenterContainer.new()
	custom.add_child(UiKit.stamp("VOID", UiKit.GREEN, 5.0, 0.9))
	sr.add_child(custom)
	v.add_child(sr)
	var row := _hbox(14)
	for pair in [[Color("a32420"), "V"], [UiKit.NAVY, "R"], [UiKit.GREEN, "C"], [UiKit.BRASS, "M"], [Color("5b2a6e"), "G"]]:
		row.add_child(UiKit.wax_seal(pair[0], pair[1], 80))
	var keys := _vbox(4)
	var k1 := _hbox(3)
	for k in ["E", "F", "G", "R", "V", "Q", "J", "M", "N", "H"]:
		k1.add_child(UiKit.key_cap(k))
	keys.add_child(k1)
	var k2 := _hbox(3)
	for k in ["Tab", "Esc", "1", "2", "3", "4", "5", "Shift", "Space"]:
		k2.add_child(UiKit.key_cap(k))
	keys.add_child(k2)
	row.add_child(keys)
	var meters := _vbox(2)
	for hv in [12.0, 48.0, 91.0]:
		meters.add_child(UiKit.heat_meter(hv))
	row.add_child(meters)
	row.add_child(UiKit.calendar(10, 29, 1929, "Black Tuesday"))
	row.add_child(UiKit.calendar(12, 5, 1933, "Repeal"))
	v.add_child(row)
	var br := _hbox(12)
	for bt in ["NORMAL", "PRESSED", "DISABLED"]:
		var b := Button.new()
		b.text = bt
		if bt == "PRESSED":
			b.toggle_mode = true
			b.button_pressed = true
		b.disabled = bt == "DISABLED"
		br.add_child(b)
	br.add_child(UiKit.ledger_figure("Clean money", 12450, "clean"))
	br.add_child(UiKit.ledger_figure("Owed to Rothstein", -1200, "debt"))
	var bars := _vbox(6)
	bars.add_child(UiKit.ledger_bar(62, 100, "green", 200))
	bars.add_child(UiKit.ledger_bar(35, 100, "red", 200))
	bars.add_child(UiKit.ledger_bar(80, 100, "ink", 200))
	br.add_child(bars)
	var cb := CheckBox.new()
	cb.text = "Paid up"
	cb.button_pressed = true
	br.add_child(cb)
	var le := LineEdit.new()
	le.placeholder_text = "name, address, occupation…"
	le.custom_minimum_size.x = 300
	br.add_child(le)
	v.add_child(br)
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	v.add_child(gap)
	var pan := _hbox(22)
	var specs := [["PanelContainer", "paper_panel()"], ["CardPanel", "card()"], ["LedgerPanel", "ledger()"],
		["LeatherPanel", "leather()"], ["TelegramPanel", "telegram()"], ["NewsPanel", "newsprint()"],
		["DecoPanel", "deco_frame()"], ["DecoNavyPanel", "deco_frame(true)"]]
	for s in specs:
		var col := _vbox(10)
		var pc := PanelContainer.new()
		pc.theme_type_variation = s[0]
		pc.custom_minimum_size = Vector2(172, 168)
		pc.add_child(Control.new())
		col.add_child(pc)
		var l := UiKit.label(s[1], "ledger_bold", 14, UiKit.INK)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		pan.add_child(col)
	v.add_child(pan)
