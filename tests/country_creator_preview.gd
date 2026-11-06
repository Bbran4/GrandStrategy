extends SceneTree
const Store = preload("res://scripts/countries/country_store.gd")
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var scene = load("res://scenes/country_creator.tscn").instantiate()
	scene.storage_directory = "res://data/countries"
	root.add_child(scene)
	var library = Store.load_library(scene.storage_directory)
	for tribe in library.records:
		if tribe.id == "FJORD": scene._edit(tribe,tribe.id); break
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://tests/output")
	root.get_texture().get_image().save_png("res://tests/output/country_creator.png")
	quit()
