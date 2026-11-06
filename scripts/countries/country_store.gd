extends RefCounted
## Reusable country definitions; no map coordinates or live simulation totals.
const Progression = preload("res://scripts/countries/nation_progression.gd")
const RULES_PATH = "res://data/country_rules/catalog.json"

static func rules() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	return parsed if parsed is Dictionary else {}

static func default_directory() -> String:
	return "res://data/countries" if OS.has_feature("editor") else "user://countries"

static func blank() -> Dictionary:
	return {"schema_version":1, "id":"", "name":"", "adjective":"", "description":"", "color":"#aa6644", "secondary_color":"#e5d5ac", "emblem":"raven", "culture":"northern", "faith":"ancestor_veneration", "government":"tribal", "tribal_profile":"clan_council", "traditions":[], "technology_tree":"tribal_to_medieval", "national_tree":"tribal_paths", "preferred_path":"raiding", "laws":{"authority":"council", "taxation":"contributions", "military_service":"seasonal_levies", "land_tenure":"communal", "religious_policy":"local_customs"}, "ai":{"aggression":50,"expansion":50,"diplomacy":50,"trade":50,"military_investment":50,"risk_tolerance":50}, "player_eligible":true,"ai_eligible":true,"archived":false,"build_plan":{"research_budget":1200,"skill_budget":6,"unlocks":[]}}

static func validate(data: Dictionary) -> PackedStringArray:
	var errors = PackedStringArray()
	var catalogue = rules()
	if catalogue.is_empty(): return ["Country rules could not be loaded."]
	var pattern = RegEx.create_from_string("^[A-Z][A-Z0-9_]{1,31}$")
	if not data.get("id") is String or pattern.search(str(data.get("id", ""))) == null:
		errors.append("ID must be 2–32 uppercase letters, numbers or underscores, starting with a letter.")
	for field in ["name","adjective"]:
		if not data.get(field) is String or str(data.get(field, "")).strip_edges().is_empty() or str(data.get(field, "")).length() > 80: errors.append(field.capitalize() + " is required (maximum 80 characters).")
	if not data.get("description") is String or str(data.get("description", "")).length() > 2000: errors.append("Description must be at most 2000 characters.")
	for field in ["color","secondary_color"]:
		if not data.get(field) is String or RegEx.create_from_string("^#[0-9a-fA-F]{6}$").search(str(data.get(field,""))) == null: errors.append("Choose an opaque RGB " + field + ".")
	if data.get("schema_version") != 1: errors.append("Unsupported country schema version.")
	if data.get("government") != "tribal": errors.append("Every country must start tribal.")
	if data.get("emblem") not in ["raven","longship","knot","spear"]: errors.append("Unknown emblem.")
	for pair in [["culture","cultures"],["faith","faiths"],["tribal_profile","tribal_profiles"]]:
		if not data.get(pair[0]) is String or not catalogue[pair[1]].has(data.get(pair[0],"")): errors.append("Unknown " + pair[0] + ".")
	if data.get("technology_tree") != catalogue.technology_tree.id or data.get("national_tree") != catalogue.national_tree.id: errors.append("Unknown progression tree.")
	if not catalogue.national_tree.branches.has(data.get("preferred_path","")): errors.append("Unknown preferred national path.")
	var traditions = data.get("traditions")
	if not traditions is Array or traditions.size() > 2: errors.append("Choose at most two starting traditions.")
	else:
		var seen = []
		for item in traditions:
			if not item is String or not catalogue.traditions.has(item) or item in seen: errors.append("Unknown or duplicate tradition.")
			seen.append(item)
	var laws = data.get("laws")
	if not laws is Dictionary: errors.append("Starting laws are required.")
	else:
		for group in catalogue.laws:
			if not laws.get(group) is String or not catalogue.laws[group].has(laws.get(group,"")): errors.append("Choose a valid " + group.replace("_"," ") + " law.")
	var ai = data.get("ai")
	if not ai is Dictionary: errors.append("AI preferences are required.")
	else:
		for axis in catalogue.ai_axes:
			var value = ai.get(axis)
			if not (value is float or value is int) or not is_finite(float(value)) or value < 0 or value > 100: errors.append("AI " + axis + " must be between 0 and 100.")
	for field in ["player_eligible","ai_eligible","archived"]:
		if not data.get(field) is bool: errors.append("Invalid " + field + " flag.")
	if data.has("build_plan"):
		var model = Progression.new()
		var problem = model.load_plan(data.build_plan)
		if not problem.is_empty(): errors.append("Build plan: " + problem)
	return errors

static func load_library(directory: String = "") -> Dictionary:
	if directory.is_empty(): directory = default_directory()
	var records: Array[Dictionary] = []
	var errors = PackedStringArray()
	if not DirAccess.dir_exists_absolute(directory): return {"records":records,"errors":errors}
	var files = DirAccess.get_files_at(directory)
	files.sort()
	var seen = {}
	for filename in files:
		if filename.get_extension().to_lower() != "json": continue
		var path = directory.path_join(filename)
		var file = FileAccess.open(path,FileAccess.READ)
		if file == null or file.get_length() > 1048576:
			errors.append(filename + ": unreadable or larger than 1 MB."); continue
		var parser = JSON.new()
		var parse_error = parser.parse(file.get_as_text())
		var parsed = parser.data
		if parse_error != OK or not parsed is Dictionary:
			errors.append(filename + ": invalid country JSON."); continue
		var problems = validate(parsed)
		if not problems.is_empty():
			errors.append(filename + ": " + "; ".join(problems)); continue
		if filename != parsed.id + ".json" or seen.has(parsed.id):
			errors.append(filename + ": duplicate ID or filename does not match ID."); continue
		seen[parsed.id] = true
		records.append(parsed)
	return {"records":records,"errors":errors}

static func save_country(data: Dictionary, directory: String = "", existing_id: String = "") -> String:
	var errors = validate(data)
	if not errors.is_empty(): return "\n".join(errors)
	if directory.is_empty(): directory = default_directory()
	if not existing_id.is_empty() and existing_id != data.id: return "Saved IDs cannot be changed. Duplicate this country to create a new ID."
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return "Cannot create the country folder."
	var path = directory.path_join(data.id + ".json")
	if existing_id.is_empty() and FileAccess.file_exists(path): return "That country ID already exists."
	var temporary = path + ".tmp"
	var file = FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return "Cannot write the country file."
	file.store_string(JSON.stringify(data,"\t") + "\n")
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK: return "Could not finish writing the country file."
	# Rename only after a complete write; keep a backup for recovery.
	var backup = path + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup) != OK: return "Cannot replace the country backup."
		if DirAccess.rename_absolute(path,backup) != OK: return "Cannot back up the previous country."
	error = DirAccess.rename_absolute(temporary,path)
	if error != OK:
		if FileAccess.file_exists(backup): DirAccess.rename_absolute(backup,path)
		return "Cannot replace the country file; previous version restored where possible."
	return ""
