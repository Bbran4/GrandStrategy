extends Control
signal node_selected(id: String)
var progression
var tree = "technology"
var selected = ""
var positions = {}

func display(model, kind: String, selected_id: String) -> void:
	progression = model
	tree = kind
	selected = selected_id
	for child in get_children(): remove_child(child); child.queue_free()
	positions.clear()
	custom_minimum_size = Vector2(990,430)
	for id in model.nodes:
		var node: Dictionary = model.nodes[id]
		if node.tree != tree: continue
		if node.row == 0:
			var heading = Label.new()
			heading.position = Vector2(14 + node.column * 194,5)
			heading.size.x = 178
			heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			heading.text = str(node.branch).capitalize()
			add_child(heading)
		var button = Button.new()
		button.position = Vector2(14 + node.column * 194,36 + node.row * 128)
		button.size = Vector2(178,84)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var state = "UNLOCKED" if id in model.unlocked else "AVAILABLE" if model.blocked_reason(id).is_empty() else "LOCKED"
		button.text = node.name + "\n" + str(int(node.cost)) + (" research" if tree == "technology" else " skill points") + " / " + state
		button.tooltip_text = node.description + "\n" + model.blocked_reason(id)
		button.modulate = Color("89c6a0") if id in model.unlocked else Color("e9cf91") if state == "AVAILABLE" else Color("9da6b4")
		button.toggle_mode = true
		button.button_pressed = id == selected
		button.pressed.connect(func(): node_selected.emit(id))
		add_child(button)
		positions[id] = button.position + button.size * 0.5
	queue_redraw()

func _draw() -> void:
	if progression == null: return
	for id in positions:
		for parent in progression.nodes[id].requires:
			if not positions.has(parent): continue
			var start = positions[parent] + Vector2(0,42)
			var end = positions[id] - Vector2(0,42)
			if tree == "national" and progression.nodes[id].row == 2:
				# Route the alternative's connection beside the intervening card.
				var rail = start.x + 94
				draw_polyline(PackedVector2Array([start,Vector2(rail,start.y),Vector2(rail,end.y-12),Vector2(end.x,end.y-12),end]),Color("7892a0"),2,true)
			else: draw_line(start,end,Color("7892a0"),2,true)
			draw_line(end,end+Vector2(-5,-8),Color("7892a0"),2,true)
			draw_line(end,end+Vector2(5,-8),Color("7892a0"),2,true)
