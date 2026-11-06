extends SceneTree
const CountryStore = preload("res://scripts/countries/country_store.gd")
const Fixture = preload("res://tests/opengs_fixture.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
func _run() -> void:
	var scene = load("res://scenes/map_editor.tscn").instantiate()
	scene.auto_import_provinces = false
	scene.heightmap_quality = 0
	scene.erosion_strength = 0
	scene.get_node("%WidthInput").value = 256
	scene.get_node("%LengthInput").value = 256
	var country_folder = "res://tests/output/province_countries_" + str(Time.get_ticks_usec())
	var country = CountryStore.blank()
	country.id = "TEST_TRIBE"
	country.name = "Test tribe"
	country.adjective = "Tribal"
	country.color = "#315f73"
	check(CountryStore.save_country(country,country_folder).is_empty(),"Country fixture must save")
	scene.country_directory = country_folder
	root.add_child(scene)
	check(scene.country_library.item_count == 2,"Map must load the saved country library")
	while scene.busy: await process_frame
	scene._on_country_library_selected(1)
	check(scene.province_owner.text == "TEST_TRIBE" and scene.province_owner_color.color.is_equal_approx(Color("315f73")),"Country picker must populate stable ID and map color")
	check(scene.province_import_button.pressed.is_connected(scene._on_province_import_pressed), "Province import button must be scene-authored")
	check(scene.province_import_dialog.dir_selected.is_connected(scene._import_provinces), "Province folder dialog must be scene-authored")
	check(scene.provinces.province_selected.is_connected(scene._on_province_selected), "Selection signal must be scene-authored")
	var source_heights = scene.heightmap.get_data()
	var folder = "res://tests/output/province_scene_" + str(Time.get_ticks_usec())
	Fixture.create(folder, 256,256)
	scene._import_provinces(ProjectSettings.globalize_path(folder))
	check(scene.busy and scene.generate_button.disabled and scene.save_button.disabled and scene.opengs_button.disabled, "Import must lock conflicting operations")
	while scene.busy: await process_frame
	check(scene.provinces.map_data != null, "Runtime province import must succeed: " + scene.status.text)
	if scene.provinces.map_data == null: scene.queue_free(); quit(1); return
	var data = scene.provinces.map_data
	check(data.provinces.size() == 5 and data.territories.size() == 3, "Runtime must create logical provinces/territories")
	check(scene.heightmap.get_data() == source_heights, "Province import must not alter accepted terrain geometry")
	check(scene.province_panel.visible and scene.province_mode.selected == 2, "Import must expose province controls and political territory view")
	check(scene.terrain.material.get_shader_param("province_id_map") is Texture2D, "Terrain shader must receive exact province IDs")
	check(scene.terrain.ocean_material.get_shader_parameter("province_id_map") is Texture2D, "Terrain3D ocean must share province IDs")
	var index = data.province_at_world(Vector3(64,0,64))
	var h = scene.terrain.data.get_height(Vector3(64,0,64))
	var point = Vector3(64,maxf(0,h),64)
	for frame in 4: await process_frame
	var screen = scene.camera.unproject_position(point)
	check(scene.provinces.pick(screen) == index, "Screen picking must identify the visible terrain/water province")
	var old_distance = scene.distance
	scene.distance = 5000
	scene._update_camera()
	check(scene.provinces.pick(scene.camera.unproject_position(point)) == index, "Province picking must work beyond the native raymarch's initial 4000m range")
	scene.distance = old_distance
	scene._update_camera()
	scene.provinces.select_province(index)
	check(scene.province_info.text.contains("PRV_A") and not scene.province_owner_apply.disabled, "Selection must show province metadata and ownership controls")
	scene.province_owner.text = "ROM"
	scene.province_owner_color.color = Color("aa3344")
	scene._on_province_owner_apply()
	check(data.provinces[index].owner == "ROM" and scene.province_mode.selected == 3, "Ownership UI must update logical ownership and political mode")
	check(scene.terrain.material.get_shader_param("province_owner_ids") is Texture2D, "Ownership boundary lookup must be bound")
	var saved = folder.path_join("saved_world")
	DirAccess.make_dir_recursive_absolute(saved)
	scene._save(ProjectSettings.globalize_path(saved))
	check(FileAccess.file_exists(saved.path_join("provinces/province_state.json")), "Save world must include imported province state")
	var settings = JSON.parse_string(FileAccess.get_file_as_string(saved.path_join("map.json")))
	check(settings.province_package == "provinces", "Saved world must locate its province package")
	var original_data = scene.provinces.map_data
	var empty = folder.path_join("invalid")
	DirAccess.make_dir_recursive_absolute(empty)
	scene._import_provinces(ProjectSettings.globalize_path(empty))
	while scene.busy: await process_frame
	check(scene.provinces.map_data == original_data and not scene.province_import_button.disabled, "Invalid imports must preserve active provinces and restore controls")
	scene._clear_provinces()
	check(scene.provinces.map_data == null and scene.heightmap.get_data() == source_heights, "Clearing provinces must retain terrain")
	scene._import_provinces(ProjectSettings.globalize_path(saved.path_join("provinces")))
	while scene.busy: await process_frame
	check(scene.provinces.map_data != null, "Saved province package must re-import in the runtime")
	if scene.provinces.map_data != null:
		var restored = scene.provinces.map_data.province_at_world(Vector3(64,0,64))
		check(scene.provinces.map_data.provinces[restored].owner == "ROM", "Runtime save/re-import must preserve country ownership")
	scene._generate()
	while scene.busy: await process_frame
	check(scene.provinces.map_data == null, "Regenerating terrain must clear stale province data")
	check(scene.heightmap.get_data() == source_heights, "Province features must preserve reproducible terrain generation")
	scene.queue_free()
	await process_frame
	print("PROVINCE SCENE TESTS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
