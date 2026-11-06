extends SceneTree
const Progression = preload("res://scripts/countries/nation_progression.gd")
const Store = preload("res://scripts/countries/country_store.gd")
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	if not value: failures.append(message); push_error(message)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var model = Progression.new()
	check(model.errors.is_empty() and model.nodes.size()==30,"Catalogue must contain 30 valid nodes")
	check(not model.unlock("longships").is_empty() and model.unlocked.is_empty(),"Prerequisites must block without charging points")
	for id in ["clinker_hulls","longships","warband_customs","sea_raiders"]: check(model.unlock(id).is_empty(),"Valid prerequisite chain should unlock: " + id)
	check(model.spent("technology")==180 and model.spent("national")==3,"Currencies must be charged separately")
	check(not model.unlock("sea_raiders").is_empty() and model.spent("national")==3,"Duplicate unlock must not charge twice")
	check(model.unlock("shield_wall").is_empty(),"Another technology branch must be available")
	check(model.blocked_reason("border_reavers").contains("Alternative"),"Specialties in a national branch are exclusive")
	check(is_equal_approx(model.effects().raid_loot,0.2),"Effect preview must sum modifiers accurately")
	var saved = model.plan()
	var roundtrip = Progression.new()
	check(roundtrip.load_plan(saved).is_empty() and roundtrip.plan()==saved,"Plan should round-trip exactly")
	var removed = model.remove("clinker_hulls")
	check("longships" in removed and "sea_raiders" in removed and "warband_customs" in model.unlocked,"Removing a tech must refund cross-tree dependents, retaining independent nodes")
	check(model.spent("technology")==60 and model.spent("national")==1,"Cascade refunds must be exact")
	var before = model.plan()
	var bad = before.duplicate(true); bad.unlocks.append("unknown")
	check(not model.load_plan(bad).is_empty() and model.plan()==before,"Invalid plan load must be transactional")
	bad = before.duplicate(true); bad.research_budget=-1
	check(not model.load_plan(bad).is_empty(),"Negative budgets reject")
	bad = before.duplicate(true); bad.skill_budget=2.5
	check(not model.load_plan(bad).is_empty(),"Fractional budgets reject")
	var poor = Progression.new(); poor.research_budget=59
	check(not poor.unlock("clinker_hulls").is_empty() and poor.remaining("technology")==59,"Insufficient budget must not mutate state")
	var definition = JSON.parse_string(FileAccess.get_file_as_string(Progression.PATH))
	definition.nodes[0].requires = ["water_mills"]
	var cyclic = Progression.new(definition)
	check(not cyclic.errors.is_empty(),"Prerequisite cycles must reject")
	print("NATION PROGRESSION TESTS: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
