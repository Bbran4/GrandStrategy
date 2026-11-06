extends SceneTree

func _initialize() -> void: call_deferred("_capture")

func _capture() -> void:
	var scene = load("res://scenes/map_editor.tscn").instantiate()
	root.add_child(scene)
	while scene.busy: await process_frame
	for frame in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/output/detail_overview.png")
	scene.get_node("EditorUI").hide()
	scene.target = Vector3(scene.generated_settings.width * 0.76, 0, scene.generated_settings.length * 0.54)
	scene.distance = 145.0
	scene.pitch = 0.85
	scene._update_camera()
	scene.camera.h_offset = 0
	for frame in 45: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/output/detail_closeup.png")
	quit()
