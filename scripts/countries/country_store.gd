extends RefCounted
## Reusable country definitions; no map coordinates or live simulation totals.
const RULES_PATH = "res://data/country_rules/catalog.json"

static func rules() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	return parsed if parsed is Dictionary else {}

static func default_directory() -> String:
	return "res://data/countries" if OS.has_feature("editor") else "user://countries"

static func blank() -> Dictionary:
	return {"id":"", "name":""}

static func identity(data: Dictionary) -> Dictionary:
	# Gameplay state belongs to a running game, never the tribe library.
	var result = {"id":data.get("id",""),"name":data.get("name","")}
	if data.get("archived",false) == true: result["archived"] = true
	return result

static func map_color(id: String) -> Color:
	# Presentation fallback, derived from identity rather than an authored tribe stat.
	var value: int = 5381
	for character in id.to_utf8_buffer(): value = ((value * 33) + character) & 0x7fffffff
	return Color.from_hsv(float(value % 360) / 360.0,0.48,0.75)

static func validate(data: Dictionary) -> PackedStringArray:
	var errors = PackedStringArray()
	var pattern = RegEx.create_from_string("^[A-Z][A-Z0-9_]{1,31}$")
	if not data.get("id") is String or pattern.search(str(data.get("id", ""))) == null:
		errors.append("ID must be 2-32 uppercase letters, numbers or underscores, starting with a letter.")
	if not data.get("name") is String or str(data.get("name","")).strip_edges().is_empty() or str(data.get("name","")).length() > 80:
		errors.append("Name is required (maximum 80 characters).")
	if data.has("archived") and not data.archived is bool: errors.append("Invalid archive flag.")
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
		records.append(identity(parsed))
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
	file.store_string(JSON.stringify(identity(data),"\t") + "\n")
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
