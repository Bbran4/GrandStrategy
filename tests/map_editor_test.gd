extends SceneTree

const Generator = preload("res://scripts/map_editor/old_world_generator.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var generator = Generator.new()
	var first = generator.generate(256, 512, 12345)
	var repeat = generator.generate(256, 512, 12345)
	var different = generator.generate(256, 512, 98765)
	check(first.get_data() == repeat.get_data(), "Same seed must reproduce heightmap")
	check(first.get_data() != different.get_data(), "Different seed must vary heightmap")
	check(first.get_size() == Vector2i(256, 512), "Rectangular dimensions must be preserved")
	check(first.get_format() == Image.FORMAT_RF, "Heightmap must retain float precision")
	var land = 0
	var water = 0
	for y in first.get_height():
		for x in first.get_width():
			var h = first.get_pixel(x, y).r
			check(is_finite(h) and h >= 0 and h <= 1, "Heights must be finite and normalized")
			if h >= 0.2: land += 1
			else: water += 1
	check(land > 1000 and water > 1000, "Old World must produce both land and sea")
	print("Generator land fraction: ", float(land) / (land + water))
	var scene = load("res://scenes/map_editor.tscn").instantiate()
	# These nodes and settings must exist in the PackedScene before _ready runs.
	check(scene.get_node_or_null("Terrain3D") is Terrain3D, "Terrain3D must be authored in the scene")
	for path in ["WorldEnvironment", "Sun", "Camera3D", "Ocean", "EditorUI/SettingsPanel", "EditorUI/SaveDialog"]:
		check(scene.has_node(path), "Scene must contain " + path + " before runtime")
	check(scene.get_node("WorldEnvironment").environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR, "Authored environment must use color ambient light")
	var original_terrain = scene.get_node("Terrain3D")
	var original_material = original_terrain.material
	var original_assets = original_terrain.assets
	var authored_children = scene.get_children().duplicate()
	root.add_child(scene)
	while scene.busy: await process_frame
	check(scene.terrain == original_terrain, "Startup must retain the authored Terrain3D node")
	check(scene.get_children() == authored_children, "Runtime must not create or replace scene children")
	check(scene.generate_button.pressed.is_connected(scene._generate), "Generate signal must be connected in the scene")
	check(scene.save_dialog.dir_selected.is_connected(scene._save), "Save dialog signal must be connected in the scene")
	check(scene.terrain.data.get_regions_active().size() == 16, "Default 1024 map requires 16 regions")
	scene.width_input.value = 256
	scene.length_input.value = 512
	scene.height_input.value = 500
	scene.sea_input.value = 25
	scene.seed_input.value = 12345
	scene.generate_button.pressed.emit()
	while scene.busy: await process_frame
	check(scene.terrain == original_terrain, "Regeneration must reuse the authored Terrain3D node")
	check(scene.terrain.material == original_material and scene.terrain.assets == original_assets, "Regeneration must preserve authored material and assets")
	check(scene.get_children() == authored_children, "Regeneration must not replace scene children")
	check(scene.heightmap.get_data() == first.get_data(), "Editor must import the requested generator output")
	check(scene.terrain.data.get_regions_active().size() == 2, "Regeneration must remove old regions")
	var expected = first.get_pixel(100, 200).r * 500.0 - 125.0
	var actual = scene.terrain.data.get_height(Vector3(100, 0, 200))
	check(absf(actual - expected) < 0.02, "Terrain height must match floating-point map with scale and sea offset")
	# Saving must use the generated snapshot, even if fields were subsequently edited.
	scene.seed_input.value = 999
	var folder = "res://tests/output/map_" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	scene._save(ProjectSettings.globalize_path(folder))
	var saved = Image.load_from_file(folder.path_join("heightmap.exr"))
	check(saved != null and saved.get_size() == first.get_size(), "EXR export must preserve dimensions")
	var settings = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("map.json")))
	check(settings.seed == 12345 and settings.width == 256 and settings.length == 512, "Saved settings must match generated map")
	check(DirAccess.get_files_at(folder.path_join("terrain")).size() == 2, "Save must write Terrain3D regions")
	var previous = FileAccess.get_file_as_bytes(folder.path_join("heightmap.exr"))
	scene._save(ProjectSettings.globalize_path(folder))
	check(previous == FileAccess.get_file_as_bytes(folder.path_join("heightmap.exr")), "Nonempty map folders must not be overwritten")
	scene.queue_free()
	await process_frame
	print("MAP EDITOR TESTS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
