extends SceneTree

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var scene = load("res://scenes/map_editor.tscn").instantiate()
	root.add_child(scene)
	while scene.busy: await process_frame
	var folder = "res://tests/output/opengs_reference_" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	scene._export_opengs(ProjectSettings.globalize_path(folder))
	while scene.busy: await process_frame
	if not FileAccess.file_exists(folder.path_join("opengs_export.json")):
		push_error(scene.status.text)
		quit(1)
		return
	for frame in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/output/opengs_export_editor.png")
	print("OpenGS reference export: ", ProjectSettings.globalize_path(folder))
	quit()
