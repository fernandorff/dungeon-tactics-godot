class_name UnitClips
## Which clip a unit plays (port of the gesture table of fx.ts and playClip/standIn of unit-view.ts): each ability's
## gesture and its looping charge, the KayKit clips that loop, and the stand-ins for the models with their own rig.

const MAGIC_CHARGE := "Ranged_Magic_Spellcasting"
const BOW_CHARGE := "Ranged_Bow_Aiming_Idle"
## ability id → [gesture when acting, looping gesture while charging ("" for none)] (Nov 12: the same roles as FFT's)
const LOOKS := {
	"strike": ["Melee_1H_Attack_Chop", ""], "heavy_strike": ["Melee_2H_Attack_Chop", ""],
	"shield_bash": ["Melee_Block_Attack", ""], "spin": ["2H_Melee_Attack_Spin", ""], "shove": ["Melee_Block_Attack", ""],
	"shot": ["Ranged_Bow_Release", ""], "aimed_shot": ["Ranged_Bow_Release", BOW_CHARGE],
	"knock_shot": ["Ranged_Bow_Release", ""], "sand": ["Throw", ""], "focus": ["Ranged_Bow_Aiming_Idle", ""],
	"dagger": ["Melee_1H_Attack_Stab", ""], "firebolt": ["Ranged_Magic_Shoot", ""],
	"blast": ["Ranged_Magic_Raise", MAGIC_CHARGE], "shadow_wave": ["Ranged_Magic_Raise", MAGIC_CHARGE],
	"gust": ["Ranged_Magic_Shoot", MAGIC_CHARGE], "heal": ["Ranged_Magic_Raise", MAGIC_CHARGE],
	"stab": ["Melee_1H_Attack_Stab", ""], "throwing_knife": ["Throw", ""], "trip": ["Unarmed_Melee_Attack_Kick", ""],
	"deathblow": ["Melee_1H_Attack_Slice_Diagonal", ""], "cleave": ["Melee_2H_Attack_Chop", ""],
	"slam": ["Melee_Unarmed_Attack_Punch_A", ""], "lance": ["Melee_1H_Attack_Stab", ""], "sweep": ["2H_Melee_Attack_Spin", ""],
	"lance_jump": ["Melee_2H_Attack_Chop", "Jump_Idle"], # charges "in the air" and lands with the strike
}
## clips that repeat until another one replaces them
const LOOPING := ["Idle", "Walking_A", "Running_A", "Spellcast_Long", MAGIC_CHARGE, BOW_CHARGE, "Jump_Idle", "Cheer"]
## a model with its own rig (the Quaternius snake and swarm: Blender's `Armature|Action` names) plays the first of its own
## clips that stands in for the KayKit gesture; every gesture not listed is acting
const STAND_IN := [["Death", ["Death"]], ["Walking", ["Walk", "Flying"]], ["Running", ["Walk", "Flying"]],
	["Hit", ["Hit", "Jump"]], ["Jump", ["Jump", "Flying"]], ["Idle", ["Idle", "Flying"]], ["Cheer", ["Idle", "Flying"]],
	["", ["Attack"]]]
const FADE := 0.15 # the cross-fade between two clips, as the web's crossFadeFrom


static func gesture(ability: String) -> String:
	return LOOKS.get(ability, LOOKS.strike)[0]


static func charge(ability: String) -> String:
	var c: String = LOOKS.get(ability, LOOKS.strike)[1]
	return c if c != "" else "Spellcast_Long"


## the animation a player has for `name`: its own, the shared pack's, or a stand-in on an own rig; "" when none
static func find(ap: AnimationPlayer, name: String) -> String:
	if ap.has_animation(name):
		return name
	if ap.has_animation("pack/" + name):
		return "pack/" + name
	var own := ap.get_animation_list()
	for row in STAND_IN:
		if not name.begins_with(row[0]):
			continue
		for k in row[1]:
			for a in own:
				if a.contains("|") and a.ends_with("_" + k):
					return a
		return ""
	return ""


## plays `name` from the start, faded from the clip before; a once-only clip stops on its last frame
static func play(ap: AnimationPlayer, name: String, rate: float = 1.0) -> String:
	var a := find(ap, name)
	if a == "":
		return ""
	ap.play(a, FADE, rate)
	ap.seek(0.0, true)
	return a
