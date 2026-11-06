extends RefCounted
## OpenGS import rasters: exact RGB labels, identical dimensions and orientation.
## Contract: https://github.com/Thomas-Holtvedt/opengs-maptool#how-to-use-the-tool

const OCEAN = Color("051412")
const LAKE = Color("00ff00")
const PALETTE = {
	"forest": Color("59c755"), "hills": Color("f8ff99"),
	"mountain": Color("9dc0d0"), "plains": Color("ff8142"),
	"urban": Color("787878"), "jungle": Color("7fbf00"),
	"marsh": Color("4c6023"), "desert": Color("ff7f00"),
	"deep_ocean": Color("022696"), "shallow_sea": Color("3876d9"),
	"fjords": Color("4ba2c6"), "lakes": Color("3a5bff")
}

static func build_images(heightmap: Image, settings: Dictionary) -> Dictionary:
	if heightmap == null or heightmap.is_empty(): return {"error": "Generate a map before exporting."}
	var image = heightmap.duplicate()
	image.convert(Image.FORMAT_RF)
	var width = image.get_width()
	var length = image.get_height()
	var heights = image.get_data().to_float32_array()
	var sea = float(settings.get("sea_level", 0.2))
	var elevation_scale = float(settings.get("height_scale", 100.0))
	var spacing = 1.0 / float(settings.get("samples_per_metre", 1))
	var water = PackedByteArray()
	water.resize(heights.size())
	for i in heights.size():
		if not is_finite(heights[i]): return {"error": "The heightmap contains invalid elevations."}
		water[i] = 1 if heights[i] < sea else 0
	# Edge-connected water is ocean. Remaining 4-connected water bodies are lakes.
	var queue = PackedInt32Array()
	for x in width:
		_seed_ocean(x, water, queue)
		_seed_ocean(x + (length - 1) * width, water, queue)
	for y in length:
		_seed_ocean(y * width, water, queue)
		_seed_ocean(y * width + width - 1, water, queue)
	_flood(water, queue, width, length, 2)
	var lakes = 0
	for i in water.size():
		if water[i] != 1: continue
		lakes += 1
		water[i] = 3
		queue = PackedInt32Array([i])
		_flood(water, queue, width, length, 3)
	var land_image = Image.create_empty(width, length, false, Image.FORMAT_RGB8)
	var boundary_image = Image.create_empty(width, length, false, Image.FORMAT_RGB8)
	boundary_image.fill(Color.WHITE)
	var density_image = Image.create_empty(width, length, false, Image.FORMAT_RGB8)
	var terrain_image = Image.create_empty(width, length, false, Image.FORMAT_RGB8)
	var moisture = FastNoiseLite.new()
	moisture.seed = int(settings.get("seed", 0)) + 3417
	moisture.frequency = 0.008
	moisture.fractal_octaves = 4
	var scale = 1024.0 / maxf(width, length)
	var counts = {"land_pixels": 0, "ocean_pixels": 0, "lake_pixels": 0, "lake_count": lakes}
	var terrain_counts: Dictionary = {}
	for y in length:
		for x in width:
			var i = x + y * width
			var h = heights[i]
			var kind: String
			var density: int
			if water[i] == 2:
				land_image.set_pixel(x, y, OCEAN)
				counts.ocean_pixels += 1
				kind = "shallow_sea" if sea - h <= 0.035 else "deep_ocean"
				density = 175
			elif water[i] == 3:
				land_image.set_pixel(x, y, LAKE)
				counts.lake_pixels += 1
				kind = "lakes"
				density = 255
			else:
				land_image.set_pixel(x, y, Color.WHITE)
				counts.land_pixels += 1
				var left = maxi(0, x - 1)
				var right = mini(width - 1, x + 1)
				var up = maxi(0, y - 1)
				var down = mini(length - 1, y + 1)
				var dx = (heights[right + y * width] - heights[left + y * width]) * elevation_scale / (maxi(1, right - left) * spacing)
				var dz = (heights[x + down * width] - heights[x + up * width]) * elevation_scale / (maxi(1, down - up) * spacing)
				var slope = Vector2(dx, dz).length()
				var altitude = maxf(0, (h - sea) / maxf(0.01, 1.0 - sea))
				var wet = moisture.get_noise_2d(x * scale, y * scale) * 0.5 + 0.5
				var latitude = absf(float(y) / length - 0.5) * 2.0
				kind = classify_land(altitude, slope, wet, latitude)
				# Fewer/larger provinces on rugged or arid ground; more seeds on
				# moist lowlands. This is suitability, not a population simulation.
				var difficulty = clampf(altitude * 0.9 + minf(slope / 0.8, 1.0) * 0.55, 0, 1)
				density = clampi(roundi(55 + difficulty * 170 + (0.5 - wet) * 45 + (35 if kind == "desert" else 0)), 20, 240)
			terrain_image.set_pixel(x, y, PALETTE[kind])
			density_image.set_pixel(x, y, Color(density / 255.0, density / 255.0, density / 255.0))
			terrain_counts[kind] = int(terrain_counts.get(kind, 0)) + 1
	return {"land": land_image, "boundary": boundary_image, "density": density_image, "terrain": terrain_image, "stats": counts, "terrain_counts": terrain_counts, "error": ""}

static func classify_land(altitude: float, slope: float, wet: float, latitude: float) -> String:
	if altitude >= 0.28 or slope >= 0.55: return "mountain"
	if altitude >= 0.10 or slope >= 0.18: return "hills"
	if wet < 0.36: return "desert"
	if wet > 0.64 and altitude < 0.025 and slope < 0.07: return "marsh"
	if wet > 0.58 and latitude < 0.32: return "jungle"
	if wet > 0.52: return "forest"
	return "plains"

static func _seed_ocean(index: int, water: PackedByteArray, queue: PackedInt32Array) -> void:
	if water[index] == 1:
		water[index] = 2
		queue.append(index)

static func _flood(water: PackedByteArray, queue: PackedInt32Array, width: int, length: int, label: int) -> void:
	var head = 0
	while head < queue.size():
		var i = queue[head]
		head += 1
		var x = i % width
		if x > 0 and water[i - 1] == 1:
			water[i - 1] = label
			queue.append(i - 1)
		if x < width - 1 and water[i + 1] == 1:
			water[i + 1] = label
			queue.append(i + 1)
		if i >= width and water[i - width] == 1:
			water[i - width] = label
			queue.append(i - width)
		if i < width * (length - 1) and water[i + width] == 1:
			water[i + width] = label
			queue.append(i + width)

static func export_folder(folder: String, heightmap: Image, settings: Dictionary) -> Dictionary:
	var directory = DirAccess.open(folder)
	if directory == null: return {"error": "Could not open export folder."}
	if not directory.get_files().is_empty() or not directory.get_directories().is_empty():
		return {"error": "Choose an empty folder so an existing export is not overwritten."}
	var maps = build_images(heightmap, settings)
	if not maps.error.is_empty(): return {"error": maps.error}
	# Catch folders filled by another writer while the images were being built.
	if not directory.get_files().is_empty() or not directory.get_directories().is_empty():
		return {"error": "The folder changed during export. Choose an empty folder."}
	for key in ["land", "boundary", "density", "terrain"]:
		var error: int = maps[key].save_png(folder.path_join(key + ".png"))
		if error != OK: return {"error": "Could not save " + key + ".png: " + error_string(error)}
	var hash_context = HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(heightmap.get_data())
	var metadata = {"format": "OpenGS import images", "export_version": 1, "source_settings": settings.duplicate(true), "width": heightmap.get_width(), "height": heightmap.get_height(), "heightmap_sha256": hash_context.finish().hex_encode(), "orientation": "image x -> world +X, image y -> world +Z; no flip", "boundary_mode": "unconstrained_white", "water_connectivity": 4, "stats": maps.stats, "terrain_counts": maps.terrain_counts, "terrain_palette_rgb": {}}
	for key in PALETTE:
		var color: Color = PALETTE[key]
		metadata.terrain_palette_rgb[key] = [color.r8, color.g8, color.b8]
	var file = FileAccess.open(folder.path_join("opengs_export.json"), FileAccess.WRITE)
	if file == null: return {"error": "Could not write export metadata."}
	file.store_string(JSON.stringify(metadata, "\t"))
	file.flush()
	var metadata_error = file.get_error()
	file.close()
	if metadata_error != OK: return {"error": "Could not finish writing export metadata."}
	file = FileAccess.open(folder.path_join("README.txt"), FileAccess.WRITE)
	if file == null: return {"error": "Could not write import instructions."}
	file.store_string("OpenGS import images\n\n1. Import land.png in Land Image.\n2. Import boundary.png in Boundary Image. This image is intentionally all white: no country/state boundaries exist in this editor yet. You may omit it, or draw your own exact-black boundaries on this image.\n3. Import density.png in Density Image. Darker means more seeds / smaller provinces; consider Exclude Ocean if you want ocean density controlled separately.\n4. Import terrain.png in Terrain Image.\n5. Generate territories FIRST, then provinces.\n\nAll images have the source heightmap dimensions and the same orientation: image x = world +X, image y = world +Z. Never resize these images independently or save categorical land/terrain images as JPEG.\n\nLand: ocean RGB (5,20,18), lakes (0,255,0), land (255,255,255). Lakes are below-sea-level water not 4-connected to a map edge. Classification is relative to this map extent.\nTerrain uses the OpenGS palette; urban and fjords are not auto-assigned because this editor has no settlement or fjord classification data. Other terrain classes are elevation/slope/moisture heuristics, not painted gameplay biomes.\nDensity is terrain suitability, not a population map. Boundary constraints are not automatically inferred from mountains.\n\nSource: https://github.com/Thomas-Holtvedt/opengs-maptool#how-to-use-the-tool\nSee opengs_export.json for exact generated settings, palette, counts and heightmap hash.\n")
	file.flush()
	var instructions_error = file.get_error()
	file.close()
	if instructions_error != OK: return {"error": "Could not finish writing import instructions."}
	return {"error": "", "stats": maps.stats, "folder": folder}
