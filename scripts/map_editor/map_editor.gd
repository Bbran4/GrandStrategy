extends Node3D

const CountryStore = preload("res://scripts/countries/country_store.gd")
@export_dir var country_directory: String = ""
@onready var country_library: OptionButton = %CountryLibrary

const ProvinceImporter = preload("res://scripts/provinces/opengs_importer.gd")
const StrategyOceanShader = preload("res://shaders/strategy_ocean.gdshader")
@export_dir var opengs_import_directory: String = "res://data/opengs"
@export var auto_import_provinces: bool = true

const DefaultOceanMaterial = preload("res://addons/terrain_3d/extras/shaders/M_ocean.tres")

const OpenGSExporter = preload("res://scripts/map_editor/opengs_exporter.gd")

const Appearance = preload("res://scripts/map_editor/terrain_appearance.gd")

@export_enum("Rugged reference", "Softer reference") var relief_profile: int = 0

@export_enum("Standard (1 sample/m)", "High (2 samples/m)") var heightmap_quality: int = 1
@export_range(0.0, 2.0, 0.1) var erosion_strength: float = 1.0

@export_range(0.0, 2.0, 0.1) var detail_strength: float = 1.0

const Generator = preload("res://scripts/map_editor/old_world_generator.gd")
@onready var provinces = $Provinces
@onready var province_import_button: Button = %ProvinceImportButton
@onready var province_import_dialog: FileDialog = $EditorUI/ProvinceImportDialog
@onready var province_mode: OptionButton = %ProvinceMode
@onready var province_borders: CheckButton = %ProvinceBorders
@onready var province_clear: Button = %ProvinceClearButton
@onready var province_panel: PanelContainer = $EditorUI/ProvincePanel
@onready var province_info: Label = %ProvinceInfo
@onready var province_hover: Label = %ProvinceHover
@onready var province_owner: LineEdit = %ProvinceOwner
@onready var province_owner_color: ColorPickerButton = %ProvinceOwnerColor
@onready var province_owner_apply: Button = %ProvinceOwnerApply
@onready var terrain: Terrain3D = $Terrain3D
@onready var terrain_focus: Node3D = $TerrainFocus
@onready var camera: Camera3D = $Camera3D
@onready var profile_input: OptionButton = %ProfileInput
@onready var neutral_view: CheckButton = %NeutralView
@onready var quality_input: OptionButton = %QualityInput
@onready var erosion_input: SpinBox = %ErosionInput
@onready var width_input: SpinBox = %WidthInput
@onready var length_input: SpinBox = %LengthInput
@onready var height_input: SpinBox = %HeightInput
@onready var sea_input: SpinBox = %SeaInput
@onready var seed_input: SpinBox = %SeedInput
@onready var generate_button: Button = %GenerateButton
@onready var opengs_button: Button = %OpenGSExportButton
@onready var opengs_dialog: FileDialog = $EditorUI/OpenGSExportDialog
@onready var save_button: Button = %SaveButton
@onready var status: Label = %Status
@onready var preview: TextureRect = %Preview
@onready var save_dialog: FileDialog = $EditorUI/SaveDialog
var heightmap: Image
var generated_settings: Dictionary = {}
var worker: Thread
var busy = false
var target = Vector3.ZERO
var yaw = 0.0
var pitch = 1.08
var distance = 1400.0
var dragging = false
var panning = false
var _colored_detail_strength: float = 1.0
var _colored_bump_strength: float = 0.35

func _ready() -> void:
	_refresh_country_library()
	country_library.get_popup().about_to_popup.connect(_refresh_country_library)
	country_library.item_selected.connect(_on_country_library_selected)
	profile_input.select(relief_profile)
	var authored_detail = terrain.material.get_shader_param("surface_detail_strength")
	var authored_bump = terrain.material.get_shader_param("detail_bump_strength")
	if authored_detail != null: _colored_detail_strength = float(authored_detail)
	if authored_bump != null: _colored_bump_strength = float(authored_bump)
	_on_neutral_view_toggled(neutral_view.button_pressed)
	quality_input.select(heightmap_quality)
	erosion_input.value = erosion_strength
	_configure_ocean()
	terrain.set_camera(camera)
	_generate()

func _on_random_seed_pressed() -> void:
	seed_input.value = randi() % 2147483647

func _on_neutral_view_toggled(enabled: bool) -> void:
	terrain.material.show_grey = enabled and provinces.map_data == null
	terrain.material.set_shader_param("province_neutral_base", enabled)
	provinces._set_uniform("province_neutral_base", enabled)
	terrain.material.set_shader_param("surface_detail_strength", 0.0 if enabled else _colored_detail_strength)
	terrain.material.set_shader_param("detail_bump_strength", 0.0 if enabled else _colored_bump_strength)
	if not generated_settings.is_empty(): generated_settings["neutral_relief"] = enabled

func _on_opengs_export_pressed() -> void:
	if busy or heightmap == null: return
	opengs_dialog.popup_centered_ratio(0.65)

func _export_opengs(folder: String) -> void:
	if busy or heightmap == null: return
	busy = true
	generate_button.disabled = true
	province_import_button.disabled = true
	save_button.disabled = true
	opengs_button.disabled = true
	status.text = "Exporting OpenGS land, boundary, density and terrain images…"
	# Use the last generated map, not subsequently edited input controls.
	var source_image = heightmap
	var source_settings = generated_settings.duplicate(true)
	worker = Thread.new()
	var error = worker.start(func(): return OpenGSExporter.export_folder(folder, source_image, source_settings))
	if error != OK:
		worker = null
		status.text = "Could not start export: " + error_string(error)
	else:
		while worker.is_alive(): await get_tree().process_frame
		var result: Dictionary = worker.wait_to_finish()
		worker = null
		if result.error.is_empty():
			status.text = "OpenGS images exported. Boundary is unconstrained.\n" + folder
		else:
			status.text = result.error
	busy = false
	generate_button.disabled = false
	province_import_button.disabled = heightmap == null
	save_button.disabled = false
	opengs_button.disabled = false

func _on_province_import_pressed() -> void:
	if busy or heightmap == null: return
	province_import_dialog.current_dir = ProjectSettings.globalize_path(opengs_import_directory)
	province_import_dialog.popup_centered_ratio(0.65)

func _try_default_provinces() -> void:
	if not auto_import_provinces or busy: return
	for name in ["provinces.png", "province_map.png", "province.png", "province_image.png"]:
		if FileAccess.file_exists(opengs_import_directory.path_join(name)):
			_import_provinces(ProjectSettings.globalize_path(opengs_import_directory))
			return

func _import_provinces(folder: String) -> void:
	if busy or heightmap == null: return
	busy = true
	generate_button.disabled = true
	province_import_button.disabled = true
	save_button.disabled = true
	opengs_button.disabled = true
	status.text = "Importing OpenGS provinces, territory membership and shared borders…"
	var source_image = heightmap
	var source_settings = generated_settings.duplicate(true)
	worker = Thread.new()
	var error = worker.start(func(): return ProvinceImporter.load_folder(folder, source_image, source_settings))
	if error != OK:
		worker = null
		status.text = "Could not start province import: " + error_string(error)
	else:
		while worker.is_alive(): await get_tree().process_frame
		var result: Dictionary = worker.wait_to_finish()
		worker = null
		if not result.error.is_empty():
			status.text = result.error
		else:
			provinces.apply_data(result.data)
			province_mode.select(2)
			province_mode.disabled = false
			province_borders.disabled = false
			province_clear.disabled = false
			_on_province_mode_selected(2)
			_on_neutral_view_toggled(neutral_view.button_pressed)
			status.text = "Imported %d provinces and %d territories." % [result.data.provinces.size() - 1, result.data.territories.size() - 1]
			for warning in result.data.warnings: status.text += "\n" + warning
	busy = false
	generate_button.disabled = false
	province_import_button.disabled = false
	save_button.disabled = false
	opengs_button.disabled = false

func _clear_provinces() -> void:
	if busy: return
	_clear_province_data()
	status.text = "Province map cleared. Terrain is unchanged."

func _clear_province_data() -> void:
	provinces.apply_data(null)
	province_mode.select(0)
	province_mode.disabled = true
	province_borders.disabled = true
	province_clear.disabled = true
	_on_neutral_view_toggled(neutral_view.button_pressed)

func _on_province_mode_selected(index: int) -> void:
	provinces.set_view_mode(index)

func _on_province_borders_toggled(enabled: bool) -> void:
	provinces.borders_enabled = enabled
	provinces.set_view_mode(province_mode.selected)

func _on_province_hovered(index: int) -> void:
	province_hover.text = "Hover: " + provinces.map_data.provinces[index].id if index > 0 and provinces.map_data != null else "Hover: —"

func _on_province_selected(index: int) -> void:
	province_panel.visible = provinces.map_data != null
	province_owner_apply.disabled = index == 0
	if index == 0:
		province_info.text = "Click a province to inspect it."
		province_owner.text = ""
		return
	var record = provinces.map_data.provinces[index]
	province_owner.text = record.owner
	_refresh_country_library()
	province_owner_color.color = Color.from_string(record.owner_color, Color("c9a05a"))
	province_info.text = "%s\nTerritory: %s\nType: %s · Terrain: %s\nArea: %.1f m²\nOwner: %s\nNeighbours (%d): %s" % [record.id, record.territory_id, record.type, record.terrain if not record.terrain.is_empty() else "not supplied", record.area_m2, record.owner if not record.owner.is_empty() else "unassigned", record.neighbours.size(), ", ".join(record.neighbours.slice(0, 12))]

func _on_province_owner_apply() -> void:
	if busy: return
	if provinces.set_province_owner(province_owner.text, province_owner_color.color):
		province_mode.select(3)
		_on_province_mode_selected(3)
		status.text = "Province ownership updated; province geometry is unchanged."

func _on_save_pressed() -> void:
	save_dialog.popup_centered_ratio(0.65)

func _generate() -> void:
	if busy: return
	relief_profile = profile_input.selected
	heightmap_quality = quality_input.selected
	erosion_strength = erosion_input.value
	busy = true
	generate_button.disabled = true
	province_import_button.disabled = true
	save_button.disabled = true
	opengs_button.disabled = true
	status.text = "Generating Old World heightmap…"
	var options = {"width": int(width_input.value), "length": int(length_input.value), "height_scale": height_input.value, "sea_level": sea_input.value / 100.0, "seed": int(seed_input.value), "template": "Old World", "generator_revision": 5, "relief_profile": relief_profile, "neutral_relief": neutral_view.button_pressed, "detail_strength": detail_strength, "erosion_strength": erosion_strength, "samples_per_metre": 2 if heightmap_quality == 1 else 1}
	options["heightmap_width"] = options.width * options.samples_per_metre
	options["heightmap_length"] = options.length * options.samples_per_metre
	worker = Thread.new()
	var error = worker.start(func():
		var image = Generator.new().generate(options.heightmap_width, options.heightmap_length, options.seed, options.detail_strength, options.erosion_strength, options.relief_profile)
		return {"height": image, "color": Appearance.colorize(image, options)}
	)
	if error != OK:
		busy = false
		generate_button.disabled = false
		province_import_button.disabled = heightmap == null
		opengs_button.disabled = heightmap == null
		save_button.disabled = heightmap == null
		status.text = "Could not start generator: " + error_string(error)
		return
	# Poll on the main thread. Scene-tree / Terrain3D operations stay here.
	while worker.is_alive(): await get_tree().process_frame
	var result: Dictionary = worker.wait_to_finish()
	worker = null
	status.text = "Building Terrain3D regions…"
	await get_tree().process_frame
	_import(result.height, result.color, options)
	busy = false
	generate_button.disabled = false
	province_import_button.disabled = heightmap == null
	save_button.disabled = false
	opengs_button.disabled = false
	call_deferred("_try_default_provinces")

func _import(image: Image, colors: Image, options: Dictionary) -> void:
	_clear_province_data()
	# Keep the authored Terrain3D node, material, assets and inspector settings.
	# Only replace its map regions, using Terrain3D's supported data API.
	for region: Terrain3DRegion in terrain.data.get_regions_active():
		terrain.data.remove_region(region, false)
	terrain.data.update_maps(Terrain3DRegion.TYPE_MAX, true, false)
	terrain.vertex_spacing = 1.0 / options.samples_per_metre
	var sea = float(options.sea_level)
	# Use floating-point heights directly; avoid 8-bit PNG terracing.
	terrain.data.import_images([image, null, colors], Vector3.ZERO, -sea * options.height_scale, options.height_scale)
	var surface_image = colors.duplicate()
	surface_image.generate_mipmaps()
	terrain.material.set_shader_param("surface_map", ImageTexture.create_from_image(surface_image))
	terrain.material.set_shader_param("map_size", Vector2(options.width, options.length))
	_configure_ocean()
	heightmap = image
	generated_settings = options.duplicate()
	preview.texture = ImageTexture.create_from_image(colors)
	_frame_map()
	status.text = "%d × %d m · seed %d\n%d × %d height samples.\nTerrain ready." % [options.width, options.length, options.seed, options.heightmap_width, options.heightmap_length]

func _configure_ocean() -> void:
	# Terrain3D owns the ocean clipmap and passes it mesh/camera uniforms.
	# Keep the inspector material; only supply a fallback if it was cleared.
	if terrain.ocean_material == null:
		terrain.ocean_material = DefaultOceanMaterial.duplicate(true)
		terrain.ocean_material.shader = StrategyOceanShader
	terrain.ocean_enabled = true
	var water_material = terrain.ocean_material as ShaderMaterial
	if water_material != null and water_material.shader != null:
		for uniform in water_material.shader.get_shader_uniform_list():
			if uniform.name == "sea_level":
				# Imported land is already offset by the chosen normalized sea level.
				# Terrain3D's ocean shader uses world metres, so its level stays at zero.
				water_material.set_shader_parameter("sea_level", 0.0)
				break

func _frame_map() -> void:
	if generated_settings.is_empty(): return
	target = Vector3((generated_settings.width - 1) * 0.5, 0, (generated_settings.length - 1) * 0.5)
	distance = maxf(generated_settings.width, generated_settings.length) * 0.80
	_update_camera()

func _update_camera() -> void:
	terrain_focus.position = target
	camera.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(target)
	camera.h_offset = -distance * 0.28

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT: dragging = event.pressed
		if event.button_index == MOUSE_BUTTON_MIDDLE: panning = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			distance = clampf(distance * (0.88 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.14), 20, 12000)
	if event is InputEventMouseMotion:
		if dragging:
			yaw -= event.relative.x * 0.005
			pitch = clampf(pitch + event.relative.y * 0.005, 0.12, 1.5)
		if panning:
			target += (-camera.global_basis.x * event.relative.x + Vector3(sin(yaw), 0, cos(yaw)) * -event.relative.y) * distance * 0.0015
	if event is InputEventKey and event.pressed and event.keycode == KEY_F: _frame_map()
	_update_camera()

func _save(folder: String) -> void:
	if busy or heightmap == null: return
	# Prevent accidental replacement of an earlier map.
	var directory = DirAccess.open(folder)
	if directory == null: return
	if not directory.get_files().is_empty() or not directory.get_directories().is_empty():
		status.text = "Choose an empty folder to avoid replacing an existing map."
		return
	var error = heightmap.save_exr(folder.path_join("heightmap.exr"), true)
	if error != OK:
		status.text = "Could not save heightmap: " + error_string(error)
		return
	var terrain_folder = folder.path_join("terrain")
	error = DirAccess.make_dir_recursive_absolute(terrain_folder)
	if error != OK:
		status.text = "Could not create terrain folder: " + error_string(error)
		return
	terrain.data.save_directory(terrain_folder)
	# Persist the terrain surface texture and Terrain3D ocean material.
	# Binary resources keep floating-point image data compact and lossless.
	error = ResourceSaver.save(terrain.material, folder.path_join("terrain_material.res"))
	if error == OK:
		error = ResourceSaver.save(terrain.ocean_material, folder.path_join("water_material.res"))
	if error != OK:
		status.text = "Could not save map materials: " + error_string(error)
		return
	if provinces.map_data != null:
		error = provinces.map_data.save_to_folder(folder.path_join("provinces"))
		if error != OK:
			status.text = "Could not save province package: " + error_string(error)
			return
	var file = FileAccess.open(folder.path_join("map.json"), FileAccess.WRITE)
	if file == null:
		status.text = "Could not save map settings."
		return
	var saved_settings = generated_settings.duplicate(true)
	saved_settings["province_package"] = "provinces" if provinces.map_data != null else ""
	file.store_string(JSON.stringify(saved_settings, "\t"))
	status.text = "Saved heightmap, settings, terrain and materials to:\n" + folder

func _exit_tree() -> void:
	if worker != null and worker.is_started(): worker.wait_to_finish()

func _refresh_country_library() -> void:
	country_library.clear()
	country_library.add_item("Choose saved country / manual ID")
	country_library.set_item_metadata(0,{})
	var library = CountryStore.load_library(country_directory)
	for country in library.records:
		if country.get("archived",false): continue
		country_library.add_item(country.name + " [" + country.id + "]")
		country_library.set_item_metadata(country_library.item_count-1,country)
	country_library.tooltip_text = "Choose a saved nation to fill its ID and a display color; then assign it to the selected province."
	if not library.errors.is_empty(): country_library.tooltip_text += "\n" + "; ".join(library.errors)
	for i in range(1,country_library.item_count):
		if country_library.get_item_metadata(i).id == province_owner.text: country_library.select(i); break

func _on_country_library_selected(index: int) -> void:
	if busy or index == 0: return
	var country: Dictionary = country_library.get_item_metadata(index)
	province_owner.text = country.id
	province_owner_color.color = CountryStore.map_color(country.id)
