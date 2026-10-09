extends Control

signal cell_clicked(cell: Vector2i)
signal swiped(direction: int)
var engine: PuzzleEngine
var cursor := Vector2i(7, 6)
var selected_id := -1
var symbols: Texture2D = preload("res://data/nes_symbols.png")
var origin := Vector2.ZERO
var cell_size := 44.0
var pointer_start := Vector2.ZERO
var pointer_down := false
var elapsed := 0.0
const COLORS := [Color("85efbf"), Color("dadfe2"), Color("61b8f6"), Color("f28d99"), Color("d7dbdf"), Color("f79db7"), Color("80e0d8"), Color("7fb5f5")]

func _ready() -> void:
	custom_minimum_size = Vector2(440, 440)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func tile_rect(position: Vector2) -> Rect2:
	return Rect2(origin + position / 16.0 * cell_size, Vector2.ONE * cell_size)

func _draw() -> void:
	cell_size = minf((size.x - 48) / 10.0, (size.y - 32) / 12.0)
	origin = (size - Vector2(10, 12) * cell_size) / 2.0
	if engine == null:
		return
	for y in range(12):
		for x in range(10):
			var kind := int(engine.grid[y][x])
			var rect := tile_rect(Vector2(x, y) * 16)
			if kind == 3:
				draw_rect(rect.grow(-1), Color("181e20"))
				var inset := rect.grow(-8)
				draw_line(inset.position, Vector2(inset.end.x, inset.position.y), Color("242d2e"), 1)
			elif kind != 0:
				draw_rect(rect.grow(-1), Color("465251"))
				draw_rect(rect.grow(-5), Color("303c3b"))
				draw_line(rect.position + Vector2(5, 5), rect.position + Vector2(cell_size - 5, 5), Color("697873"), 2)
				draw_line(rect.position + Vector2(5, 5), rect.position + Vector2(5, cell_size - 5), Color("53645f"), 1)
			else:
				draw_rect(rect.grow(-1), Color("0d1113"))
				draw_circle(rect.get_center(), 1.1, Color("26302f"))
	for platform in engine.platforms:
		var rect := tile_rect(platform.pos).grow(-2)
		draw_rect(rect, Color("eac174"))
		draw_rect(rect.grow(-4), Color("554936"))
		var center := rect.get_center()
		var axis: Vector2 = Vector2.DOWN if platform.kind == 4 else Vector2.RIGHT
		for sign_value in [-1, 1]:
			var tip: Vector2 = center + axis * 10 * sign_value
			var tail: Vector2 = center + axis * 4 * sign_value
			var side := Vector2(-axis.y, axis.x) * 4
			draw_line(tail + side, tip, Color("eac174"), 2, true)
			draw_line(tail - side, tip, Color("eac174"), 2, true)
	for block in engine.blocks:
		var rect := tile_rect(block.pos).grow(-3)
		var color: Color = COLORS[int(block.kind) - 8]
		draw_rect(Rect2(rect.position + Vector2(0, 3), rect.size), Color(0, 0, 0, 0.5))
		draw_rect(rect, Color("253030"))
		draw_rect(rect.grow(-1), Color("182122"))
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), color.darkened(0.4), 2)
		draw_texture_rect_region(symbols, rect.grow(-5), Rect2((int(block.kind) - 8) * 16, 0, 16, 16))
		if block.id == selected_id:
			draw_rect(rect.grow(3), Color("85efbf"), false, 2)
	if engine.clear_frames > 0:
		var progress := 1.0 - engine.clear_frames / 28.0
		for block in engine.cleared:
			var center := tile_rect(block.pos).get_center()
			var color: Color = COLORS[int(block.kind) - 8]
			color.a = 1.0 - progress
			for i in range(8):
				var offset := Vector2.from_angle(i * TAU / 8.0) * (8 + progress * cell_size)
				draw_rect(Rect2(center + offset - Vector2.ONE * 2, Vector2.ONE * 4), color)
	var cursor_rect := tile_rect(Vector2(cursor) * 16).grow(-1)
	var color := Color("85efbf") if selected_id >= 0 else Color("f0f5ef")
	color.a = 0.8 + sin(elapsed * 4) * 0.2
	for corner in [cursor_rect.position, Vector2(cursor_rect.end.x, cursor_rect.position.y), cursor_rect.end, Vector2(cursor_rect.position.x, cursor_rect.end.y)]:
		var horizontal := -1 if corner.x > cursor_rect.get_center().x else 1
		var vertical := -1 if corner.y > cursor_rect.get_center().y else 1
		draw_line(corner, corner + Vector2(horizontal * 9, 0), color, 2, true)
		draw_line(corner, corner + Vector2(0, vertical * 9), color, 2, true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pointer_start = event.position
			pointer_down = true
			var cell := Vector2i(floor((event.position.x - origin.x) / cell_size), floor((event.position.y - origin.y) / cell_size))
			if cell.x >= 0 and cell.x < 10 and cell.y >= 0 and cell.y < 12:
				cell_clicked.emit(cell)
		else:
			pointer_down = false
	if event is InputEventMouseMotion and pointer_down:
		var distance: float = event.position.x - pointer_start.x
		if abs(distance) > cell_size * 0.65:
			swiped.emit(1 if distance > 0 else -1)
			pointer_start = event.position
