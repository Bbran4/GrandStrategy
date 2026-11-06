extends RefCounted
## Deterministic, elevation/slope/moisture-based cartographic surface colors.

static func colorize(image: Image, options: Dictionary) -> Image:
	var moisture = FastNoiseLite.new()
	moisture.seed = int(options.seed) + 3417
	moisture.frequency = 0.008
	moisture.fractal_octaves = 4
	var detail = FastNoiseLite.new()
	detail.seed = int(options.seed) + 836
	detail.frequency = 0.18
	detail.fractal_octaves = 3
	var colors = Image.create_empty(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	var sea = float(options.sea_level)
	var scale = 1024.0 / maxf(image.get_width(), image.get_height())
	for y in image.get_height():
		for x in image.get_width():
			var h = image.get_pixel(x, y).r
			var dx = (image.get_pixel(mini(x + 1, image.get_width() - 1), y).r - image.get_pixel(maxi(x - 1, 0), y).r) * options.height_scale * 0.5
			var dz = (image.get_pixel(x, mini(y + 1, image.get_height() - 1)).r - image.get_pixel(x, maxi(y - 1, 0)).r) * options.height_scale * 0.5
			var slope = Vector2(dx, dz).length()
			var wet = moisture.get_noise_2d(x * scale, y * scale) * 0.5 + 0.5
			var grain = detail.get_noise_2d(x * scale, y * scale)
			var latitude = absf(float(y) / image.get_height() - 0.5) * 2.0
			var land_height = maxf(0, (h - sea) / maxf(0.01, 1.0 - sea))
			var dry = smoothstep(0.3, 0.7, 1.0 - wet + (1.0 - latitude) * 0.12)
			var grass = Color("66714a").lerp(Color("aaa077"), dry)
			var forest = smoothstep(0.52, 0.7, wet) * (1.0 - smoothstep(0.22, 0.5, land_height))
			grass = grass.lerp(Color("364b35"), forest * 0.75)
			var rock = Color("777568").lerp(Color("a59981"), dry)
			var rocky = maxf(smoothstep(0.22, 0.75, slope), smoothstep(0.25, 0.55, land_height))
			var color = grass.lerp(rock, rocky * 0.9)
			var snow = smoothstep(0.70 - latitude * 0.1, 0.93 - latitude * 0.1, land_height + grain * 0.025)
			color = color.lerp(Color("d9dcd1"), snow)
			var beach = (1.0 - smoothstep(0.001, 0.009, h - sea)) * (1.0 - smoothstep(0.08, 0.35, slope))
			color = color.lerp(Color("b8ac87"), beach * 0.7)
			# Blend across the waterline rather than classifying each image pixel
			# as either land or seabed (which leaves a square texel silhouette).
			var seabed = Color("45676b").lerp(Color("203f50"), smoothstep(0.0, 0.15, sea - h))
			color = seabed.lerp(color, smoothstep(sea - 0.006, sea + 0.006, h))
			color *= 1.0 + grain * 0.12
			color.a = 1.0
			colors.set_pixel(x, y, color)
	return colors
