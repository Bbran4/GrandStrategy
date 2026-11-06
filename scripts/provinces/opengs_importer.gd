extends RefCounted
const Data = preload("res://scripts/provinces/province_map_data.gd")
const MAX_REGIONS = 65535

static func load_folder(folder: String, heightmap: Image, settings: Dictionary) -> Dictionary:
	if heightmap == null: return {"error": "Generate the source terrain before importing provinces."}
	var paths = {}
	for spec in [
		["provinces", ["provinces.png", "province_map.png", "province.png", "province_image.png"], true],
		["territories", ["territories.png", "territory_map.png", "territory.png", "territory_image.png"], true],
		["province_definitions", ["province_definitions.json", "province_data.json", "provinces.json"], false],
		["territory_definitions", ["territory_definitions.json", "territory_data.json", "territories.json"], false],
		["history", ["territory_history.json"], false]]:
		var found = []
		for name in spec[1]:
			if FileAccess.file_exists(folder.path_join(name)): found.append(folder.path_join(name))
		if found.size() > 1: return {"error": "Multiple candidate files for " + spec[0] + ". Keep just one matching export."}
		if found.is_empty() and spec[2]: return {"error": "Missing " + spec[1][0] + " in the selected OpenGS folder."}
		paths[spec[0]] = "" if found.is_empty() else found[0]
	var manifest_path = folder.path_join("opengs_export.json")
	var warnings: Array[String] = []
	if FileAccess.file_exists(manifest_path):
		var parsed = _json(manifest_path)
		if not parsed.error.is_empty(): return parsed
		var manifest = parsed.value
		if manifest.get("heightmap_sha256", "") != _hash(heightmap.get_data()):
			return {"error": "These province exports belong to a different source heightmap. Regenerate its original settings first."}
		for key in ["width", "length", "samples_per_metre", "sea_level"]:
			if absf(float(manifest.get("source_settings", {}).get(key, -1)) - float(settings.get(key, -2))) > 0.000001:
				return {"error": "Source manifest does not match the current terrain's " + key + "."}
	else:
		warnings.append("No opengs_export.json source manifest: resolution is checked, but coastline alignment is unverified.")
	var province_image = Image.load_from_file(paths.provinces)
	var territory_image = Image.load_from_file(paths.territories)
	if province_image == null or territory_image == null: return {"error": "Could not decode the province/territory PNG files."}
	if province_image.get_size() != heightmap.get_size() or territory_image.get_size() != heightmap.get_size():
		return {"error": "Both images must match the generated heightmap exactly: %d × %d pixels. No automatic resizing is applied." % [heightmap.get_width(), heightmap.get_height()]}
	if province_image.detect_alpha() != Image.ALPHA_NONE or territory_image.detect_alpha() != Image.ALPHA_NONE:
		return {"error": "Province and territory images must be opaque, flat-color PNGs without transparent edges."}
	province_image.convert(Image.FORMAT_RGB8)
	territory_image.convert(Image.FORMAT_RGB8)
	var pdef = _definitions(paths.province_definitions, "province")
	var tdef = _definitions(paths.territory_definitions, "territory")
	if not pdef.error.is_empty(): return pdef
	if not tdef.error.is_empty(): return tdef
	var data = Data.new()
	data.size = province_image.get_size()
	data.spacing = 1.0 / float(settings.get("samples_per_metre", 1))
	data.warnings = warnings
	data.source_files = paths.duplicate()
	data.source_hashes = {"provinces": _hash(province_image.get_data()), "territories": _hash(territory_image.get_data()), "heightmap": _hash(heightmap.get_data())}
	data.province_source_image = province_image
	data.territory_source_image = territory_image
	data.source_settings = settings.duplicate(true)
	var pbytes = province_image.get_data()
	var tbytes = territory_image.get_data()
	var pcolors = {}
	var tcolors = {}
	for i in data.size.x * data.size.y:
		pcolors[_color_key(pbytes, i)] = true
		tcolors[_color_key(tbytes, i)] = true
	pcolors.erase(0)
	tcolors.erase(0)
	if pcolors.is_empty() or tcolors.is_empty(): return {"error": "Province and territory images must contain colored regions; black is unassigned."}
	if pcolors.size() > MAX_REGIONS or tcolors.size() > MAX_REGIONS:
		return {"error": "Too many distinct colors. Export raw region images without anti-aliasing, text or JPEG compression (maximum 65535 regions)."}
	var province_keys = pcolors.keys()
	var territory_keys = tcolors.keys()
	province_keys.sort()
	territory_keys.sort()
	var pindex = {0: 0}
	var tindex = {0: 0}
	data.provinces.append({"id": "", "index": 0})
	data.territories.append({"id": "", "index": 0})
	for spec in [[province_keys, pdef, pindex, data.provinces, "PRV"], [territory_keys, tdef, tindex, data.territories, "TRT"]]:
		for color in spec[0]:
			if spec[1].provided and not spec[1].colors.has(color):
				return {"error": "Image color #%06x has no %s definition. Use raw, unfiltered export images and their matching JSON definitions." % [color, spec[4]]}
			var index = spec[3].size()
			var source: Dictionary = spec[1].colors.get(color, {})
			spec[2][color] = index
			spec[3].append({"id": str(source.get("id", "%s_%06X" % [spec[4], color])), "index": index, "color": "%06x" % color, "type": source.get("type", ""), "terrain": source.get("terrain", ""), "source_center": source.get("center", []), "pixel_count": 0, "centroid_pixel": [0.0, 0.0], "representative_pixel": [], "territory_index": 0, "territory_id": "", "territory_overlaps": {}, "owner": "", "owner_color": "899293", "neighbours": [], "shared_borders": {}})
	data.province_pixels.resize(data.size.x * data.size.y)
	data.territory_pixels.resize(data.province_pixels.size())
	var wet_counts = PackedInt32Array()
	wet_counts.resize(data.provinces.size())
	var terrain_values = heightmap.get_data().to_float32_array()
	var sea = float(settings.get("sea_level", 0.2))
	var adjacency: Dictionary = {}
	for y in data.size.y:
		for x in data.size.x:
			var i = x + y * data.size.x
			var pi = int(pindex[_color_key(pbytes, i)])
			var ti = int(tindex[_color_key(tbytes, i)])
			data.province_pixels[i] = pi
			data.territory_pixels[i] = ti
			if (pi == 0) != (ti == 0): return {"error": "The province and territory images have different unassigned areas at pixel (%d,%d)." % [x, y]}
			if pi == 0: continue
			var province: Dictionary = data.provinces[pi]
			province.territory_overlaps[ti] = int(province.territory_overlaps.get(ti, 0)) + 1
			province.territory_index = ti
			province.territory_id = data.territories[ti].id
			for record in [province, data.territories[ti]]:
				record.pixel_count += 1
				record.centroid_pixel[0] += x
				record.centroid_pixel[1] += y
				if record.representative_pixel.is_empty(): record.representative_pixel = [x, y]
			if terrain_values[i] < sea: wet_counts[pi] += 1
			if x > 0: _edge(pi, data.province_pixels[i - 1], adjacency)
			if y > 0: _edge(pi, data.province_pixels[i - data.size.x], adjacency)
	var history_parent = {}
	if not paths.history.is_empty():
		var supplied_history = _json(paths.history)
		if not supplied_history.error.is_empty(): return supplied_history
		for territory_id in supplied_history.value:
			var entry = supplied_history.value[territory_id]
			if not entry is Dictionary or not entry.get("provinces", null) is Array: return {"error": "Invalid territory history membership."}
			for province_id in entry.provinces:
				if not province_id is String or history_parent.has(province_id): return {"error": "Duplicate or invalid province in territory history."}
				history_parent[province_id] = territory_id
	var corrected_lakes = 0
	for i in range(1, data.provinces.size()):
		var record = data.provinces[i]
		var overlaps: Dictionary = record.territory_overlaps
		var parent = int(overlaps.keys()[0])
		if overlaps.size() > 1:
			var water_region = record.type in ["lake", "water"] or (record.type.is_empty() and wet_counts[i] > record.pixel_count / 2)
			if not water_region: return {"error": "Province " + record.id + " crosses territory boundaries. Re-export matching maps from OpenGS."}
			# Whole-lake provinces can overlap several raw OpenGS territory colors.
			for candidate in overlaps:
				if overlaps[candidate] > overlaps[parent]: parent = int(candidate)
			if record.source_center.size() == 2:
				var cx = int(record.source_center[0])
				var cy = int(record.source_center[1])
				if cx >= 0 and cy >= 0 and cx < data.size.x and cy < data.size.y and data.province_pixels[cx + cy * data.size.x] == i:
					parent = data.territory_pixels[cx + cy * data.size.x]
			if history_parent.has(record.id):
				var found = false
				for candidate in overlaps:
					if data.territories[candidate].id == history_parent[record.id]: parent = int(candidate); found = true; break
				if not found: return {"error": "Lake history assigns " + record.id + " to a territory it does not overlap."}
			corrected_lakes += 1
		record.territory_index = parent
		record.territory_id = data.territories[parent].id
	if corrected_lakes > 0:
		data.warnings.append("%d water province(s) overlap territory boundaries; assigned one parent using history, the source center, or largest overlap." % corrected_lakes)
		for i in range(1, data.territories.size()):
			data.territories[i].pixel_count = 0
			data.territories[i].centroid_pixel = [0.0, 0.0]
			data.territories[i].representative_pixel = []
		for i in data.province_pixels.size():
			var pi = data.province_pixels[i]
			if pi == 0: continue
			var ti = data.provinces[pi].territory_index
			data.territory_pixels[i] = ti
			var record = data.territories[ti]
			record.pixel_count += 1
			record.centroid_pixel[0] += i % data.size.x
			record.centroid_pixel[1] += int(i / data.size.x)
			if record.representative_pixel.is_empty(): record.representative_pixel = [i % data.size.x, int(i / data.size.x)]
	var mismatch = 0
	for i in range(1, data.provinces.size()):
		var record = data.provinces[i]
		var water_majority = wet_counts[i] > record.pixel_count / 2
		if record.type.is_empty(): record.type = "water" if water_majority else "land"
		if (record.type == "land" and water_majority) or (record.type in ["ocean", "lake", "water"] and not water_majority): mismatch += 1
	if mismatch > 0: data.warnings.append("%d province types disagree with the terrain's water mask. Check the source world and image orientation." % mismatch)
	for records in [data.provinces, data.territories]:
		for i in range(1, records.size()):
			var record = records[i]
			record.centroid_pixel[0] /= maxi(1, record.pixel_count)
			record.centroid_pixel[1] /= maxi(1, record.pixel_count)
			record["centroid_world"] = [(record.centroid_pixel[0] + 0.5) * data.spacing, (record.centroid_pixel[1] + 0.5) * data.spacing]
			record["area_m2"] = record.pixel_count * data.spacing * data.spacing
	for key in adjacency:
		var a = int(key >> 32)
		var b = int(key & 0xffffffff)
		data.provinces[a].neighbours.append(data.provinces[b].id)
		data.provinces[b].neighbours.append(data.provinces[a].id)
		data.provinces[a].shared_borders[data.provinces[b].id] = adjacency[key] * data.spacing
		data.provinces[b].shared_borders[data.provinces[a].id] = adjacency[key] * data.spacing
	for i in range(1, data.territories.size()): data.territories[i]["provinces"] = []
	for i in range(1, data.provinces.size()):
		data.territories[data.provinces[i].territory_index].provinces.append(data.provinces[i].id)
	if not paths.history.is_empty():
		var history = _json(paths.history)
		if not history.error.is_empty(): return history
		for i in range(1, data.territories.size()):
			var territory = data.territories[i]
			if not history.value.has(territory.id): return {"error": "Territory history is missing " + territory.id}
			if not history.value[territory.id] is Dictionary: return {"error": "Invalid territory history record."}
			var listed = history.value[territory.id].get("provinces", [])
			if not listed is Array: return {"error": "Territory province membership must be an array."}
			var actual = territory.provinces.duplicate()
			listed.sort()
			actual.sort()
			if listed != actual: return {"error": "Territory history and images disagree for " + territory.id}
	data.province_index_image = data.encode_indices(data.province_pixels, data.size.x, data.size.y)
	data.territory_index_image = data.encode_indices(data.territory_pixels, data.size.x, data.size.y)
	data.province_lookup = data.make_lookup(data.provinces)
	data.territory_lookup = data.make_lookup(data.territories)
	var state_path = folder.path_join("province_state.json")
	if FileAccess.file_exists(state_path):
		var state = _json(state_path)
		if not state.error.is_empty(): return state
		if state.value.get("format_version", 0) != 1 or not state.value.get("provinces", null) is Array:
			return {"error": "Invalid saved province state."}
		var state_by_id = {}
		for record in state.value.provinces:
			if not record is Dictionary: return {"error": "Invalid province state record."}
			state_by_id[str(record.get("id", ""))] = record
		for i in range(1, data.provinces.size()):
			var record = data.provinces[i]
			var saved: Dictionary = state_by_id.get(record.id, {})
			record.owner = str(saved.get("owner", ""))
			record.owner_color = str(saved.get("owner_color", "899293"))
	data.rebuild_owners()
	data.border_distance_image = data.build_border_distance()
	return {"error": "", "data": data}

static func _edge(a: int, b: int, edges: Dictionary) -> void:
	if a == 0 or b == 0 or a == b: return
	var key = (mini(a, b) << 32) | maxi(a, b)
	edges[key] = int(edges.get(key, 0)) + 1

static func _color_key(bytes: PackedByteArray, index: int) -> int:
	return (int(bytes[index * 3]) << 16) | (int(bytes[index * 3 + 1]) << 8) | int(bytes[index * 3 + 2])

static func _hash(bytes: PackedByteArray) -> String:
	var hash_context = HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(bytes)
	return hash_context.finish().hex_encode()

static func _json(path: String) -> Dictionary:
	if FileAccess.get_file_as_bytes(path).size() > 32 * 1024 * 1024: return {"error": "JSON file is too large: " + path.get_file()}
	var parser = JSON.new()
	var error = parser.parse(FileAccess.get_file_as_string(path))
	if error != OK or not parser.data is Dictionary: return {"error": "Invalid JSON object: " + path.get_file()}
	return {"error": "", "value": parser.data}

static func _definitions(path: String, kind: String) -> Dictionary:
	if path.is_empty(): return {"error": "", "provided": false, "colors": {}}
	var parsed = _json(path)
	if not parsed.error.is_empty(): return parsed
	var colors = {}
	for id in parsed.value:
		var record = parsed.value[id]
		if not record is Dictionary: return {"error": "Invalid definition record: " + str(id)}
		var key = 0
		for channel in ["R", "G", "B"]:
			var value = record.get(channel, -1)
			if not (value is float or value is int) or value != int(value) or value < 0 or value > 255:
				return {"error": "Invalid RGB definition for " + str(id)}
			key = (key << 8) | int(value)
		if key == 0 or colors.has(key): return {"error": "Definitions contain duplicate or reserved black colors."}
		colors[key] = {"id": str(id), "type": str(record.get(kind + "_type", "")), "terrain": str(record.get("province_terrain", "")), "center": [record.get("x", 0), record.get("y", 0)]}
	return {"error": "", "provided": true, "colors": colors}
