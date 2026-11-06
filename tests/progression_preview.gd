extends SceneTree
const Store = preload("res://scripts/countries/country_store.gd")
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.gui_embed_subwindows = true
	var creator = load("res://scenes/country_creator.tscn").instantiate()
	creator.storage_directory="res://tests/output/progression_preview"
	root.add_child(creator)
	var data = Store.blank(); data.id="FJORD"; data.name="Fjord clans"; data.adjective="Fjordish"
	creator._edit(data,"")
	creator.get_node("%Tabs").current_tab=2
	var planner = creator.get_node("ProgressionPlanner")
	planner.open_plan(data.build_plan)
	for id in ["clinker_hulls","longships","warband_customs","sea_raiders"]: planner.model.unlock(id)
	planner.selected="longships"; planner._refresh()
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://tests/output")
	root.get_texture().get_image().save_png("res://tests/output/technology_tree.png")
	planner.get_node("%TreeKind").select(1)
	planner.selected="sea_raiders"; planner._refresh()
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/output/national_skill_tree.png")
	quit()
