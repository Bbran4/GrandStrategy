extends SceneTree

func _initialize() -> void: call_deferred("_capture")

func _capture() -> void:
	var softer = "--softer" in OS.get_cmdline_user_args()
	var scene = load("res://scenes/map_editor.tscn").instantiate()
	scene.relief_profile = 1 if softer else 0
	# A neutral relief study, independent of the player's saved material/height defaults.
	scene.get_node("%HeightInput").value = 100
	root.add_child(scene)
	while scene.busy: await process_frame
	for frame in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/output/heightmap_editor_v4.png")
	scene.get_node("EditorUI").hide()
	scene.target = Vector3(scene.generated_settings.width * 0.76, 14, scene.generated_settings.length * 0.54)
	scene.distance = 230.0 if softer else 180.0
	scene.pitch = 0.95 if softer else 0.7
	scene._update_camera()
	scene.camera.h_offset = 0
	scene.terrain.material.set_shader_param("surface_detail_strength", 0.0)
	scene.terrain.material.set_shader_param("detail_bump_strength", 0.0)
	scene.terrain.material.show_grey = true
	for frame in 45: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/output/terrain_softer_reference.png" if softer else "res://tests/output/terrain_rugged_reference.png")
	var gray = scene.heightmap.duplicate()
	var data = gray.get_data().to_float32_array()
	gray = Image.create_empty(gray.get_width(), gray.get_height(), false, Image.FORMAT_RGB8)
	for y in gray.get_height():
		for x in gray.get_width():
			var h = data[x + y * gray.get_width()]
			gray.set_pixel(x, y, Color(h, h, h))
	gray.save_png("res://tests/output/heightmap_data_v4.png")
	print("HEIGHTMAP GEOMETRY PREVIEW: ", scene.heightmap.get_size(), " spacing ", scene.terrain.vertex_spacing)
	quit()
