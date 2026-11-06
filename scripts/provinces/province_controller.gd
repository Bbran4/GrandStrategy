extends Node
signal province_selected(index: int)
signal province_hovered(index: int)

const Data = preload("res://scripts/provinces/province_map_data.gd")
const Importer = preload("res://scripts/provinces/opengs_importer.gd")
@onready var terrain: Terrain3D = get_parent().get_node("Terrain3D")
@onready var camera: Camera3D = get_parent().get_node("Camera3D")
var map_data: Data
var selected = 0
var hovered = 0
var view_mode = 0
var borders_enabled = true
var _textures: Dictionary = {}
var _hover_timer = 0.0

func apply_data(data: Data) -> void:
	map_data = data
	selected = 0
	hovered = 0
	for key in _textures: _set_uniform(key, null)
	_textures.clear()
	if data == null:
		_set_uniform("province_overlay_enabled", false)
		province_selected.emit(0)
		province_hovered.emit(0)
		return
	for spec in [["province_id_map", data.province_index_image], ["territory_id_map", data.territory_index_image], ["province_color_lookup", data.province_lookup], ["territory_color_lookup", data.territory_lookup], ["province_owner_lookup", data.owner_lookup], ["province_owner_ids", data.owner_id_lookup], ["province_border_distance", data.border_distance_image]]:
		_textures[spec[0]] = ImageTexture.create_from_image(spec[1])
		_set_uniform(spec[0], _textures[spec[0]])
	_set_uniform("province_world_size", Vector2(data.size) * data.spacing)
	_set_uniform("province_raster_size", Vector2(data.size))
	_set_uniform("province_selected_id", 0)
	_set_uniform("province_hovered_id", 0)
	_set_uniform("province_overlay_enabled", true)
	set_view_mode(view_mode)
	province_selected.emit(0)
	province_hovered.emit(0)

func set_view_mode(mode: int) -> void:
	view_mode = clampi(mode, 0, 3)
	_set_uniform("province_view_mode", view_mode)
	_set_uniform("province_borders_enabled", borders_enabled)

func select_province(index: int) -> void:
	if map_data == null: index = 0
	elif index < 0 or index >= map_data.provinces.size(): index = 0
	selected = index
	_set_uniform("province_selected_id", selected)
	province_selected.emit(selected)

func set_province_owner(owner_id: String, color: Color) -> bool:
	if map_data == null or not map_data.set_owner(selected, owner_id, color): return false
	(_textures.province_owner_lookup as ImageTexture).update(map_data.owner_lookup)
	(_textures.province_owner_ids as ImageTexture).update(map_data.owner_id_lookup)
	province_selected.emit(selected)
	return true

func _set_uniform(name: String, value: Variant) -> void:
	if not is_instance_valid(terrain): return
	terrain.material.set_shader_param(name, value)
	var water = terrain.ocean_material as ShaderMaterial
	if water != null and water.shader != null:
		# A StandardMaterial3D or third-party ocean remains usable, but cannot render this overlay.
		for uniform in water.shader.get_shader_uniform_list():
			if uniform.name == name:
				water.set_shader_parameter(name, value)
				break

func _process(delta: float) -> void:
	if map_data == null: return
	_hover_timer -= delta
	if _hover_timer > 0: return
	_hover_timer = 0.075
	var index = 0
	if get_viewport().gui_get_hovered_control() == null:
		index = pick(get_viewport().get_mouse_position())
	if index != hovered:
		hovered = index
		_set_uniform("province_hovered_id", hovered)
		province_hovered.emit(hovered)

func _unhandled_input(event: InputEvent) -> void:
	if map_data == null: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		select_province(pick(event.position))
		get_viewport().set_input_as_handled()

func pick(screen_position: Vector2) -> int:
	if map_data == null: return 0
	var origin = camera.project_ray_origin(screen_position)
	var direction = camera.project_ray_normal(screen_position)
	var ray_start = origin
	var vertical_bound = float(map_data.source_settings.get("height_scale", 1500.0)) + 20.0
	var world_size = Vector2(map_data.size) * map_data.spacing
	var bounds = AABB(Vector3(0, -vertical_bound, 0), Vector3(world_size.x, vertical_bound * 2, world_size.y))
	var entry = bounds.intersects_ray(origin, direction)
	if entry is Vector3 and origin.distance_to(entry) > 5.0:
		ray_start = entry - direction * 1.0
	var hit = terrain.get_intersection(ray_start, direction, false)
	if not hit.is_finite() or hit.z > 3.4e38: return 0
	# The visible water surface is above the seabed. Prefer it when nearer.
	if direction.y < -0.000001:
		var plane_distance = -origin.y / direction.y
		if plane_distance > 0:
			var water_hit = origin + direction * plane_distance
			if plane_distance < origin.distance_to(hit) and map_data.province_at_world(water_hit) != 0:
				hit = water_hit
	return map_data.province_at_world(hit)

