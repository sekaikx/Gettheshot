extends Control
## The family book (Tab, or the desk in your club): Family, Rackets, Heat, Rivals, Money.
## STUB: the FamilyBook piece replaces this (docs/REBUILD_2D.md, "FamilyBook").

var hud: Node
var _body: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.03, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_body = Label.new()
	_body.position = Vector2(60, 60)
	_body.add_theme_font_size_override("font_size", 18)
	add_child(_body)


func open() -> void:
	refresh()


func refresh() -> void:
	var me := int(Game.player(Net.my_id()).get("family", -1))
	var f := Game.fam(me)
	if f.is_empty():
		return
	var lines := ["The %s family (Tab to close)" % f["name"], ""]
	for c in Game.crew_of(me):
		lines.append("%s · %s · %s · loyalty %d · %s" % [c["name"], c["rank"], Rackets.TRAITS.get(c.get("trait", ""), {}).get("name", ""), c["loyalty"], c["task"]])
	lines.append("")
	for b in Game.shops_of(me):
		lines.append("%s · %s" % [b["name"], "owned" if int(b["owned_by"]) == me else "pays $%d" % b["rate"]])
	_body.text = "\n".join(lines)
