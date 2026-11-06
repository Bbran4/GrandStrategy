extends Control
const Store = preload("res://scripts/countries/country_store.gd")
const EMBLEMS = {"raven":preload("res://assets/country_emblems/raven.svg"),"longship":preload("res://assets/country_emblems/longship.svg"),"knot":preload("res://assets/country_emblems/knot.svg"),"spear":preload("res://assets/country_emblems/spear.svg")}
@export_dir var storage_directory: String = ""
var catalogue: Dictionary
var records: Array[Dictionary] = []
var current: Dictionary = {}
var baseline: Dictionary = {}
var existing_id: String = ""
var pending_action: Callable
var dirty = false
var last_form: Dictionary = {}
var prior_auto_quit = true

func _ready() -> void:
	catalogue = Store.rules()
	if storage_directory.is_empty(): storage_directory = Store.default_directory()
	prior_auto_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	for pair in [["TribalProfile","tribal_profiles"],["Culture","cultures"],["Faith","faiths"]]: _options(get_node("%"+pair[0]),catalogue[pair[1]])
	_options(%Emblem,{"raven":"Raven","longship":"Longship","knot":"Knot","spear":"Spear"})
	_options(%PreferredPath,catalogue.national_tree.branches)
	for group in catalogue.laws: _options(_field(group),catalogue.laws[group])
	for id in catalogue.traditions:
		var choice = CheckBox.new()
		choice.text = catalogue.traditions[id]
		choice.set_meta("id",id)
		%Traditions.add_child(choice)
	%CountryList.item_selected.connect(_on_item_selected)
	%Search.text_changed.connect(func(_value): _refresh_list())
	%ShowArchived.toggled.connect(func(_value): _refresh_list())
	%NewButton.pressed.connect(func(): _guard(_new_country))
	%DuplicateButton.pressed.connect(_duplicate_country)
	%SaveButton.pressed.connect(_save)
	%RevertButton.pressed.connect(func(): _guard(func(): _edit(baseline,existing_id)))
	%BackButton.pressed.connect(func(): _guard(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn")))
	%ArchiveButton.pressed.connect(_request_archive)
	%ArchiveConfirm.confirmed.connect(_archive)
	%Unsaved.confirmed.connect(func():
		if pending_action.is_valid(): pending_action.call()
		pending_action = Callable())
	%Unsaved.canceled.connect(func(): pending_action = Callable(); _refresh_list())
	%PlanButton.pressed.connect(func():
		$ProgressionPlanner.open_plan(current.get("build_plan",Store.blank().build_plan)))
	$ProgressionPlanner.plan_chosen.connect(func(plan):
		current["build_plan"] = plan.duplicate(true)
		last_form = {})
	_reload()
	_new_country()

func _exit_tree() -> void:
	get_tree().auto_accept_quit = prior_auto_quit

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: _guard(func(): get_tree().quit())

func _field(id: String) -> Node:
	return get_node("%" + id.to_pascal_case())

func _options(button: OptionButton, values: Dictionary) -> void:
	button.clear()
	for id in values:
		button.add_item(values[id])
		button.set_item_metadata(button.item_count-1,id)

func _select(button: OptionButton, id: String) -> void:
	for i in button.item_count:
		if button.get_item_metadata(i) == id: button.select(i); return

func _choice(button: OptionButton) -> String:
	return str(button.get_item_metadata(button.selected)) if button.selected >= 0 else ""

func _reload() -> void:
	var result = Store.load_library(storage_directory)
	records.assign(result.records)
	%Status.text = "Country folder: " + ProjectSettings.globalize_path(storage_directory)
	if not result.errors.is_empty(): %Status.text += "\nSkipped invalid files: " + "; ".join(result.errors)
	_refresh_list()

func _refresh_list() -> void:
	%CountryList.clear()
	for record in records:
		if record.archived and not %ShowArchived.button_pressed: continue
		var query = %Search.text.strip_edges().to_lower()
		if not query.is_empty() and not (record.name + " " + record.id).to_lower().contains(query): continue
		%CountryList.add_item(record.name + "  [" + record.id + "]" + (" (archived)" if record.archived else ""))
		var index = %CountryList.item_count-1
		%CountryList.set_item_metadata(index,record.id)
		if record.id == existing_id: %CountryList.select(index)

func _on_item_selected(index: int) -> void:
	var id = str(%CountryList.get_item_metadata(index))
	_guard(func():
		for record in records:
			if record.id == id: _edit(record,id); return)

func _guard(action: Callable) -> void:
	dirty = _collect() != baseline
	if dirty:
		pending_action = action
		%Unsaved.popup_centered()
	else: action.call()

func _new_country() -> void:
	_edit(Store.blank(),"")

func _edit(data: Dictionary, saved_id: String) -> void:
	current = data.duplicate(true)
	existing_id = saved_id
	%CountryId.text = current.id
	%CountryId.editable = saved_id.is_empty()
	%CountryName.text = current.name
	%Adjective.text = current.adjective
	%Description.text = current.description
	%PrimaryColor.color = Color(current.color)
	%SecondaryColor.color = Color(current.secondary_color)
	_select(%Emblem,current.emblem)
	_select(%TribalProfile,current.tribal_profile)
	_select(%Culture,current.culture)
	_select(%Faith,current.faith)
	_select(%PreferredPath,current.preferred_path)
	%PlayerEligible.button_pressed = current.player_eligible
	%AiEligible.button_pressed = current.ai_eligible
	for group in catalogue.laws: _select(_field(group),current.laws[group])
	for axis in catalogue.ai_axes: _field(axis).value = current.ai[axis]
	for choice in %Traditions.get_children(): choice.button_pressed = choice.get_meta("id") in current.traditions
	baseline = _collect().duplicate(true)
	last_form = {}
	dirty = false
	_refresh_list()

func _collect() -> Dictionary:
	if current.is_empty(): return {}
	var data = current.duplicate(true)
	data.id = %CountryId.text.strip_edges().to_upper()
	data.name = %CountryName.text.strip_edges()
	data.adjective = %Adjective.text.strip_edges()
	data.description = %Description.text
	data.color = "#" + %PrimaryColor.color.to_html(false)
	data.secondary_color = "#" + %SecondaryColor.color.to_html(false)
	data.emblem = _choice(%Emblem)
	data.tribal_profile = _choice(%TribalProfile)
	data.culture = _choice(%Culture)
	data.faith = _choice(%Faith)
	data.preferred_path = _choice(%PreferredPath)
	data.player_eligible = %PlayerEligible.button_pressed
	data.ai_eligible = %AiEligible.button_pressed
	data.traditions = []
	for choice in %Traditions.get_children():
		if choice.button_pressed: data.traditions.append(choice.get_meta("id"))
	for group in catalogue.laws: data.laws[group] = _choice(_field(group))
	for axis in catalogue.ai_axes: data.ai[axis] = int(_field(axis).value)
	return data

func _process(_delta: float) -> void:
	if current.is_empty(): return
	var data = _collect()
	if data == last_form: return
	last_form = data.duplicate(true)
	dirty = data != baseline
	%SaveButton.text = "Save country *" if dirty else "Save country"
	%ArchiveButton.disabled = existing_id.is_empty()
	%ArchiveButton.text = "Restore country" if data.archived else "Archive country"
	%Flag.color = Color(data.color)
	%FlagEmblem.texture = EMBLEMS[data.emblem]
	%FlagEmblem.modulate = Color(data.secondary_color)
	%PreviewName.text = data.name if not data.name.is_empty() else "Unnamed tribe"
	%PreviewSummary.text = "TRIBAL" + (" / ARCHIVED" if data.archived else "") + "\n" + catalogue.tribal_profiles[data.tribal_profile] + "\n" + catalogue.cultures[data.culture] + " / " + catalogue.faiths[data.faith] + "\nNational path: " + catalogue.national_tree.branches[data.preferred_path] + "\nTraditions: %d / 2" % data.traditions.size()
	var plan: Dictionary = data.get("build_plan",Store.blank().build_plan)
	%PlanSummary.text = "Saved build plan: %d unlocks. Preview budgets: %d research / %d skills. This plan does not grant starting unlocks." % [plan.unlocks.size(),plan.research_budget,plan.skill_budget]
	var errors = Store.validate(data)
	if existing_id.is_empty() and FileAccess.file_exists(storage_directory.path_join(data.id+".json")): errors.append("That country ID already exists.")
	%Validation.text = "Ready to save.\n\nProgression, law effects and AI behavior are definitions for future gameplay." if errors.is_empty() else "Please fix:\n" + "\n".join(errors)
	%Validation.modulate = Color("b9ccba") if errors.is_empty() else Color("efba89")
	%SaveButton.disabled = not errors.is_empty()

func _save() -> bool:
	var data = _collect()
	var error = Store.save_country(data,storage_directory,existing_id)
	if not error.is_empty(): %Status.text = error; return false
	_edit(data,data.id)
	_reload()
	%Status.text = "Saved " + data.name + " (" + data.id + ")."
	return true

func _duplicate_country() -> void:
	# A duplicate preserves the current form, including unsaved edits.
	var data = _collect()
	var original = data.id if not data.id.is_empty() else "TRIBE"
	var candidate = original.left(25) + "_COPY"
	var suffix = 2
	while FileAccess.file_exists(storage_directory.path_join(candidate+".json")):
		candidate = original.left(22) + "_COPY" + str(suffix); suffix += 1
	data.id = candidate
	data.name = (data.name + " copy").left(80)
	data.archived = false
	_edit(data,"")
	# Unsaved duplicates must trigger the discard guard even before further edits.
	baseline = Store.blank()
	last_form = {}
	%Status.text = "Duplicate created. Choose a unique ID and save it."

func _request_archive() -> void:
	if existing_id.is_empty(): return
	_guard(func():
		if current.archived: _archive()
		else: %ArchiveConfirm.popup_centered())

func _archive() -> void:
	var data = baseline.duplicate(true)
	data.archived = not data.archived
	var error = Store.save_country(data,storage_directory,existing_id)
	if not error.is_empty(): %Status.text = error; return
	_edit(data,data.id)
	_reload()
	%Status.text = "Country archived; existing map references are preserved." if data.archived else "Country restored."
