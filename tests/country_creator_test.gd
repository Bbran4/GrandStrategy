extends SceneTree
const Store = preload("res://scripts/countries/country_store.gd")
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	if not value: failures.append(message); push_error(message)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var starters = Store.load_library("res://data/countries")
	check(starters.errors.is_empty(),"Bundled tribe files must load cleanly")
	for id in ["FJORD","RAVENFELL","ASHEN_WOLF","IRON_PINE","STORM_COAST","ELKWOOD"]:
		var found = starters.records.filter(func(record): return record.id == id)
		check(found.size()==1 and found[0].size()==2,"Starter tribe must have only ID and name: "+id)
	var folder = "res://tests/output/countries_" + str(Time.get_ticks_usec())
	var data = Store.blank()
	data.id = "FJORD"
	data.name = "Fjord clans"
	check(Store.validate(data).is_empty(),"Valid tribal definition should pass")
	check(Store.save_country(data,folder).is_empty(),"New country should save")
	check(not Store.save_country(data,folder).is_empty(),"Duplicate ID must not overwrite")
	var loaded = Store.load_library(folder)
	check(loaded.records.size() == 1 and loaded.errors.is_empty(),"Saved country should round-trip")
	data.name = "Fjord union"
	check(Store.save_country(data,folder,"FJORD").is_empty(),"Display name may change with stable ID")
	check(FileAccess.file_exists(folder.path_join("FJORD.json.bak")),"Updating must keep previous version backup")
	var invalid = data.duplicate(true)
	invalid.id = "../ESCAPE"
	check(not Store.save_country(invalid,folder).is_empty(),"Path traversal ID must reject")
	invalid = data.duplicate(true); invalid.name = ""
	check(not Store.validate(invalid).is_empty(),"Empty names must reject")
	check(Store.blank().size()==2,"New tribes must contain only ID and name")
	var legacy = data.duplicate(true)
	legacy["laws"] = {"taxation":"levy"}
	legacy["build_plan"] = {"unlocks":["longships"]}
	check(Store.identity(legacy)==data,"Legacy gameplay choices must not enter tribe identity")
	check(Store.save_country(legacy,folder,"FJORD").is_empty(),"Legacy records can be resaved as identity only")
	var raw = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("FJORD.json")))
	check(raw.size()==2 and not raw.has("laws") and not raw.has("build_plan"),"Saving must not preserve pregame choices")
	invalid = data.duplicate(true); invalid.id = "OTHER"
	check(not Store.save_country(invalid,folder,"FJORD").is_empty(),"Existing IDs cannot change")
	var malformed = FileAccess.open(folder.path_join("broken.json"),FileAccess.WRITE)
	malformed.store_string("{ broken"); malformed.close()
	loaded = Store.load_library(folder)
	check(loaded.records.size() == 1 and loaded.errors.size() == 1,"Malformed file must not hide valid library entries")
	var scene = load("res://scenes/country_creator.tscn").instantiate()
	scene.storage_directory = folder
	root.add_child(scene)
	await process_frame
	check(scene.get_node("%CountryList").item_count == 1,"Creator loads saved country library")
	scene._edit(data,"FJORD")
	check(not scene.get_node("%CountryId").editable,"Saved ID must be read-only")
	scene.get_node("%CountryName").text = "Unsaved edit"
	scene._guard(scene._new_country)
	check(scene.get_node("%Unsaved").visible,"Switching with unsaved edits must ask before discarding")
	scene.get_node("%Unsaved").hide()
	scene.get_node("%Unsaved").canceled.emit()
	check(scene.get_node("%CountryName").text == "Unsaved edit","Cancel discard must retain edits")
	scene._duplicate_country()
	check(scene.existing_id.is_empty() and scene._collect().id == "FJORD_COPY","Duplicate must receive a new editable ID")
	check(scene._save(),"Duplicate should save independently")
	loaded = Store.load_library(folder)
	var duplicate = loaded.records.filter(func(record): return record.id == "FJORD_COPY")[0]
	check(duplicate.size()==2,"Saved tribes must have only ID and name")
	scene._archive()
	check(scene.current.get("archived",false) and scene.get_node("%CountryList").item_count == 1,"Archive must hide without deleting identity")
	scene._archive()
	check(not scene.current.get("archived",false),"Archived country can be restored")
	scene.get_node("%Search").text = "not found"
	scene.get_node("%Search").text_changed.emit("not found")
	check(scene.get_node("%CountryList").item_count == 0,"Search must filter country library")
	scene.queue_free()
	await process_frame
	print("COUNTRY CREATOR TESTS: ", "PASS" if failures.is_empty() else "FAIL " + str(failures))
	quit(0 if failures.is_empty() else 1)
