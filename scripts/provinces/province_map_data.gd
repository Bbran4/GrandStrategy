class_name ProvinceMapData
extends RefCounted
## Province identity is independent of ownership and presentation.
var size = Vector2i.ZERO
var spacing = 1.0
var province_pixels = PackedInt32Array()
var territory_pixels = PackedInt32Array()
var provinces: Array[Dictionary] = []
var territories: Array[Dictionary] = []
var province_index_image: Image
var territory_index_image: Image
var province_source_image: Image
var territory_source_image: Image
var source_settings: Dictionary = {}
var border_distance_image: Image
var owner_id_lookup: Image
var province_lookup: Image
var territory_lookup: Image
var owner_lookup: Image
var warnings: Array[String] = []
var source_files: Dictionary = {}
var source_hashes: Dictionary = {}

func province_at_pixel(pixel: Vector2i) -> int:
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= size.x or pixel.y >= size.y: return 0
	return province_pixels[pixel.x + pixel.y * size.x]

func province_at_world(position: Vector3) -> int:
	return province_at_pixel(Vector2i(floori(position.x / spacing), floori(position.z / spacing)))

func set_owner(index: int, owner_id: String, color: Color) -> bool:
	if index <= 0 or index >= provinces.size(): return false
	owner_id = owner_id.strip_edges()
	# Joining an existing country keeps its color. Recoloring a province already
	# in that country explicitly updates the shared country palette.
	if provinces[index].owner != owner_id and not owner_id.is_empty():
		for i in range(1, provinces.size()):
			if provinces[i].owner == owner_id:
				color = Color.from_string(provinces[i].owner_color, color)
				break
	provinces[index]["owner"] = owner_id
	provinces[index]["owner_color"] = color.to_html(false)
	if not owner_id.is_empty():
		for i in range(1, provinces.size()):
			if provinces[i].owner == owner_id: provinces[i].owner_color = color.to_html(false)
	rebuild_owners()
	return true

func rebuild_owners() -> void:
	owner_lookup = make_lookup(provinces, true)
	owner_id_lookup = make_lookup(provinces, true)
	owner_id_lookup.fill(Color.BLACK)
	var names = {}
	for i in range(1, provinces.size()):
		if not provinces[i].owner.is_empty(): names[provinces[i].owner] = true
	var keys = names.keys()
	keys.sort()
	for i in range(1, provinces.size()):
		var record = provinces[i]
		var index = keys.find(record.owner) + 1 if not record.owner.is_empty() else 0
		record["owner_index"] = index
		if index == 0: continue
		owner_lookup.set_pixel(i % 256, int(i / 256), Color.from_string(record.owner_color, Color("899293")))
		owner_id_lookup.set_pixel(i % 256, int(i / 256), Color8((index >> 16) & 255, (index >> 8) & 255, index & 255))

func encode_indices(indices: PackedInt32Array, width: int, height: int) -> Image:
	var bytes = PackedByteArray()
	bytes.resize(indices.size() * 3)
	for i in indices.size():
		bytes[i * 3] = (indices[i] >> 16) & 255
		bytes[i * 3 + 1] = (indices[i] >> 8) & 255
		bytes[i * 3 + 2] = indices[i] & 255
	return Image.create_from_data(width, height, false, Image.FORMAT_RGB8, bytes)

func make_lookup(records: Array[Dictionary], neutral: bool = false) -> Image:
	var image = Image.create_empty(256, maxi(1, ceili(records.size() / 256.0)), false, Image.FORMAT_RGBA8)
	image.fill(Color("899293") if neutral else Color.BLACK)
	for i in range(1, records.size()):
		var color = Color(records[i].color) if not neutral else Color("899293")
		color.a = 1.0 if neutral or records[i].get("type", "land") == "land" else 0.0
		image.set_pixel(i % 256, int(i / 256), color)
	return image

func save_to_folder(folder: String) -> Error:
	var error = DirAccess.make_dir_recursive_absolute(folder)
	if error != OK: return error
	error = province_index_image.save_png(folder.path_join("province_ids.png"))
	if error == OK: error = territory_index_image.save_png(folder.path_join("territory_ids.png"))
	if error != OK: return error
	var file = FileAccess.open(folder.path_join("province_state.json"), FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"format_version": 1, "width": size.x, "height": size.y, "vertex_spacing": spacing, "source_files": source_files, "source_hashes": source_hashes, "warnings": warnings, "provinces": provinces, "territories": territories}, "\t"))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK: return error
	for spec in [[province_source_image, "provinces.png"], [territory_source_image, "territories.png"]]:
		error = spec[0].save_png(folder.path_join(spec[1]))
		if error != OK: return error
	for spec in [[provinces, "province", "province_definitions.json"], [territories, "territory", "territory_definitions.json"]]:
		var definitions = {}
		for i in range(1, spec[0].size()):
			var record = spec[0][i]
			var color = Color(record.color)
			definitions[record.id] = {"R": color.r8, "G": color.g8, "B": color.b8, "x": record.centroid_pixel[0], "y": record.centroid_pixel[1], spec[1] + "_type": record.type}
			if spec[1] == "province": definitions[record.id]["province_terrain"] = record.terrain
		error = _save_json(folder.path_join(spec[2]), definitions)
		if error != OK: return error
	var history = {}
	for i in range(1, territories.size()): history[territories[i].id] = {"provinces": territories[i].provinces}
	error = _save_json(folder.path_join("territory_history.json"), history)
	if error != OK: return error
	return _save_json(folder.path_join("opengs_export.json"), {"heightmap_sha256": source_hashes.get("heightmap", ""), "source_settings": source_settings})

func _save_json(path: String, value: Dictionary) -> Error:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value, "\t"))
	file.flush()
	var error = file.get_error()
	file.close()
	return error

func build_border_distance() -> Image:
	var width = size.x
	var height = size.y
	var images: Array[PackedFloat32Array] = []
	for ids in [province_pixels, territory_pixels]:
		var values = PackedFloat32Array()
		values.resize(ids.size())
		values.fill(32.0)
		for y in height:
			for x in width:
				var i = x + y * width
				if (x > 0 and ids[i] != ids[i - 1]) or (y > 0 and ids[i] != ids[i - width]):
					values[i] = 0
					if x > 0 and ids[i] != ids[i - 1]: values[i - 1] = 0
					if y > 0 and ids[i] != ids[i - width]: values[i - width] = 0
		for y in height:
			for x in width:
				var i = x + y * width
				if x > 0: values[i] = minf(values[i], values[i - 1] + 1)
				if y > 0: values[i] = minf(values[i], values[i - width] + 1)
				if x > 0 and y > 0: values[i] = minf(values[i], values[i - width - 1] + 1.414214)
				if x < width - 1 and y > 0: values[i] = minf(values[i], values[i - width + 1] + 1.414214)
		for y in range(height - 1, -1, -1):
			for x in range(width - 1, -1, -1):
				var i = x + y * width
				if x < width - 1: values[i] = minf(values[i], values[i + 1] + 1)
				if y < height - 1: values[i] = minf(values[i], values[i + width] + 1)
				if x < width - 1 and y < height - 1: values[i] = minf(values[i], values[i + width + 1] + 1.414214)
				if x > 0 and y < height - 1: values[i] = minf(values[i], values[i + width - 1] + 1.414214)
		images.append(values)
	var bytes = PackedByteArray()
	bytes.resize(width * height * 2)
	for i in width * height:
		bytes[i * 2] = roundi(clampf(images[0][i] / 32.0, 0, 1) * 255)
		bytes[i * 2 + 1] = roundi(clampf(images[1][i] / 32.0, 0, 1) * 255)
	return Image.create_from_data(width, height, false, Image.FORMAT_RG8, bytes)
