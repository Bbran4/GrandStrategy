extends SceneTree
const Exporter = preload("res://scripts/map_editor/opengs_exporter.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
func rgb(image: Image, x: int, y: int) -> Array:
	var c = image.get_pixel(x, y)
	return [c.r8, c.g8, c.b8]

func _run() -> void:
	var image = Image.create_empty(32, 24, false, Image.FORMAT_RF)
	image.fill(Color(0.24, 0, 0))
	for y in 24:
		for x in 4: image.set_pixel(x, y, Color(0, 0, 0))
	for y in range(8, 11):
		for x in range(5, 8): image.set_pixel(x, y, Color(0.15, 0, 0))
	image.set_pixel(3, 12, Color(0.18, 0, 0))
	image.set_pixel(15, 0, Color(0.0, 0, 0))
	image.set_pixel(16, 1, Color(0.0, 0, 0))
	image.set_pixel(20, 10, Color(0.75, 0, 0))
	image.set_pixel(30, 22, Color(0.2, 0, 0))
	var settings = {"sea_level": 0.2, "height_scale": 100.0, "samples_per_metre": 2, "seed": 12345, "width": 16, "length": 12}
	var original = image.get_data()
	var maps = Exporter.build_images(image, settings)
	check(maps.error.is_empty(), "Export images must build")
	check(image.get_data() == original, "Export must not alter terrain height data")
	for key in ["land", "boundary", "density", "terrain"]:
		check(maps[key].get_size() == Vector2i(32, 24), "Raster dimensions must match: " + key)
		check(maps[key].get_format() == Image.FORMAT_RGB8, "Categorical images must be opaque RGB8: " + key)
	check(rgb(maps.land, 0, 12) == [5, 20, 18], "Ocean must use OpenGS exact RGB")
	check(rgb(maps.land, 6, 9) == [0, 255, 0], "Enclosed water must be exported as a lake")
	check(rgb(maps.land, 16, 1) == [0, 255, 0], "Diagonal contact alone must not connect lake to ocean")
	check(rgb(maps.land, 15, 0) == [5, 20, 18], "Edge water must be ocean")
	check(rgb(maps.land, 30, 22) == [255, 255, 255], "The sea threshold itself is land")
	check(rgb(maps.terrain, 6, 9) == [58, 91, 255], "Lake terrain RGB must match OpenGS")
	check(rgb(maps.terrain, 0, 12) == [2, 38, 150], "Deep-ocean terrain RGB must match OpenGS")
	check(rgb(maps.terrain, 3, 12) == [56, 118, 217], "Shallow-sea terrain RGB must match OpenGS")
	check(rgb(maps.terrain, 20, 10) == [157, 192, 208], "Mountain terrain RGB must match OpenGS")
	check(maps.stats.lake_count == 2, "Lake components must be counted independently")
	check(maps.stats.land_pixels + maps.stats.ocean_pixels + maps.stats.lake_pixels == 32 * 24, "Every source sample must be classified")
	var palette = [[89,199,85], [248,255,153], [157,192,208], [255,129,66], [120,120,120], [127,191,0], [76,96,35], [255,127,0], [2,38,150], [56,118,217], [75,162,198], [58,91,255]]
	for y in 24:
		for x in 32:
			check(rgb(maps.terrain, x, y) in palette, "Terrain labels must not contain blended or invented colors")
			check(rgb(maps.boundary, x, y) == [255, 255, 255], "Unconstrained boundaries must be white")
			var d = rgb(maps.density, x, y)
			check(d[0] == d[1] and d[1] == d[2], "Density must be grayscale")
	check(maps.density.get_pixel(12, 12).r < maps.density.get_pixel(20, 10).r, "Fertile flat ground must attract more seeds than mountain ground")
	for sample in [[0.4,0,0.5,0.5,"mountain"], [0.15,0,0.5,0.5,"hills"], [0.05,0,0.2,0.5,"desert"], [0.01,0,0.8,0.5,"marsh"], [0.05,0,0.7,0.1,"jungle"], [0.05,0,0.55,0.5,"forest"], [0.05,0,0.5,0.5,"plains"]]:
		check(Exporter.classify_land(sample[0], sample[1], sample[2], sample[3]) == sample[4], "Terrain classification: " + sample[4])
	var folder = "res://tests/output/opengs_" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	var exported = Exporter.export_folder(ProjectSettings.globalize_path(folder), image, settings)
	check(exported.error.is_empty(), "Export must save a complete pack")
	for key in ["land", "boundary", "density", "terrain"]:
		var loaded = Image.load_from_file(folder.path_join(key + ".png"))
		check(loaded != null and loaded.get_size() == image.get_size() and loaded.get_data() == maps[key].get_data(), "PNG round-trip must preserve every RGB byte: " + key)
	var metadata = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("opengs_export.json")))
	check(metadata.source_settings.seed == 12345 and metadata.width == 32 and metadata.height == 24, "Metadata must preserve source settings and resolution")
	check(metadata.boundary_mode == "unconstrained_white" and metadata.stats.lake_count == 2, "Metadata must explain boundary and lake handling")
	var old_bytes = FileAccess.get_file_as_bytes(folder.path_join("land.png"))
	check(not Exporter.export_folder(ProjectSettings.globalize_path(folder), image, settings).error.is_empty(), "Nonempty export folders must be rejected")
	check(old_bytes == FileAccess.get_file_as_bytes(folder.path_join("land.png")), "Rejected export must not overwrite existing files")
	var water = Image.create_empty(8, 8, false, Image.FORMAT_RF)
	water.fill(Color(0, 0, 0))
	check(Exporter.build_images(water, settings).stats.ocean_pixels == 64, "All-ocean map must export")
	water.fill(Color(0.2, 0, 0))
	check(Exporter.build_images(water, settings).stats.land_pixels == 64, "All-land map must export")
	check(not Exporter.build_images(null, settings).error.is_empty(), "Missing map must be handled")
	print("OPENGS EXPORT TESTS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
