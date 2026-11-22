class_name Moods
## Each map's mood (port of ambience-moods.ts): forest, field, crypt, frost or cave, found from the scenario id, and the
## light each one puts over the scene's.

## the maps by id; a split map `<id>½` takes its whole map's, Until Dawn is fought in Ash Wood
const KIND := {"ash_wood": "forest", "flooded_crypt": "crypt", "crypt_heart": "crypt", "frost_pass": "frost",
	"vauclair": "forest", "survival": "forest"}
## crawl rooms have a new id per seed: the theme at its end picks the mood
const ROOM_KIND := {"dungeon": "cave", "forest": "forest", "mountain": "frost"}
## the scene light on top of the usual one: sky and sun multiplied, the sun moved to `at` (Ash Wood: low, from the side,
## long shadows; Fernando found it "a bit dark" with sky 0.45 on Nov 13, so 0.7)
const LIGHT := {
	"forest": {"sky": 0.7, "sun": 0.95, "at": Vector3(-10, 7, 5)},
	"cave": {"sky": 0.55, "sun": 0.8, "at": Vector3(-6, 9, 4)},
}


static func kind_of(scenario_id: String) -> String:
	var id := scenario_id.trim_suffix(Content.HALF)
	if KIND.has(id):
		return KIND[id]
	return ROOM_KIND.get(CrawlGen.room_theme(id), "field")
