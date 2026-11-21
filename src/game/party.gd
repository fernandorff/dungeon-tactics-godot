class_name Party
## The player's party (port of group.ts): the 4 story members never leave, recruits are hired at the Tavern and can be
## dismissed, anyone changes class among the jobs, up to 4 go. A group is {members: [{id, name, cls, recruit}], deployed: [id]}.

const GROUP_KEY := "dt:party"
const GROUP_MAX := 8
const DEPLOY_MAX := 4
const RECRUIT_COST := 200
const NAME_MAX := 16


static func jobs() -> Array:
	return Content.data.jobs


static func default_group() -> Dictionary:
	var members: Array = []
	var ids: Array = []
	for m in Content.data.story:
		members.append(m.duplicate())
		ids.append(m.id)
	return {"members": members, "deployed": ids}


## r1 to r999, as the web game's /^r\d{1,3}$/
static func _is_recruit_id(id: String) -> bool:
	var digits := id.substr(1)
	if not id.begins_with("r") or digits.length() < 1 or digits.length() > 3:
		return false
	for c in digits:
		if c < "0" or c > "9":
			return false
	return true


## trust boundary: the story members always come back (with a valid saved class); a bad recruit disappears
static func parse_group(raw: Variant) -> Dictionary:
	var r: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	var list: Array = []
	if typeof(r.get("members")) == TYPE_ARRAY:
		for m in r.members:
			if typeof(m) == TYPE_DICTIONARY:
				list.append(m)
	var members: Array = []
	for s in Content.data.story:
		var m: Dictionary = s.duplicate()
		for x in list:
			if x.get("id") == s.id:
				if jobs().has(x.get("cls")):
					m.cls = x.cls
				break
		members.append(m)
	var recruits := 0
	for m in list:
		var id: Variant = m.get("id")
		var name: Variant = m.get("name")
		if typeof(id) != TYPE_STRING or not _is_recruit_id(id) or typeof(name) != TYPE_STRING or name.strip_edges() == "" or name.length() > NAME_MAX or not jobs().has(m.get("cls")):
			continue
		if not member({"members": members}, id).is_empty() or recruits >= GROUP_MAX - Content.data.story.size():
			continue
		members.append({"id": id, "name": name.strip_edges(), "cls": m.cls, "recruit": true})
		recruits += 1
	var deployed: Array = []
	if typeof(r.get("deployed")) == TYPE_ARRAY:
		for id in r.deployed:
			if typeof(id) == TYPE_STRING and not deployed.has(id) and not member({"members": members}, id).is_empty() and deployed.size() < DEPLOY_MAX:
				deployed.append(id)
	return {"members": members, "deployed": deployed if deployed.size() else default_group().deployed}


static func member(g: Dictionary, id: String) -> Dictionary:
	for m in g.members:
		if m.id == id:
			return m
	return {}


## hires a recruit of the class: costs gold, respects the cap; null if not possible
static func recruit(g: Dictionary, chest: Dictionary, cls: String) -> Variant:
	if g.members.size() >= GROUP_MAX or chest.gold < RECRUIT_COST:
		return null
	var k := 1
	while not member(g, "r%d" % k).is_empty():
		k += 1
	var name := "Recruta %d" % k
	for n in Content.data.recruit_names:
		if not g.members.any(func(m: Dictionary) -> bool: return m.name == n):
			name = n
			break
	var m := {"id": "r%d" % k, "name": name, "cls": cls, "recruit": true}
	var deployed: Array = g.deployed + [m.id] if g.deployed.size() < DEPLOY_MAX else g.deployed.duplicate()
	return {"group": {"members": g.members + [m], "deployed": deployed}, "chest": {"gold": chest.gold - RECRUIT_COST, "items": chest.items.duplicate()}}


## a recruit leaves; its equipment returns to the chest, so null when the chest has no room
static func dismiss(g: Dictionary, eq: Dictionary, chest: Dictionary, id: String) -> Variant:
	if not member(g, id).get("recruit", false):
		return null
	var back: Array = []
	var gear: Dictionary = eq.get(id, {})
	for s in gear:
		if gear[s]:
			back.append(gear[s])
	if chest.items.size() + back.size() > Chest.CHEST_MAX:
		return null
	var rest := eq.duplicate()
	rest.erase(id)
	var members: Array = g.members.filter(func(x: Dictionary) -> bool: return x.id != id)
	var deployed: Array = g.deployed.filter(func(x: String) -> bool: return x != id)
	if deployed.is_empty():
		deployed = [members[0].id]
	return {"group": {"members": members, "deployed": deployed}, "eq": rest, "chest": {"gold": chest.gold, "items": chest.items + back}}


static func change_class(g: Dictionary, id: String, cls: String) -> Dictionary:
	var members: Array = []
	for m in g.members:
		var n: Dictionary = m.duplicate()
		if n.id == id:
			n.cls = cls
		members.append(n)
	return {"members": members, "deployed": g.deployed.duplicate()}


## fields or removes from battle: at most 4 and never none; null if not possible
static func toggle_deploy(g: Dictionary, id: String) -> Variant:
	if g.deployed.has(id):
		if g.deployed.size() <= 1:
			return null
		return {"members": g.members, "deployed": g.deployed.filter(func(x: String) -> bool: return x != id)}
	if g.deployed.size() < DEPLOY_MAX and not member(g, id).is_empty():
		return {"members": g.members, "deployed": g.deployed + [id]}
	return null


## who goes first, in the deployment order, then who stays in town
static func roster(g: Dictionary) -> Array:
	var out: Array = []
	for id in g.deployed:
		out.append(member(g, id))
	for m in g.members:
		if not g.deployed.has(m.id):
			out.append(m)
	return out


## who goes to battle, each with the whole kit of their class and their equipment
static func heroes_for(g: Dictionary, eq: Dictionary = {}) -> Array:
	var out: Array = []
	for id in g.deployed:
		var m := member(g, id)
		var u := Roster.unit_from(m.cls, m.name)
		if eq.has(id):
			u.items = eq[id]
		out.append(u)
	return out
