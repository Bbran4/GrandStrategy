extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var scene = load("res://scenes/map_editor.tscn").instantiate()
	root.add_child(scene)
	while scene.busy: await process_frame
	for frame in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/output/map_editor_preview.png")
	quit()
