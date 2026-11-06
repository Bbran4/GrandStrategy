extends SceneTree
const Store = preload("res://scripts/countries/country_store.gd")
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.gui_embed_subwindows = true
	var planner = load("res://scenes/progression_planner.tscn").instantiate()
	root.add_child(planner)
	planner.open_plan({"research_budget":1200,"skill_budget":6,"unlocks":[]})
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
