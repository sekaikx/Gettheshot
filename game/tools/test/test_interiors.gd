extends Node2D

func _ready() -> void:
	Game.new_campaign({"seed": 1923, "families": 4}, [{"peer": 1, "name": "Alex", "family_name": "Vitale", "color": "#c42828"}])
	Game.running = false
	var plan: CityPlan = Game.plan
	var counts := {}
	for b in Game.biz:
		var lot: Dictionary = plan.lots[int(b["lot"])]
		counts[b["kind"]] = int(counts.get(b["kind"], 0)) + 1
		print("%3d %-10s lot %3d side %s size %.1f x %.1f yaw %.2f floors %d" % [b["id"], b["kind"], lot["id"], lot["side"], lot["size"][0], lot["size"][1], lot["yaw"], lot["floors"]])
	print(counts)
	get_tree().quit()
