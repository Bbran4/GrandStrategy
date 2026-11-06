extends SceneTree
const Store = preload("res://scripts/countries/country_store.gd")
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var folder = "res://tests/output/country_preview"
	var data = Store.blank()
	data.id = "FJORD"
	data.name = "Fjord clans"
	data.adjective = "Fjordish"
	data.description = "A union of coastal clans, bound by the assembly and the sea."
	data.color = "#315f73"
	data.secondary_color = "#e5d5ac"
	data.traditions = ["seafarers","oral_history"]
	data.tribal_profile = "tribal_assembly"
	data.ai.trade = 65
	var error = Store.save_country(data,folder,"FJORD" if FileAccess.file_exists(folder.path_join("FJORD.json")) else "")
	if not error.is_empty(): push_error(error); quit(1); return
	var scene = load("res://scenes/country_creator.tscn").instantiate()
	scene.storage_directory = folder
	root.add_child(scene)
	scene._edit(data,"FJORD")
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/output/country_creator.png")
	scene.get_node("%Tabs").current_tab = 2
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/output/country_creator_build.png")
	quit()
