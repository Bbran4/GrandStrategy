class_name OldWorldGenerator
extends RefCounted
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

func generate(width: int, length: int, map_seed: int) -> Image:
	assert(width >= 64 and width <= 2048 and length >= 64 and length <= 2048)
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
	image.resize(width, length, Image.INTERPOLATE_BILINEAR)
	return image

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
