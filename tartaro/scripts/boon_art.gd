class_name BoonArt
## Pre-rendered boon art: god portraits (tools/blender/gods.py) and embossed
## emblems (tools/blender/emblems.py), plus the texts shown on boon cards.

const PORTRAITS := "res://art/gods/"
const EMBLEMS := "res://art/emblems/"

## What each boon's number means, for the "▸ stat" line on its card.
const STATS := {
	"ares": ["Dano extra", "+%s%%"],
	"apolo": ["Velocidade de ataque", "+%s%%"],
	"hermes": ["Movimento e recarga", "+%s%%"],
	"artemis": ["Chance de crítico", "+%s%%"],
	"hefesto": ["Projéteis", "+1"],
	"zeus": ["Chance de raio", "%s%%"],
	"poseidon": ["Dano da onda", "%s"],
	"atena": ["Vida máxima", "+%s"],
	"dionisio": ["Cura por abate", "%s"],
	"demeter": ["Coleta e XP", "+%s%%"],
	"hestia": ["Queimadura por segundo", "%s"],
	"boreas": ["Lentidão", "%s%%"],
	"selene": ["Luas orbitando", "+1"],
	"hecate": ["Dano da explosão", "%s"],
	"eolo": ["Cargas de dash", "+1"],
	"nemesis": ["Dano da vingança", "%s"],
	"iris": ["Ricochetes", "+1"],
	"tique": ["Óbolos extras", "+%s%%"],
	"ambrosia": ["Cura", "20"],
}

static var _emblems := {}


static func emblem(god: String) -> Texture2D:
	if not _emblems.has(god):
		var path := EMBLEMS + god + ".png"
		_emblems[god] = load(path) if ResourceLoader.exists(path) else null
	return _emblems[god]


static func portrait(god: String) -> Texture2D:
	var path := PORTRAITS + god + ".png"
	return load(path) if ResourceLoader.exists(path) else null


static func portrait_glow(god: String) -> Texture2D:
	var path := PORTRAITS + god + "_glow.png"
	return load(path) if ResourceLoader.exists(path) else null


## God whose art represents an offer (duos use their first god).
static func god_of(offer: Dictionary) -> String:
	if offer.get("duo", false):
		return offer["gods"][0]
	return offer["id"] if GameData.GODS.has(offer["id"]) else "olimpo"


static func god_color(god: String) -> Color:
	for b in GameData.BOONS:
		if b["id"] == god:
			return b["color"]
	return UI.GOLD


static func stat_line(offer: Dictionary) -> Array:
	if offer.get("duo", false):
		return ["Bênção Duo", "%s + %s" % [GameData.GODS[offer["gods"][0]]["name"].capitalize(), GameData.GODS[offer["gods"][1]]["name"].capitalize()]]
	var st: Array = STATS.get(offer["id"], ["", ""])
	var fmt: String = st[1]
	if fmt.contains("%s"):
		var v := float(offer.get("per", 0.0)) * float(offer.get("mult", 1.0))
		fmt = fmt % (str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v)
	return [st[0], fmt]


## What a boon does right now, with all its levels stacked.
static func current_effect(b: Dictionary, total: float, level: int) -> String:
	if b.has("gods"):
		return b["desc"]
	if b.has("per"):
		var v := float(b["per"]) * total
		return String(b["desc"]).replace("{v}", str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v)
	match String(b["id"]):
		"hefesto":
			return "+%d %s (espada: arco maior, cetro: +%d %s)" % [level, "projétil extra" if level == 1 else "projéteis extras", level, "salto" if level == 1 else "saltos"]
		"selene":
			return "%d %s ao seu redor e %s inimigos" % [level, "lua gira" if level == 1 else "luas giram", "fere" if level == 1 else "ferem"]
		"eolo":
			return "+%d %s de dash" % [level, "carga" if level == 1 else "cargas"]
		"iris":
			return "Projéteis ricocheteiam em +%d %s" % [level, "inimigo" if level == 1 else "inimigos"]
	return b["desc"]


## Card description with its numbers highlighted (BBCode).
static func rich_desc(text: String, accent: Color) -> String:
	var hex := accent.to_html(false)
	var re := RegEx.new()
	re.compile("([+]?\\d+(?:[.,]\\d+)?%?)")
	return re.sub(text, "[color=#%s]$1[/color]" % hex, true)


static func draw_emblem(ci: CanvasItem, god: String, center: Vector2, size: float, tint := Color.WHITE) -> bool:
	var tex := emblem(god)
	if tex == null:
		return false
	ci.draw_texture_rect(tex, Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size)), false, tint)
	return true
