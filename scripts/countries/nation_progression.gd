extends RefCounted
## Deterministic unlock rules shared by the planner and future runtime simulation.
const PATH = "res://data/country_rules/progression.json"
var nodes: Dictionary = {}
var stats: Dictionary = {}
var errors = PackedStringArray()
var unlocked: Array[String] = []
var research_budget: int = 1200
var skill_budget: int = 6

func _init(definition: Dictionary = {}) -> void:
	if definition.is_empty():
		var parser = JSON.new()
		if parser.parse(FileAccess.get_file_as_string(PATH)) != OK:
			errors.append("Cannot read progression definitions."); return
		definition = parser.data if parser.data is Dictionary else {}
	if definition.get("schema_version") != 1 or not definition.get("nodes") is Array or not definition.get("stats") is Dictionary:
		errors.append("Invalid progression catalogue."); return
	stats = definition.stats
	for entry in definition.nodes:
		if not entry is Dictionary or not entry.get("id") is String:
			errors.append("Invalid progression node."); continue
		if nodes.has(entry.id): errors.append("Duplicate node: " + entry.id); continue
		if entry.get("tree") not in ["technology","national"] or not entry.get("requires") is Array or not entry.get("effects") is Dictionary or not entry.get("name") is String or not entry.get("description") is String or not entry.get("exclusive_group") is String:
			errors.append("Invalid fields: " + entry.id); continue
		if not whole_number(entry.get("cost"),1,100000) or not whole_number(entry.get("column"),0,20) or not whole_number(entry.get("row"),0,20):
			errors.append("Invalid cost or position: " + entry.id); continue
		for stat in entry.effects:
			var value = entry.effects[stat]
			if not stats.has(stat) or not (value is float or value is int) or not is_finite(float(value)):
				errors.append("Invalid effect: " + entry.id)
		nodes[entry.id] = entry
	for id in nodes:
		var seen = []
		for prerequisite in nodes[id].requires:
			if not prerequisite is String or not nodes.has(prerequisite) or prerequisite in seen: errors.append("Unknown or duplicate prerequisite: " + id)
			seen.append(prerequisite)
		if _cyclic(id,[]): errors.append("Prerequisite cycle: " + id)

static func whole_number(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(float(value)) and value >= low and value <= high

func _cyclic(id: String, path: Array) -> bool:
	if id in path: return true
	if not nodes.has(id): return false
	var next = path.duplicate()
	next.append(id)
	for parent in nodes[id].requires:
		if parent is String and _cyclic(parent,next): return true
	return false

func spent(tree: String) -> int:
	var total = 0
	for id in unlocked:
		if nodes[id].tree == tree: total += int(nodes[id].cost)
	return total

func remaining(tree: String) -> int:
	return (research_budget if tree == "technology" else skill_budget) - spent(tree)

func blocked_reason(id: String) -> String:
	if not errors.is_empty(): return "Progression definitions are invalid."
	if not nodes.has(id): return "Unknown node."
	if id in unlocked: return "Already unlocked."
	var node: Dictionary = nodes[id]
	for parent in node.requires:
		if parent not in unlocked: return "Requires " + nodes[parent].name + "."
	if not node.exclusive_group.is_empty():
		for other in unlocked:
			if nodes[other].exclusive_group == node.exclusive_group: return "Alternative already chosen: " + nodes[other].name + "."
	if remaining(node.tree) < node.cost: return "Not enough " + ("research" if node.tree == "technology" else "national skill points") + "."
	return ""

func unlock(id: String) -> String:
	var reason = blocked_reason(id)
	if not reason.is_empty(): return reason
	unlocked.append(id)
	return ""

func remove(id: String) -> Array[String]:
	var removed: Array[String] = []
	if id not in unlocked: return removed
	unlocked.erase(id)
	removed.append(id)
	var changed = true
	while changed:
		changed = false
		for other in unlocked.duplicate():
			for parent in nodes[other].requires:
				if parent not in unlocked:
					unlocked.erase(other); removed.append(other); changed = true; break
	return removed

func effects() -> Dictionary:
	var totals = {}
	for id in unlocked:
		for stat in nodes[id].effects: totals[stat] = totals.get(stat,0.0) + float(nodes[id].effects[stat])
	return totals

func plan() -> Dictionary:
	return {"research_budget":research_budget,"skill_budget":skill_budget,"unlocks":unlocked.duplicate()}

func load_plan(data: Variant) -> String:
	# Transactional: a failed plan never partially changes this state.
	if not errors.is_empty(): return "Invalid progression definitions: " + "; ".join(errors)
	if not data is Dictionary or not data.get("unlocks") is Array or not whole_number(data.get("research_budget"),0,100000) or not whole_number(data.get("skill_budget"),0,100): return "Invalid build plan budgets or node list."
	var old = plan()
	unlocked.clear()
	research_budget = int(data.research_budget)
	skill_budget = int(data.skill_budget)
	var error = ""
	for id in data.unlocks:
		if not id is String: error = "Invalid node ID."; break
		error = unlock(id)
		if not error.is_empty(): break
	if not error.is_empty():
		unlocked.assign(old.unlocks)
		research_budget = old.research_budget
		skill_budget = old.skill_budget
	return error
