extends Node

const PATH := "user://save.json"

var coins := 0
var owned_weapons: Array = ["lanca"]
var equipped := "lanca"
var perma := {}
var best_scores := {}
var haptics := true
var sound := true
var low_fx := false
var stats := {"runs": 0, "best_room": 0, "kills": 0, "bosses": 0}

var next_seed := 0


func _ready() -> void:
	load_data()
	apply_settings()


func daily_seed() -> int:
	return absi(Time.get_date_string_from_system().hash()) % 999999 + 1


func load_data() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not d is Dictionary:
		return
	coins = int(d.get("coins", 0))
	owned_weapons = d.get("owned_weapons", ["lanca"])
	equipped = d.get("equipped", "lanca")
	perma = d.get("perma", {})
	best_scores = d.get("best_scores", {})
	haptics = d.get("haptics", true)
	sound = d.get("sound", true)
	low_fx = d.get("low_fx", false)
	var s = d.get("stats", {})
	if s is Dictionary:
		stats.merge(s, true)
	if not GameData.WEAPONS.has(equipped):
		equipped = "lanca"


func save_data() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"coins": coins,
		"owned_weapons": owned_weapons,
		"equipped": equipped,
		"perma": perma,
		"best_scores": best_scores,
		"haptics": haptics,
		"sound": sound,
		"low_fx": low_fx,
		"stats": stats,
	}))


func apply_settings() -> void:
	AudioServer.set_bus_mute(0, not sound)


func record_run(room_reached: int, kills: int, bosses: int) -> void:
	stats["runs"] = int(stats["runs"]) + 1
	stats["best_room"] = maxi(int(stats["best_room"]), room_reached)
	stats["kills"] = int(stats["kills"]) + kills
	stats["bosses"] = int(stats["bosses"]) + bosses


func perma_level(id: String) -> int:
	return int(perma.get(id, 0))


func perma_cost(id: String) -> int:
	return int(GameData.PERMA[id]["base_cost"]) * (perma_level(id) + 1)


func buy_perma(id: String) -> bool:
	var cost := perma_cost(id)
	if coins < cost or perma_level(id) >= int(GameData.PERMA[id]["max"]):
		return false
	coins -= cost
	perma[id] = perma_level(id) + 1
	save_data()
	return true


func buy_weapon(id: String) -> bool:
	var cost := int(GameData.WEAPONS[id]["cost"])
	if coins < cost or id in owned_weapons:
		return false
	coins -= cost
	owned_weapons.append(id)
	equipped = id
	save_data()
	return true


func equip(id: String) -> void:
	if id in owned_weapons:
		equipped = id
		save_data()


func best_score(seed_value: int) -> int:
	return int(best_scores.get(str(seed_value), 0))


func record_score(seed_value: int, score: int) -> bool:
	if score <= best_score(seed_value):
		return false
	best_scores[str(seed_value)] = score
	return true
