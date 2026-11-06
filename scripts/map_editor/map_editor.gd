extends Node3D

const DefaultOceanMaterial = preload("res://addons/terrain_3d/extras/shaders/M_ocean.tres")

const Appearance = preload("res://scripts/map_editor/terrain_appearance.gd")

@export_range(0.0, 2.0, 0.1) var detail_strength: float = 1.0

const Generator = preload("res://scripts/map_editor/old_world_generator.gd")
@onready var terrain: Terrain3D = $Terrain3D
@onready var camera: Camera3D = $Camera3D
@onready var width_input: SpinBox = %WidthInput
@onready var length_input: SpinBox = %LengthInput
@onready var height_input: SpinBox = %HeightInput
@onready var sea_input: SpinBox = %SeaInput
@onready var seed_input: SpinBox = %SeedInput
@onready var generate_button: Button = %GenerateButton
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

func _ready() -> void:
	_configure_ocean()
	terrain.set_camera(camera)
	_generate()

func _on_random_seed_pressed() -> void:
	seed_input.value = randi() % 2147483647

func _on_save_pressed() -> void:
	save_dialog.popup_centered_ratio(0.65)

func _generate() -> void:
	if busy: return
	busy = true
	generate_button.disabled = true
	save_button.disabled = true
	status.text = "Generating Old World heightmap…"
	var options = {"width": int(width_input.value), "length": int(length_input.value), "height_scale": height_input.value, "sea_level": sea_input.value / 100.0, "seed": int(seed_input.value), "template": "Old World", "generator_revision": 2, "detail_strength": detail_strength}
	worker = Thread.new()
	var error = worker.start(func():
		var image = Generator.new().generate(options.width, options.length, options.seed, options.detail_strength)
		return {"height": image, "color": Appearance.colorize(image, options)}
	)
	if error != OK:
		busy = false
		generate_button.disabled = false
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
	save_button.disabled = false

func _import(image: Image, colors: Image, options: Dictionary) -> void:
	# Keep the authored Terrain3D node, material, assets and inspector settings.
	# Only replace its map regions, using Terrain3D's supported data API.
	for region: Terrain3DRegion in terrain.data.get_regions_active():
		terrain.data.remove_region(region, false)
	terrain.data.update_maps(Terrain3DRegion.TYPE_MAX, true, false)
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
	status.text = "%d × %d · seed %d\nTerrain ready. Changes apply on Generate." % [options.width, options.length, options.seed]

func _configure_ocean() -> void:
	# Terrain3D owns the ocean clipmap and passes it mesh/camera uniforms.
	# Keep the inspector material; only supply a fallback if it was cleared.
	if terrain.ocean_material == null:
		terrain.ocean_material = DefaultOceanMaterial.duplicate(true)
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
	var file = FileAccess.open(folder.path_join("map.json"), FileAccess.WRITE)
	if file == null:
		status.text = "Could not save map settings."
		return
	file.store_string(JSON.stringify(generated_settings, "\t"))
	status.text = "Saved heightmap, settings, terrain and materials to:\n" + folder

func _exit_tree() -> void:
	if worker != null and worker.is_started(): worker.wait_to_finish()
