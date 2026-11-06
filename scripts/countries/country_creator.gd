extends Control
const Store = preload("res://scripts/countries/country_store.gd")
@export_dir var storage_directory: String = ""
var records: Array[Dictionary] = []
var current: Dictionary = {}
var baseline: Dictionary = {}
var existing_id: String = ""
var pending_action: Callable
var dirty = false
var last_form: Dictionary = {}
var prior_auto_quit = true

func _ready() -> void:
	if storage_directory.is_empty(): storage_directory = Store.default_directory()
	prior_auto_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
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
	_reload()
	_new_country()

func _exit_tree() -> void:
	get_tree().auto_accept_quit = prior_auto_quit

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: _guard(func(): get_tree().quit())

func _reload() -> void:
	var result = Store.load_library(storage_directory)
	records.assign(result.records)
	%Status.text = "Country folder: " + ProjectSettings.globalize_path(storage_directory)
	if not result.errors.is_empty(): %Status.text += "\nSkipped invalid files: " + "; ".join(result.errors)
	_refresh_list()

func _refresh_list() -> void:
	%CountryList.clear()
	for record in records:
		if record.get("archived",false) and not %ShowArchived.button_pressed: continue
		var query = %Search.text.strip_edges().to_lower()
		if not query.is_empty() and not (record.name + " " + record.id).to_lower().contains(query): continue
		%CountryList.add_item(record.name + (" (archived)" if record.get("archived",false) else ""))
		var index = %CountryList.item_count-1
		%CountryList.set_item_metadata(index,record.id)
		%CountryList.set_item_tooltip(index,record.id)
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
	current = Store.identity(data)
	existing_id = saved_id
	%CountryId.text = current.id
	%CountryId.editable = saved_id.is_empty()
	%CountryName.text = current.name
	baseline = _collect().duplicate(true)
	last_form = {}
	dirty = false
	_refresh_list()

func _collect() -> Dictionary:
	if current.is_empty(): return {}
	var data = current.duplicate(true)
	data.id = %CountryId.text.strip_edges().to_upper()
	data.name = %CountryName.text.strip_edges()
	return data

func _process(_delta: float) -> void:
	if current.is_empty(): return
	var data = _collect()
	if data == last_form: return
	last_form = data.duplicate(true)
	dirty = data != baseline
	%SaveButton.text = "Save tribe *" if dirty else "Save tribe"
	%ArchiveButton.disabled = existing_id.is_empty()
	%ArchiveButton.text = "Restore tribe" if data.get("archived",false) else "Archive tribe"
	%PreviewName.text = data.name if not data.name.is_empty() else "Unnamed tribe"
	%PreviewSummary.text = "ID: " + (data.id if not data.id.is_empty() else "not set")
	var errors = Store.validate(data)
	if existing_id.is_empty() and FileAccess.file_exists(storage_directory.path_join(data.id+".json")): errors.append("That country ID already exists.")
	%Validation.text = "Ready to save.\n\nLaws, taxation, technology and skills will be chosen during the game." if errors.is_empty() else "Please fix:\n" + "\n".join(errors)
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
	data.erase("archived")
	_edit(data,"")
	# Unsaved duplicates must trigger the discard guard even before further edits.
	baseline = Store.blank()
	last_form = {}
	%Status.text = "Duplicate created. Choose a unique ID and save it."

func _request_archive() -> void:
	if existing_id.is_empty(): return
	_guard(func():
		if current.get("archived",false): _archive()
		else: %ArchiveConfirm.popup_centered())

func _archive() -> void:
	var data = baseline.duplicate(true)
	data["archived"] = not data.get("archived",false)
	var error = Store.save_country(data,storage_directory,existing_id)
	if not error.is_empty(): %Status.text = error; return
	_edit(data,data.id)
	_reload()
	%Status.text = "Country archived; existing map references are preserved." if data.get("archived",false) else "Country restored."
