class_name OldWorldGenerator
extends RefCounted

const HydraulicErosion = preload("res://scripts/map_editor/hydraulic_erosion.gd")
## Adapted from Azgaar's MIT-licensed heightmap template and operations.
## Uses a six-neighbour staggered raster instead of Azgaar's Voronoi graph.

const RECIPE = [
	["Range", "3", "70", "15-85", "20-80"],
	["Hill", "2-3", "50-70", "15-45", "20-80"],
	["Hill", "2-3", "50-70", "65-85", "20-80"],
	["Hill", "4-6", "20-25", "15-85", "20-80"],
	["Multiply", "0.5", "land", "0", "0"],
	["Smooth", "2", "0", "0", "0"],
	["Range", "3-4", "20-50", "15-35", "20-45"],
	["Range", "2-4", "20-50", "65-85", "45-80"],
	["Strait", "3-7", "vertical", "0", "0"],
	["Trough", "6-8", "20-50", "15-85", "45-65"],
	["Pit", "5-6", "20-30", "10-90", "10-90"],
]
var rng = RandomNumberGenerator.new()
var heights = PackedFloat32Array()
var neighbours: Array[PackedInt32Array] = []
var columns: int
var rows: int

func generate(width: int, length: int, map_seed: int, detail_strength: float = 1.0, erosion_strength: float = 1.0, relief_profile: int = 0) -> Image:
	assert(width >= 64 and width <= 4096 and length >= 64 and length <= 4096)
	rng.seed = map_seed
	# Approximately 10k simulation cells, independent of output resolution.
	columns = maxi(16, roundi(sqrt(10000.0 * width / length)))
	rows = maxi(16, roundi(10000.0 / columns))
	heights.resize(columns * rows)
	heights.fill(0.0)
	neighbours.clear()
	for y in rows:
		for x in columns:
			var adjacent = PackedInt32Array()
			var diagonal = 1 if y % 2 else -1
			for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(diagonal, -1), Vector2i(diagonal, 1)]:
				var p = Vector2i(x, y) + offset
				if p.x >= 0 and p.x < columns and p.y >= 0 and p.y < rows:
					adjacent.append(p.x + p.y * columns)
			neighbours.append(adjacent)
	for step in RECIPE:
		match step[0]:
			"Multiply":
				for i in heights.size():
					if heights[i] >= 20: heights[i] = floor((heights[i] - 20) * 0.5 + 20)
			"Smooth": _smooth()
			"Strait": _strait(_number(step[1]))
			_:
				for count in int(_number(step[1])):
					var h = _number(step[2])
					var start = _start(step[3], step[4])
					for attempt in 50:
						if step[0] == "Range": break
						if step[0] == "Hill" and heights[start] + h <= 90: break
						if step[0] != "Hill" and heights[start] >= 20: break
						start = _start(step[3], step[4])
					if step[0] in ["Range", "Trough"]:
						_line(start, h, step[0] == "Trough")
					else:
						_blob(start, h, step[0] == "Pit")
	var image = Image.create_empty(columns, rows, false, Image.FORMAT_RF)
	for y in rows:
		for x in columns:
			image.set_pixel(x, y, Color(heights[x + y * columns] / 100.0, 0, 0))
	# Cubic reconstruction plus domain-warped, multi-scale ridges adds real geometry
	# between the original recipe cells. Coordinates stay stable across resolutions.
	image = _reconstruct_macro(image)
	image.resize(width, length, Image.INTERPOLATE_CUBIC)
	return HydraulicErosion.erode(_refine(image, map_seed, detail_strength, relief_profile), map_seed, erosion_strength)

func _number(value: String) -> float:
	var parts = value.split("-")
	return rng.randi_range(int(parts[0]), int(parts[1])) if parts.size() == 2 else float(value)

func _start(x_range: String, y_range: String) -> int:
	var x = clampi(int(_number(x_range) * 0.01 * (columns - 1)), 0, columns - 1)
	var y = clampi(int(_number(y_range) * 0.01 * (rows - 1)), 0, rows - 1)
	return x + y * columns

func _position(index: int) -> Vector2:
	return Vector2(float(index % columns) / columns, float(index / columns) / rows)

func _path(start: int, end: int, used: PackedByteArray) -> PackedInt32Array:
	var path = PackedInt32Array([start])
	var current = start
	used[current] = 1
	for guard in heights.size():
		if current == end: break
		var best = -1
		var distance = INF
		for next in neighbours[current]:
			if used[next]: continue
			var d = _position(next).distance_squared_to(_position(end))
			if rng.randf() > 0.8: d *= 0.5
			if d < distance:
				distance = d
				best = next
		if best < 0: break
		current = best
		used[current] = 1
		path.append(current)
	return path

func _blob(start: int, h: float, pit: bool) -> void:
	var change = PackedFloat32Array()
	change.resize(heights.size())
	var used = PackedByteArray()
	used.resize(heights.size())
	var queue = PackedInt32Array([start])
	change[start] = h
	used[start] = 1
	var head = 0
	while head < queue.size():
		var current = queue[head]
		head += 1
		if pit:
			h = pow(h, 0.98) * rng.randf_range(0.9, 1.1)
			if h < 1: break
		for next in neighbours[current]:
			if used[next]: continue
			used[next] = 1
			if pit:
				heights[next] = floor(clampf(heights[next] - h * rng.randf_range(0.9, 1.1), 0, 100))
				queue.append(next)
			else:
				change[next] = floor(pow(change[current], 0.98) * rng.randf_range(0.9, 1.1))
				if change[next] > 1: queue.append(next)
	if not pit:
		for i in heights.size(): heights[i] = clampf(heights[i] + change[i], 0, 100)

func _line(start: int, h: float, trough: bool) -> void:
	var end = start
	for attempt in 50:
		end = _start("10-90", "15-85")
		var delta = (_position(end) - _position(start)).abs()
		var distance = delta.x + delta.y * float(rows) / columns
		if distance >= 0.125 and distance <= (0.5 if trough else 0.333): break
	var used = PackedByteArray()
	used.resize(heights.size())
	var ridge = _path(start, end, used)
	var frontier = ridge
	var layers = 0
	while not frontier.is_empty():
		layers += 1
		for cell in frontier:
			heights[cell] = floor(clampf(heights[cell] + h * (-1 if trough else 1) * rng.randf_range(0.85, 1.15), 0, 100))
		h = pow(h, 0.81) - 1
		if h < 2: break
		var next_frontier = PackedInt32Array()
		for cell in frontier:
			for next in neighbours[cell]:
				if not used[next]:
					used[next] = 1
					next_frontier.append(next)
		frontier = next_frontier
	for i in range(0, ridge.size(), 6):
		var current = ridge[i]
		for layer in layers:
			var lowest = neighbours[current][0]
			for next in neighbours[current]:
				if heights[next] < heights[lowest]: lowest = next
			heights[lowest] = floor((heights[current] * 2 + heights[lowest]) / 3)
			current = lowest

func _strait(width: float) -> void:
	var start = _start("30-70", "0")
	var end_x = clampi(columns - start % columns + rng.randi_range(-columns / 10, columns / 10), 0, columns - 1)
	var used = PackedByteArray()
	used.resize(heights.size())
	var frontier = _path(start, end_x + (rows - 1) * columns, used)
	used.fill(0)
	for layer in int(width):
		var next_frontier = PackedInt32Array()
		var exponent = 0.9 - 0.1 / width * (width - layer)
		for cell in frontier:
			for next in neighbours[cell]:
				if used[next]: continue
				used[next] = 1
				heights[next] = floor(pow(heights[next], exponent))
				next_frontier.append(next)
		frontier = next_frontier

func _smooth() -> void:
	var result = heights.duplicate()
	for i in heights.size():
		var total = heights[i]
		for next in neighbours[i]: total += heights[next]
		result[i] = floor((heights[i] + total / (neighbours[i].size() + 1)) / 2)
	heights = result

func _refine(base: Image, map_seed: int, strength: float, relief_profile: int = 0) -> Image:
	var ridges = FastNoiseLite.new()
	ridges.seed = map_seed + 411
	ridges.frequency = 0.012
	ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridges.fractal_octaves = 7
	ridges.fractal_gain = 0.55
	ridges.domain_warp_enabled = true
	ridges.domain_warp_amplitude = 38.0
	ridges.domain_warp_frequency = 0.009
	var spurs = FastNoiseLite.new()
	spurs.seed = map_seed + 19489
	spurs.frequency = 0.045
	spurs.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	spurs.fractal_octaves = 5
	spurs.domain_warp_enabled = true
	spurs.domain_warp_amplitude = 9.0
	spurs.domain_warp_frequency = 0.02
	var fine = FastNoiseLite.new()
	fine.seed = map_seed + 7919
	fine.frequency = 0.11
	fine.fractal_octaves = 3
	var warp = FastNoiseLite.new()
	warp.seed = map_seed + 173
	warp.frequency = 0.035
	warp.fractal_octaves = 3
	var result = Image.create_empty(base.get_width(), base.get_height(), false, Image.FORMAT_RF)
	var sample_scale = 1024.0 / maxf(base.get_width(), base.get_height())
	for y in base.get_height():
		for x in base.get_width():
			var px = x * sample_scale
			var py = y * sample_scale
			var wx = warp.get_noise_2d(px, py)
			var wy = warp.get_noise_2d(px + 537.0, py - 321.0)
			var sx = clampf(x + wx * 3.5 * strength / sample_scale, 0, base.get_width() - 1.001)
			var sy = clampf(y + wy * 3.5 * strength / sample_scale, 0, base.get_height() - 1.001)
			var ix = int(sx)
			var iy = int(sy)
			var a = lerpf(base.get_pixel(ix, iy).r, base.get_pixel(ix + 1, iy).r, sx - ix)
			var b = lerpf(base.get_pixel(ix, iy + 1).r, base.get_pixel(ix + 1, iy + 1).r, sx - ix)
			var h = clampf(lerpf(a, b, sy - iy), 0, 1)
			# Accepted reference variants: preserve the rugged relief, or soften it.
			if relief_profile == 1 and h > 0.2: h = 0.2 + (h - 0.2) * 0.72
			var mountain_mask = smoothstep(0.25, 0.65, h)
			var land_mask = smoothstep(0.19, 0.27, h)
			var ridge = ridges.get_noise_2d(px, py)
			var grain = fine.get_noise_2d(px, py)
			# Rebuild upland relief at output resolution, rather than merely adding
			# tiny bumps to the enlarged continental hills.
			var massif = pow(clampf(ridge * 0.5 + 0.5, 0, 1), 1.7)
			var spur = spurs.get_noise_2d(px, py) * 0.5 + 0.5
			var upland = smoothstep(0.25, 0.52, h)
			h += upland * ((massif * (0.55 + spur * 0.45) - 0.25) * 0.34) * strength
			# Broad plains, incised ridges, and much finer foothill relief.
			h += (ridge * (0.008 + mountain_mask * 0.065) * land_mask + grain * (0.002 + mountain_mask * 0.009) + wx * 0.003) * strength
			if h > 0.2: h = 0.2 + pow((h - 0.2) / 0.8, 1.22) * 0.8
			result.set_pixel(x, y, Color(clampf(h, 0, 1), 0, 0))
	return _erode(result, strength)

func _erode(image: Image, strength: float) -> Image:
	# Conservative thermal weathering: steep faces shed a little material
	# downhill. Restrict to uplands so coastlines and lowland channels stay stable.
	if strength <= 0.0: return image
	var width = image.get_width()
	var length = image.get_height()
	var values = image.get_data().to_float32_array()
	var talus = 0.006 * 1024.0 / maxf(width, length)
	for iteration in 6:
		var delta = PackedFloat32Array()
		delta.resize(values.size())
		for y in range(1, length - 1):
			for x in range(1, width - 1):
				var i = x + y * width
				if values[i] < 0.26: continue
				var lowest = i
				for next in [i - 1, i + 1, i - width, i + width]:
					if values[next] < values[lowest]: lowest = next
				var slope = values[i] - values[lowest]
				if slope <= talus: continue
				var transfer = (slope - talus) * 0.12 * clampf(strength, 0.0, 2.0) * smoothstep(0.26, 0.45, values[i])
				delta[i] -= transfer
				delta[lowest] += transfer
		for i in values.size(): values[i] += delta[i]
	return Image.create_from_data(width, length, false, Image.FORMAT_RF, values.to_byte_array())

func _reconstruct_macro(image: Image) -> Image:
	# The continental recipe has abrupt cell-to-cell ridge falloff. Reconstruct
	# broad landforms before adding high-resolution geology, instead of retaining
	# those coarse walls as narrow, near-vertical fins.
	var width = image.get_width()
	var length = image.get_height()
	var data = image.get_data().to_float32_array()
	var kernel = PackedFloat32Array([0.0625, 0.25, 0.375, 0.25, 0.0625])
	for pass_index in 2:
		for axis in 2:
			var result = PackedFloat32Array()
			result.resize(data.size())
			for y in length:
				for x in width:
					var total = 0.0
					for tap in 5:
						var sx = clampi(x + (tap - 2 if axis == 0 else 0), 0, width - 1)
						var sy = clampi(y + (tap - 2 if axis == 1 else 0), 0, length - 1)
						total += data[sx + sy * width] * kernel[tap]
					result[x + y * width] = total
			data = result
	return Image.create_from_data(width, length, false, Image.FORMAT_RF, data.to_byte_array())
