extends SceneTree

var failures := 0
var game: Control

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func _initialize() -> void:
	call_deferred("run")

func frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame

func screenshot(name: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/" + name + ".png")

func check_bounds(node: Node) -> void:
	if node is Control and node.is_visible_in_tree() and not node is Label:
		var rect: Rect2 = node.get_global_rect()
		check(rect.end.y <= game.size.y + 2, "Control fits vertically: " + str(node.name))
		check(rect.end.x <= game.size.x + 2, "Control fits horizontally: " + str(node.name))
	for child in node.get_children():
		check_bounds(child)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	AudioServer.set_bus_mute(0, true)
	game._load_level(0)
	check(game.engine.remaining() == 14, "First NES level has 14 blocks")
	check(game.password_label.text == "VVVV", "Original password visible")
	game.paused = true
	await screenshot("godot-desktop")
	check_bounds(game)
	game._show_levels()
	await screenshot("godot-levels")
	check_bounds(game)
	game._show_password()
	await frames()
	var entry: LineEdit = game.modal_body.get_child(2)
	entry.text = "VPP3"
	var submit: Button = game.modal_body.get_child(4)
	submit.pressed.emit()
	check(game.level_index == 1, "Original NES password opens correct level")
	check(not game.paused, "Password resumes gameplay")
	game._show_pause()
	var frozen: float = game.seconds
	await frames(10)
	check(game.seconds == frozen, "Pause freezes timer")
	game._load_level(0)
	game._click_cell(Vector2i(7, 6))
	check(game.mouse_selected == 67, "Mouse selects original first block")
	game._move_selected(-1)
	check(game.engine.moves == 1, "Mouse/touch movement enters engine")
	game._confirm_retry()
	var retry: Button = game.modal_body.get_child(2)
	retry.pressed.emit()
	check(game.retries == 1 and game.engine.moves == 0, "Retry resets board and consumes retry")
	game.mode = 1
	game._load_level(0)
	check(game.engine.remaining() > 0, "Gravnic imported and playable")
	game._touch_direction(Vector2i.LEFT)
	check(game.engine.moves == 1, "Gravnic directional controls")
	await screenshot("godot-gravnic")
	game.mode = 0
	game._load_level(14)
	game.paused = true
	await screenshot("godot-platforms")
	root.size = Vector2i(800, 600)
	await frames(5)
	game._load_level(0)
	game.paused = true
	await screenshot("godot-small-window")
	check_bounds(game)
	game.queue_free()
	await frames()
	print("Native UI checks: passwords, level selector, mouse input, pause, retries, Gravnic, and window sizes. Failures: ", failures)
	quit(1 if failures else 0)
