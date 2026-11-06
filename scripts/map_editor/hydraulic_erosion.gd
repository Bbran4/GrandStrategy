extends RefCounted
## Seeded droplet erosion with bilinear gradients, soil removal and deposition.
## Simulates at up to 1024 samples across; applies its elevation delta to the full
## resolution field so fine ridge geometry survives reconstruction.

static func erode(image: Image, map_seed: int, strength: float) -> Image:
	if strength <= 0.0: return image
	var size = image.get_size()
	var simulation = image.duplicate()
	var ratio = minf(1.0, 1024.0 / maxf(size.x, size.y))
	if ratio < 1.0:
		simulation.resize(maxi(32, roundi(size.x * ratio)), maxi(32, roundi(size.y * ratio)), Image.INTERPOLATE_BILINEAR)
	var width = simulation.get_width()
	var length = simulation.get_height()
	var original = simulation.get_data().to_float32_array()
	var heights = original.duplicate()
	var starts = PackedInt32Array()
	for y in range(3, length - 3):
		for x in range(3, width - 3):
			var index = x + y * width
			if heights[index] > 0.26: starts.append(index)
	if starts.is_empty(): return image
	var rng = RandomNumberGenerator.new()
	rng.seed = map_seed + 971231
	var drops = clampi(roundi(starts.size() * 0.18), 2000, 50000)
	var offsets = PackedInt32Array([-width - 1, -width, -width + 1, -1, 0, 1, width - 1, width, width + 1])
	var weights = PackedFloat32Array([0.06, 0.12, 0.06, 0.12, 0.28, 0.12, 0.06, 0.12, 0.06])
	for drop in drops:
		var start = starts[rng.randi_range(0, starts.size() - 1)]
		var position = Vector2(start % width + rng.randf(), int(start / width) + rng.randf())
		var direction = Vector2.ZERO
		var speed = 1.0
		var water = 1.0
		var sediment = 0.0
		for age in 48:
			var current = _sample(heights, width, position)
			if current.x < 0.225: break
			direction = direction * 0.15 - Vector2(current.y, current.z) * 0.85
			if direction.length_squared() < 0.000000001:
				direction = Vector2.from_angle(rng.randf() * TAU)
			else: direction = direction.normalized()
			var next_position = position + direction
			if next_position.x < 2 or next_position.y < 2 or next_position.x >= width - 3 or next_position.y >= length - 3: break
			var next = _sample(heights, width, next_position)
			var difference = next.x - current.x
			var capacity = maxf(-difference * speed * water * 9.0, 0.00002)
			if sediment > capacity or difference > 0:
				var deposit = minf(difference, sediment) if difference > 0 else (sediment - capacity) * 0.3
				var deposited = _deposit(heights, original, width, position, deposit, strength)
				sediment -= deposited
			else:
				var cut = minf((capacity - sediment) * 0.38 * strength, maxf(0, -difference))
				cut *= smoothstep(0.225, 0.32, current.x)
				var index = int(position.x) + int(position.y) * width
				for brush in offsets.size():
					var i = index + offsets[brush]
					var removed = minf(maxf(0, heights[i] - maxf(0.222, original[i] - 0.065 * strength)), cut * weights[brush])
					heights[i] -= removed
					sediment += removed
			speed = sqrt(maxf(0.01, speed * speed - difference * 6.0))
			water *= 0.985
			position = next_position
		# Sediment still suspended at the lifetime/boundary limit leaves the simulation.
		# Dumping an entire droplet load onto one cell creates artificial needle peaks.
	var delta = PackedFloat32Array()
	delta.resize(heights.size())
	for i in heights.size(): delta[i] = heights[i] - original[i]
	var delta_image = Image.create_from_data(width, length, false, Image.FORMAT_RF, delta.to_byte_array())
	if delta_image.get_size() != size: delta_image.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
	var full = image.get_data().to_float32_array()
	var full_delta = delta_image.get_data().to_float32_array()
	for i in full.size():
		# Fade at the sea band, retaining the continental coastline.
		full[i] = clampf(full[i] + full_delta[i] * smoothstep(0.22, 0.26, full[i]), 0, 1)
	return Image.create_from_data(size.x, size.y, false, Image.FORMAT_RF, full.to_byte_array())

static func _sample(heights: PackedFloat32Array, width: int, position: Vector2) -> Vector3:
	var x = int(position.x)
	var y = int(position.y)
	var fx = position.x - x
	var fy = position.y - y
	var index = x + y * width
	var a = heights[index]
	var b = heights[index + 1]
	var c = heights[index + width]
	var d = heights[index + width + 1]
	return Vector3(lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy), lerpf(b - a, d - c, fy), lerpf(c - a, d - b, fx))

static func _deposit(heights: PackedFloat32Array, original: PackedFloat32Array, width: int, position: Vector2, amount: float, strength: float) -> float:
	var index = int(position.x) + int(position.y) * width
	var x = position.x - int(position.x)
	var y = position.y - int(position.y)
	var indices = PackedInt32Array([index, index + 1, index + width, index + width + 1])
	var weights = PackedFloat32Array([(1 - x) * (1 - y), x * (1 - y), (1 - x) * y, x * y])
	var deposited = 0.0
	for corner in 4:
		var i = indices[corner]
		# Limit fan buildup relative to the initial surface, rather than allowing
		# stationary droplets to accumulate unbounded single-cell spires.
		var local = minf(amount * weights[corner], maxf(0, original[i] + 0.018 * strength - heights[i]))
		heights[i] += local
		deposited += local
	return deposited
