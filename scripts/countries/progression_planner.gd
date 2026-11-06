extends Window
signal plan_chosen(data: Dictionary)
const Progression = preload("res://scripts/countries/nation_progression.gd")
var model
var selected = ""

func _ready() -> void:
	close_requested.connect(hide)
	%Cancel.pressed.connect(hide)
	%TreeKind.item_selected.connect(func(_index): selected = ""; _refresh())
	%Canvas.node_selected.connect(func(id): selected = id; _refresh())
	%ResearchBudget.value_changed.connect(func(value): _set_budget("technology",int(value)))
	%SkillBudget.value_changed.connect(func(value): _set_budget("national",int(value)))
	%Unlock.pressed.connect(func():
		%Message.text = model.unlock(selected)
		_refresh())
	%Remove.pressed.connect(func():
		var removed = model.remove(selected)
		%Message.text = "Refunded %d nodes, including dependent unlocks." % removed.size()
		_refresh())
	%Reset.pressed.connect(func(): model.unlocked.clear(); _refresh())
	%UsePlan.pressed.connect(func(): plan_chosen.emit(model.plan()); hide())

func open_plan(data: Dictionary) -> void:
	model = Progression.new()
	var error = model.load_plan(data)
	selected = ""
	%Message.text = error
	%TreeKind.select(0)
	_refresh()
	popup_centered()

func _set_budget(tree: String, value: int) -> void:
	if model == null: return
	if value < model.spent(tree):
		%Message.text = "Remove unlocks before reducing the budget below spent points."
	elif tree == "technology": model.research_budget = value
	else: model.skill_budget = value
	_refresh()

func _refresh() -> void:
	if model == null: return
	%ResearchBudget.set_value_no_signal(model.research_budget)
	%SkillBudget.set_value_no_signal(model.skill_budget)
	%Balance.text = "%d research / %d skills left" % [model.remaining("technology"),model.remaining("national")]
	%Canvas.display(model,"technology" if %TreeKind.selected == 0 else "national",selected)
	%UsePlan.disabled = not model.errors.is_empty()
	%Unlock.disabled = true
	%Remove.disabled = true
	%Details.text = "Select a node. Lines show prerequisites within this tree; cross-tree requirements appear here. National specialties in each branch are alternatives."
	if model.nodes.has(selected):
		var node: Dictionary = model.nodes[selected]
		var requires = PackedStringArray()
		for id in node.requires: requires.append(model.nodes[id].name)
		var bonus = PackedStringArray()
		for stat in node.effects: bonus.append("%+.0f%% %s" % [node.effects[stat]*100,model.stats[stat]])
		var reason = model.blocked_reason(selected)
		%Details.text = node.name + "\n\n" + node.description + "\n\nRequires: " + (", ".join(requires) if not requires.is_empty() else "None") + "\nCost: " + str(int(node.cost)) + "\n\nProposed effects:\n" + "\n".join(bonus) + "\n\n" + ("Available" if reason.is_empty() else reason)
		%Unlock.disabled = not reason.is_empty()
		%Remove.disabled = selected not in model.unlocked
	var totals = model.effects()
	%Effects.text = "BUILD TOTALS (PREVIEW ONLY)\nAdditive percentage modifiers; not applied to gameplay."
	for stat in totals: %Effects.text += "\n%+.0f%% %s" % [totals[stat]*100,model.stats[stat]]
	if not model.errors.is_empty(): %Message.text = "\n".join(model.errors)
