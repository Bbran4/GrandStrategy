extends SceneTree
## Rebuild the scene's deterministic, seamless procedural PBR texture arrays.
const SIZE = 512

func _initialize() -> void: call_deferred("_build")

func _noise(seed_value: int, frequency: float, ridged: bool = false) -> Image:
	var noise = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	noise.fractal_octaves = 5
	if ridged: noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	var texture = NoiseTexture2D.new()
	texture.width = SIZE
	texture.height = SIZE
	texture.seamless = true
	texture.noise = noise
	await texture.changed
	return texture.get_image()

func _build() -> void:
	assert(DisplayServer.get_name() != "headless", "Texture arrays must be built with a graphics device to serialize their pixels.")
	var broad: Image = await _noise(5127, 0.012)
	var medium: Image = await _noise(9133, 0.065)
	var fine: Image = await _noise(4712, 0.4)
	var ridge: Image = await _noise(1987, 0.035, true)
	var albedos: Array[Image] = []
	var normals: Array[Image] = []
	for layer in 3:
		var albedo = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		var normal = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		var heights = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RF)
		for y in SIZE:
			for x in SIZE:
				var a = broad.get_pixel(x, y).r
				var b = medium.get_pixel(x, y).r
				var c = fine.get_pixel(x, y).r
				var r = ridge.get_pixel(x, y).r
				var h: float
				var color: Color
				if layer == 0:
					h = b * 0.3 + c * 0.45 + a * 0.25
					color = Color("646b45").lerp(Color("9a9068"), smoothstep(0.3, 0.7, a))
					color = color.lerp(Color("4b5136"), smoothstep(0.55, 0.8, b) * 0.45)
				elif layer == 1:
					var fissure = smoothstep(0.28, 0.42, r)
					var strata = sin(float(y) * TAU * 20.0 / SIZE + b * 6.0 + a * 12.0) * 0.5 + 0.5
					h = r * 0.5 + b * 0.2 + c * 0.12 + strata * 0.18
					color = Color("58564e").lerp(Color("aaa28f"), a * 0.4 + b * 0.3 + strata * 0.3)
					color *= 0.65 + fissure * 0.35
				else:
					var ripple = sin(float(x) * TAU * 16.0 / SIZE + b * 4.0) * 0.5 + 0.5
					h = b * 0.35 + c * 0.4 + ripple * 0.25
					color = Color("9e9478").lerp(Color("bfb28e"), a)
				color *= 0.87 + c * 0.26
				color.a = h
				albedo.set_pixel(x, y, color)
				heights.set_pixel(x, y, Color(h, 0, 0))
		for y in SIZE:
			for x in SIZE:
				var dx = heights.get_pixel((x + 1) % SIZE, y).r - heights.get_pixel(posmod(x - 1, SIZE), y).r
				var dy = heights.get_pixel(x, (y + 1) % SIZE).r - heights.get_pixel(x, posmod(y - 1, SIZE)).r
				var n = Vector3(-dx * 3.0, -dy * 3.0, 1).normalized()
				normal.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 0.78 + fine.get_pixel(x, y).r * 0.2))
		albedo.generate_mipmaps()
		normal.generate_mipmaps()
		albedos.append(albedo)
		normals.append(normal)
	var colors = Texture2DArray.new()
	var rough_normals = Texture2DArray.new()
	assert(colors.create_from_images(albedos) == OK)
	assert(rough_normals.create_from_images(normals) == OK)
	assert(colors.get_layer_data(0) != null)
	assert(ResourceSaver.save(colors, "res://shaders/detail/terrain_albedo_height.res") == OK)
	assert(ResourceSaver.save(rough_normals, "res://shaders/detail/terrain_normal_roughness.res") == OK)
	print("Built seamless ground, rock and sand PBR texture layers.")
	quit()
