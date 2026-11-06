extends SceneTree

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var scene = load("res://scenes/map_editor.tscn").instantiate()
	scene.auto_import_provinces = true
	root.add_child(scene)
	while scene.busy: await process_frame
	await process_frame
	await process_frame
	while scene.busy: await process_frame
	if scene.provinces.map_data == null:
		push_error(scene.status.text)
		quit(1)
		return
	var data = scene.provinces.map_data
	print("REAL OPENGS: ", data.provinces.size() - 1, " provinces / ", data.territories.size() - 1, " territories. Height hash: ", data.source_hashes.heightmap)
	print("WARNINGS: ", data.warnings)
	var selected = 1
	for i in range(1, data.provinces.size()):
		if data.provinces[i].type == "land": selected = i; break
	scene.provinces.select_province(selected)
	# Frame the map beside the selection panel, hiding only the authoring sidebar.
	scene.get_node("EditorUI/SettingsPanel").hide()
	scene.distance = scene.generated_settings.width * 0.75
	scene.pitch = 1.0
	scene._update_camera()
	scene.camera.h_offset = scene.distance * 0.18
	scene.get_node("EditorUI/SettingsPanel/Scroll").scroll_vertical = 400
	for frame in 45: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/output/opengs_real_territories.png")
	scene.province_mode.select(1)
	scene._on_province_mode_selected(1)
	for frame in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/output/opengs_real_provinces.png")
	quit()
