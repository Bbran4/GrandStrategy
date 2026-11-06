extends RefCounted
## Synthetic OpenGS-schema fixtures; these are not user-authored province exports.
static func create(folder: String, width: int = 8, height: int = 8, definitions: bool = true) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(folder)
	var province = Image.create_empty(width, height, false, Image.FORMAT_RGB8)
	var territory = Image.create_empty(width, height, false, Image.FORMAT_RGB8)
	var heights = Image.create_empty(width, height, false, Image.FORMAT_RF)
	heights.fill(Color(0.4, 0, 0))
	var colors = [Color8(200,10,20), Color8(30,180,40), Color8(25,70,200), Color8(180,50,200)]
	var tcolors = [Color8(200,160,60), Color8(60,80,170)]
	for y in height:
		for x in width:
			province.set_pixel(x, y, colors[(0 if x < width / 2 else 1) + (0 if y < height / 2 else 2)])
			territory.set_pixel(x, y, tcolors[0 if y < height / 2 else 1])
	province.save_png(folder.path_join("provinces.png"))
	territory.save_png(folder.path_join("territories.png"))
	if definitions:
		var pdefs = {}
		var tdefs = {}
		for i in 4:
			pdefs["PRV_" + ["A", "B", "C", "D"][i]] = {"R": colors[i].r8, "G": colors[i].g8, "B": colors[i].b8, "province_type": "land", "province_terrain": "forest", "x": 1, "y": 1}
		for i in 2:
			tdefs["TRT_" + ["NORTH", "SOUTH"][i]] = {"R": tcolors[i].r8, "G": tcolors[i].g8, "B": tcolors[i].b8, "territory_type": "land", "x": 1, "y": 1}
		write_json(folder.path_join("province_definitions.json"), pdefs)
		write_json(folder.path_join("territory_definitions.json"), tdefs)
	return {"heightmap": heights, "provinces": province, "territories": territory, "settings": {"width": width * 0.5, "length": height * 0.5, "samples_per_metre": 2, "height_scale": 100.0, "sea_level": 0.2, "seed": 12345}}

static func write_json(path: String, data: Dictionary) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
