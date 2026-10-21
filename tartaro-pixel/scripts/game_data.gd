class_name GameData

static var WEAPON_ORDER := ["lanca", "arco", "espada", "cetro"]

static var WEAPONS := {
	"lanca": {
		"name": "Lança de Bronze",
		"desc": "Arremessos rápidos no inimigo mais próximo.",
		"cost": 0, "damage": 1, "interval": 0.32, "range": 170.0,
		"color": Color("f5c542"), "sound": "shoot",
	},
	"arco": {
		"name": "Arco de Ártemis",
		"desc": "Leque de 3 flechas de longo alcance que atravessam um inimigo.",
		"cost": 80, "damage": 1, "interval": 0.55, "range": 240.0,
		"color": Color("9be36d"), "sound": "arrow",
	},
	"espada": {
		"name": "Lâmina de Ares",
		"desc": "Golpe em arco de perto. Dano alto, exige coragem.",
		"cost": 150, "damage": 3, "interval": 0.42, "range": 52.0,
		"color": Color("ff5e57"), "sound": "slash",
	},
	"cetro": {
		"name": "Cetro de Zeus",
		"desc": "Raio que salta entre 3 inimigos.",
		"cost": 220, "damage": 2, "interval": 0.62, "range": 150.0,
		"color": Color("7fd4ff"), "sound": "zap",
	},
}

static var PERMA := {
	"vida": {"name": "Vitalidade", "desc": "+10 de vida máxima", "max": 10, "base_cost": 40},
	"forca": {"name": "Força", "desc": "+10% de dano", "max": 10, "base_cost": 60},
	"fortuna": {"name": "Fortuna", "desc": "+25% de óbolos ganhos", "max": 4, "base_cost": 80},
}
static var PERMA_ORDER := ["vida", "forca", "fortuna"]

static var RARITIES := [
	{"name": "COMUM", "mult": 1.0, "weight": 58, "color": Color("c8c4d8")},
	{"name": "RARO", "mult": 1.5, "weight": 28, "color": Color("4aa3ff")},
	{"name": "ÉPICO", "mult": 2.0, "weight": 11, "color": Color("c56cff")},
	{"name": "LENDÁRIO", "mult": 3.0, "weight": 3, "color": Color("ffb142")},
]

static var BOONS := [
	{"id": "ares", "god": "ARES", "name": "Fúria de Ares", "desc": "+{v}% de dano", "per": 20, "max": 5, "color": Color("ff5e57")},
	{"id": "apolo", "god": "APOLO", "name": "Ritmo de Apolo", "desc": "+{v}% de velocidade de ataque", "per": 15, "max": 5, "color": Color("ffb142")},
	{"id": "hermes", "god": "HERMES", "name": "Sandálias de Hermes", "desc": "+{v}% de movimento e recarga do dash", "per": 12, "max": 4, "color": Color("f7f1e3")},
	{"id": "artemis", "god": "ÁRTEMIS", "name": "Olho de Ártemis", "desc": "+{v}% de chance de crítico", "per": 10, "max": 5, "color": Color("9be36d")},
	{"id": "hefesto", "god": "HEFESTO", "name": "Forja de Hefesto", "desc": "+1 projétil (espada: arco maior, cetro: +1 salto)", "flat": true, "max": 3, "color": Color("cd6133")},
	{"id": "zeus", "god": "ZEUS", "name": "Ira de Zeus", "desc": "+{v}% de chance de raio extra por acerto", "per": 15, "max": 4, "color": Color("7fd4ff")},
	{"id": "poseidon", "god": "POSEIDON", "name": "Onda de Poseidon", "desc": "O dash termina numa onda de {v} de dano", "per": 3, "max": 4, "color": Color("34ace0")},
	{"id": "atena", "god": "ATENA", "name": "Égide de Atena", "desc": "+{v} de vida máxima e cura o mesmo", "per": 15, "max": 4, "color": Color("d1ccc0")},
	{"id": "dionisio", "god": "DIONÍSIO", "name": "Banquete de Dionísio", "desc": "Cura {v} de vida a cada abate", "per": 0.5, "max": 3, "color": Color("b06cff")},
	{"id": "demeter", "god": "DEMÉTER", "name": "Colheita de Deméter", "desc": "+{v}% de raio de coleta e XP", "per": 40, "max": 3, "color": Color("e1b12c")},
	{"id": "hestia", "god": "HÉSTIA", "name": "Chama de Héstia", "desc": "Acertos queimam: {v} de dano por segundo", "per": 1, "max": 4, "color": Color("ff8c3a")},
	{"id": "boreas", "god": "BÓREAS", "name": "Sopro de Bóreas", "desc": "Acertos deixam inimigos {v}% mais lentos", "per": 15, "max": 3, "color": Color("a8e6ff")},
	{"id": "selene", "god": "SELENE", "name": "Luas de Selene", "desc": "+1 lua que gira ao seu redor e fere inimigos", "flat": true, "max": 4, "color": Color("e0e6ff")},
	{"id": "hecate", "god": "HÉCATE", "name": "Maldição de Hécate", "desc": "Inimigos explodem ao morrer ({v} de dano em área)", "per": 3, "max": 4, "color": Color("8e44ad")},
	{"id": "eolo", "god": "ÉOLO", "name": "Ventos de Éolo", "desc": "+1 carga de dash", "flat": true, "max": 2, "color": Color("c7ecee")},
	{"id": "nemesis", "god": "NÊMESIS", "name": "Vingança de Nêmesis", "desc": "Ao ser atingido, explode causando {v} de dano", "per": 8, "max": 3, "color": Color("c0392b")},
	{"id": "iris", "god": "ÍRIS", "name": "Prisma de Íris", "desc": "Projéteis ricocheteiam em +1 inimigo", "flat": true, "max": 3, "color": Color("ff9ff3"), "weapons": ["lanca", "arco"]},
	{"id": "tique", "god": "TIQUE", "name": "Sorte de Tique", "desc": "+{v}% de óbolos e um pouco mais de crítico", "per": 30, "max": 3, "color": Color("ffd84a")},
]

static var DUOS := [
	{"id": "tempestade", "gods": ["zeus", "poseidon"], "god": "ZEUS + POSEIDON", "name": "Tempestade", "desc": "A onda do dash lança raios em até 3 inimigos"},
	{"id": "golpe_mortal", "gods": ["ares", "artemis"], "god": "ARES + ÁRTEMIS", "name": "Golpe Mortal", "desc": "Críticos causam dano x3 em vez de x2"},
	{"id": "frenesi", "gods": ["hermes", "apolo"], "god": "HERMES + APOLO", "name": "Frenesi", "desc": "Após o dash, +60% de velocidade de ataque por 2s"},
	{"id": "inferno_gelido", "gods": ["hestia", "boreas"], "god": "HÉSTIA + BÓREAS", "name": "Inferno Gélido", "desc": "Inimigos lentos sofrem queimadura dobrada"},
	{"id": "eclipse", "gods": ["selene", "hecate"], "god": "SELENE + HÉCATE", "name": "Eclipse", "desc": "Luas giram 2x mais rápido, maiores e com dano dobrado"},
	{"id": "fartura", "gods": ["dionisio", "demeter"], "god": "DIONÍSIO + DEMÉTER", "name": "Fartura", "desc": "Cada alma coletada cura 1 de vida"},
]
static var DUO_COLOR := Color("ffd84a")

static var AMBROSIA := {"id": "ambrosia", "god": "OLIMPO", "name": "Ambrosia", "desc": "Cura 20 de vida", "flat": true, "max": 999, "color": Color("ffd84a")}

static var REWARDS := {
	"boon": {"name": "BÊNÇÃO", "short": "B", "color": Color("ffd84a"), "weight": 40},
	"coins": {"name": "ÓBOLOS", "short": "$", "color": Color("e1b12c"), "weight": 18},
	"heal": {"name": "AMBROSIA", "short": "+", "color": Color("ff6b81"), "weight": 15},
	"maxhp": {"name": "CORAÇÃO", "short": "V", "color": Color("e74c3c"), "weight": 12},
	"forge": {"name": "BIGORNA", "short": "F", "color": Color("cd6133"), "weight": 15},
	"boon_epic": {"name": "DÁDIVA", "short": "B", "color": Color("c56cff"), "weight": 0},
}

const ROOMS_PER_BIOME := 5

static var BIOMES := [
	{
		"name": "TÁRTARO", "floor_a": Color("1d1a2b"), "floor_b": Color("221e33"), "deco": Color("2f2945"),
		"edge": Color("4a3f6b"), "pillar": Color("3a3352"), "hazard": Color(0, 0, 0, 0),
		"enemies": [Enemy.Kind.SHADE, Enemy.Kind.SHADE, Enemy.Kind.WISP, Enemy.Kind.BRUTE], "boss": "cerbero",
	},
	{
		"name": "ASFÓDELO", "floor_a": Color("1a2320"), "floor_b": Color("1f2a26"), "deco": Color("33463c"),
		"edge": Color("4f6b55"), "pillar": Color("3d5246"), "hazard": Color("6ab04c"),
		"enemies": [Enemy.Kind.SHADE, Enemy.Kind.ARCHER, Enemy.Kind.BOMBER, Enemy.Kind.WISP, Enemy.Kind.BRUTE], "boss": "medusa",
	},
	{
		"name": "ELÍSIO", "floor_a": Color("2a2516"), "floor_b": Color("302a1a"), "deco": Color("4a4128"),
		"edge": Color("8a7a3f"), "pillar": Color("5c5232"), "hazard": Color("ff6b3a"),
		"enemies": [Enemy.Kind.WISP, Enemy.Kind.ARCHER, Enemy.Kind.BOMBER, Enemy.Kind.BRUTE, Enemy.Kind.SHADE], "boss": "talos",
	},
]

static var BOSSES := {
	"cerbero": {
		"name": "CÉRBERO", "title": "Guardião do Tártaro", "hp": 220, "damage": 12, "speed": 45.0,
		"radius": 16.0, "color": Color("7a2a2a"), "bullet": Color("ff7f50"),
		"p1": [
			{"do": "spread", "count": 3, "spread": 0.5, "speed": 115.0, "repeat": 3, "gap": 0.5, "heads": true},
			{"do": "wait", "t": 0.9},
			{"do": "charge", "repeat": 2, "speed": 270.0},
			{"do": "wait", "t": 0.7},
			{"do": "summon", "kind": Enemy.Kind.SHADE, "count": 3},
			{"do": "wait", "t": 1.0},
		],
		"p2": [
			{"do": "spread", "count": 4, "spread": 0.7, "speed": 130.0, "repeat": 4, "gap": 0.4, "heads": true},
			{"do": "ring", "count": 18, "repeat": 3, "gap": 0.55, "rot": 0.17, "speed": 95.0},
			{"do": "charge", "repeat": 3, "speed": 320.0},
			{"do": "summon", "kind": Enemy.Kind.WISP, "count": 4},
			{"do": "wait", "t": 0.6},
		],
	},
	"medusa": {
		"name": "MEDUSA", "title": "A Górgona de Asfódelo", "hp": 380, "damage": 12, "speed": 35.0,
		"radius": 13.0, "color": Color("3e8e5e"), "bullet": Color("9be36d"),
		"p1": [
			{"do": "spiral", "t": 3.0, "gap": 0.13, "arms": 2, "spin": 2.2, "speed": 95.0},
			{"do": "wait", "t": 0.6},
			{"do": "beam", "repeat": 2},
			{"do": "teleport"},
			{"do": "spread", "count": 3, "spread": 0.3, "speed": 150.0, "repeat": 4, "gap": 0.3},
			{"do": "summon", "kind": Enemy.Kind.ARCHER, "count": 2},
			{"do": "wait", "t": 1.0},
		],
		"p2": [
			{"do": "spiral", "t": 3.5, "gap": 0.12, "arms": 4, "spin": 2.6, "speed": 100.0},
			{"do": "beam", "repeat": 3},
			{"do": "teleport"},
			{"do": "ring", "count": 16, "repeat": 2, "gap": 0.5, "rot": 0.2, "speed": 110.0},
			{"do": "summon", "kind": Enemy.Kind.BOMBER, "count": 3},
			{"do": "wait", "t": 0.6},
		],
	},
	"talos": {
		"name": "TALOS", "title": "O Gigante de Bronze", "hp": 600, "damage": 14, "speed": 30.0,
		"radius": 18.0, "color": Color("b87333"), "bullet": Color("ffb142"),
		"p1": [
			{"do": "ring", "count": 24, "repeat": 3, "gap": 0.75, "gap_size": 5, "speed": 90.0},
			{"do": "wait", "t": 0.5},
			{"do": "meteors", "count": 5},
			{"do": "charge", "repeat": 2, "speed": 300.0, "bounce": true},
			{"do": "wait", "t": 1.0},
		],
		"p2": [
			{"do": "ring", "count": 30, "repeat": 4, "gap": 0.55, "gap_size": 5, "speed": 100.0},
			{"do": "meteors", "count": 8},
			{"do": "spread", "count": 9, "spread": 1.2, "speed": 120.0, "repeat": 3, "gap": 0.45},
			{"do": "charge", "repeat": 3, "speed": 340.0, "bounce": true},
			{"do": "summon", "kind": Enemy.Kind.BRUTE, "count": 2},
			{"do": "wait", "t": 0.6},
		],
	},
}
