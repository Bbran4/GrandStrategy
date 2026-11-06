extends SceneTree

const Generator = preload("res://scripts/map_editor/old_world_generator.gd")
var failures: Array[String] = []
var has_renderer = DisplayServer.get_name() != "headless"

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var generator = Generator.new()
	var test_slope = Image.create_empty(32, 32, false, Image.FORMAT_RF)
	test_slope.fill(Color(0.3, 0, 0))
	test_slope.set_pixel(16, 16, Color(0.8, 0, 0))
	var weathered = generator._erode(test_slope, 1.0)
	var old_mass = 0.0
	var new_mass = 0.0
	for y in 32:
		for x in 32:
			old_mass += test_slope.get_pixel(x, y).r
			new_mass += weathered.get_pixel(x, y).r
	check(absf(old_mass - new_mass) < 0.002, "Weathering must conserve terrain material")
	check(weathered.get_pixel(16, 16).r < 0.8 and weathered.get_pixel(15, 16).r > 0.3, "Steep terrain must deposit material downhill")
	var lowland = Image.create_empty(32, 32, false, Image.FORMAT_RF)
	lowland.fill(Color(0.21, 0, 0))
	check(generator._erode(lowland, 1.0).get_data() == lowland.get_data(), "Weathering must preserve the shoreline band")
	var hydraulic = preload("res://scripts/map_editor/hydraulic_erosion.gd")
	var basin = Image.create_empty(64, 64, false, Image.FORMAT_RF)
	for y in 64:
		for x in 64:
			basin.set_pixel(x, y, Color(0.28 + float(63 - y) * 0.006 + sin(x * 0.2) * 0.015, 0, 0))
	var carved = hydraulic.erode(basin, 5, 1.0)
	for y in 64:
		for x in 64:
			check(carved.get_pixel(x, y).r <= basin.get_pixel(x, y).r + 0.0181, "Erosion deposition must not create needle peaks")
	check(carved.get_data() != basin.get_data(), "Hydraulic erosion must change elevation, not just materials")
	check(carved.get_data() == hydraulic.erode(basin, 5, 1.0).get_data(), "Hydraulic erosion must reproduce the same seed")
	check(hydraulic.erode(basin, 5, 0.0).get_data() == basin.get_data(), "Disabling hydraulic erosion must preserve the input")
	var first = generator.generate(256, 512, 12345)
	var repeat = generator.generate(256, 512, 12345)
	var softer = generator.generate(256, 512, 12345, 1.0, 1.0, 1)
	check(softer.get_data() != first.get_data(), "Reference presets must produce different landforms")
	var different = generator.generate(256, 512, 98765)
	var coarse = generator.generate(256, 512, 12345, 0.0)
	check(first.get_data() != coarse.get_data(), "Detail strength must change actual terrain geometry")
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
	check(scene.heightmap_quality == 1, "Scene should default to high elevation sampling")
	scene.heightmap_quality = 0
	# These nodes and settings must exist in the PackedScene before _ready runs.
	check(scene.get_node_or_null("Terrain3D") is Terrain3D, "Terrain3D must be authored in the scene")
	for path in ["WorldEnvironment", "Sun", "Camera3D", "TerrainFocus", "EditorUI/SettingsPanel", "EditorUI/SaveDialog", "EditorUI/OpenGSExportDialog"]:
		check(scene.has_node(path), "Scene must contain " + path + " before runtime")
	check(scene.get_node("WorldEnvironment").environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR, "Authored environment must use color ambient light")
	check(scene.get_node("%HeightInput").value == 100.0, "Default relief scale must match accepted previews")
	check(scene.get_node("%NeutralView").button_pressed, "Default view must match neutral reference previews")
	var original_terrain = scene.get_node("Terrain3D")
	var original_material = original_terrain.material
	var original_assets = original_terrain.assets
	var authored_children = scene.get_children().duplicate()
	root.add_child(scene)
	while scene.busy: await process_frame
	if has_renderer:
		check(scene.terrain.material.get_shader_param("surface_map") is Texture2D, "Custom terrain shader must receive its surface texture")
		for param in ["detail_albedo", "detail_normal"]:
			var detail_texture = scene.terrain.material.get_shader_param(param) as Texture2DArray
			check(detail_texture != null and detail_texture.get_layers() == 3 and detail_texture.has_mipmaps(), "PBR detail must bind three mipmapped material layers: " + param)
	check(not scene.has_node("Ocean"), "There must be no separate ocean mesh node")
	check(scene.terrain.clipmap_target == scene.terrain_focus, "Terrain LOD must follow the ground focus rather than the elevated camera")
	check(scene.terrain.mesh_size >= 96 and scene.terrain.tessellation_level >= 1, "Terrain must retain the close-up detail settings")
	var original_target = scene.target
	scene.target = Vector3(300, 0, 200)
	scene._update_camera()
	check(scene.terrain_focus.position == scene.target, "Panning must move the terrain detail focus")
	scene.target = original_target
	scene._update_camera()
	check(scene.terrain.ocean_enabled, "Terrain3D built-in ocean must be enabled")
	var original_ocean_material = scene.terrain.ocean_material
	check(original_ocean_material is ShaderMaterial, "The scene must use Terrain3D's native ocean shader material")
	check(original_ocean_material.shader.resource_path == "res://addons/terrain_3d/extras/shaders/ocean_shader.gdshader", "Use Terrain3D's ocean clipmap shader")
	check(original_ocean_material.get_shader_parameter("sea_level") == 0.0, "Ocean uses world Y zero")
	var shape_before_view_toggle = scene.heightmap.get_data()
	scene.neutral_view.button_pressed = false
	check(not scene.terrain.material.show_grey, "Colored terrain must remain selectable")
	scene.neutral_view.button_pressed = true
	check(scene.terrain.material.show_grey and scene.heightmap.get_data() == shape_before_view_toggle, "View toggles must preserve terrain geometry")
	check(scene.terrain == original_terrain, "Startup must retain the authored Terrain3D node")
	check(scene.get_children() == authored_children, "Runtime must not create or replace scene children")
	check(scene.generate_button.pressed.is_connected(scene._generate), "Generate signal must be connected in the scene")
	check(scene.save_dialog.dir_selected.is_connected(scene._save), "Save dialog signal must be connected in the scene")
	check(scene.opengs_button.pressed.is_connected(scene._on_opengs_export_pressed), "OpenGS button signal must be authored in the scene")
	check(scene.opengs_dialog.dir_selected.is_connected(scene._export_opengs), "OpenGS folder dialog must be connected in the scene")
	check(not scene.opengs_button.disabled, "OpenGS export must enable after generation")
	var expected_regions = int(scene.generated_settings.heightmap_width / 256) * int(scene.generated_settings.heightmap_length / 256)
	check(scene.terrain.data.get_regions_active().size() == expected_regions, "Initial map must contain the expected regions")
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
	var saved_material = load(folder.path_join("terrain_material.res")) as Terrain3DMaterial
	check(saved_material != null and saved_material.shader_override_enabled, "Save must retain the custom terrain material")
	if has_renderer:
		# Terrain3D initializes a loaded material's uniforms when attached to a node.
		scene.terrain.material = saved_material
		await process_frame
		check(saved_material.get_shader_param("surface_map") is Texture2D, "Saved terrain material must retain its generated surface texture")
		check(saved_material.get_shader_param("detail_albedo") is Texture2DArray, "Saved terrain material must retain PBR detail textures")
		scene.terrain.material = original_material
	var saved_water = load(folder.path_join("water_material.res")) as ShaderMaterial
	check(saved_water != null and saved_water.shader.resource_path == "res://addons/terrain_3d/extras/shaders/ocean_shader.gdshader", "Saved water must retain Terrain3D native ocean shader")
	var settings = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("map.json")))
	check(settings.generator_revision == 5 and settings.relief_profile == 0 and settings.detail_strength == 1.0 and settings.seed == 12345 and settings.width == 256 and settings.length == 512, "Saved settings must match generated map")
	check(DirAccess.get_files_at(folder.path_join("terrain")).size() == 2, "Save must write Terrain3D regions")
	var previous = FileAccess.get_file_as_bytes(folder.path_join("heightmap.exr"))
	scene._save(ProjectSettings.globalize_path(folder))
	check(previous == FileAccess.get_file_as_bytes(folder.path_join("heightmap.exr")), "Nonempty map folders must not be overwritten")
	var export_folder = "res://tests/output/opengs_scene_" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(export_folder)
	var before_export = scene.heightmap.get_data()
	scene._export_opengs(ProjectSettings.globalize_path(export_folder))
	check(scene.busy and scene.opengs_button.disabled and scene.generate_button.disabled and scene.save_button.disabled, "OpenGS export must lock mutations until its worker finishes")
	scene._generate()
	while scene.busy: await process_frame
	check(scene.heightmap.get_data() == before_export, "OpenGS export must preserve current terrain")
	check(not scene.opengs_button.disabled and not scene.generate_button.disabled and not scene.save_button.disabled, "OpenGS export must restore controls")
	var export_metadata = JSON.parse_string(FileAccess.get_file_as_string(export_folder.path_join("opengs_export.json")))
	check(export_metadata.source_settings.seed == 12345 and export_metadata.source_settings.sea_level == 0.25 and export_metadata.source_settings.height_scale == 500, "OpenGS export must use generated settings rather than edited controls")
	check(Image.load_from_file(export_folder.path_join("land.png")).get_size() == scene.heightmap.get_size(), "Runtime OpenGS export must use the heightmap resolution")
	scene._export_opengs(ProjectSettings.globalize_path(export_folder))
	while scene.busy: await process_frame
	check(scene.status.text.contains("empty folder") and not scene.opengs_button.disabled, "Export errors must be shown and controls restored")
	# Regression: a StandardMaterial3D used to cast to Nil and crash _import.
	scene.terrain.ocean_material = StandardMaterial3D.new()
	scene.generate_button.pressed.emit()
	while scene.busy: await process_frame
	check(scene.terrain.ocean_material is StandardMaterial3D, "Generation must tolerate a non-shader ocean material")
	check(not scene.save_button.disabled, "Generation must complete with a non-shader ocean material")
	# High sampling increases height data resolution without enlarging the world.
	scene.quality_input.select(1)
	scene.generate_button.pressed.emit()
	while scene.busy: await process_frame
	check(scene.heightmap.get_size() == Vector2i(512, 1024), "High quality must double elevation samples per axis")
	check(scene.terrain.vertex_spacing == 0.5, "High quality must retain physical map dimensions")
	check(scene.generated_settings.width == 256 and scene.generated_settings.length == 512, "Physical dimensions must remain unchanged")
	check(scene.terrain.data.get_regions_active().size() == 8, "High quality must import all higher-resolution regions")
	var high_expected = scene.heightmap.get_pixel(200, 400).r * 500.0 - 125.0
	check(absf(scene.terrain.data.get_height(Vector3(100, 0, 200)) - high_expected) < 0.02, "High-resolution Terrain3D heights must match the generated elevation data")
	# Check an unconfigured material before the native ocean has live clipmap RIDs.
	# Clearing an active native material itself is an addon/engine concern.
	var probe = load("res://scenes/map_editor.tscn").instantiate()
	probe.terrain = probe.get_node("Terrain3D")
	probe.terrain.ocean_material = null
	probe._configure_ocean()
	check(probe.terrain.ocean_material != null, "A cleared ocean material must receive the native fallback")
	probe.free()
	scene.queue_free()
	await process_frame
	if not has_renderer: print("GPU texture-binding checks require the non-headless test run.")
	print("MAP EDITOR TESTS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
