extends SceneTree

var failures := 0

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func make_level(rows: Array) -> Dictionary:
	var grid: Array = []
	for y in range(12):
		var row: Array = []
		for x in range(10):
			row.append(6 if x == 0 or x == 9 or y == 0 or y == 11 else 0)
		grid.append(row)
	for row in rows:
		grid[row[1]][row[0]] = row[2]
	return {"mode": 0, "grid": grid}

func _initialize() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	var levels: Array = parsed.levels
	check(levels.size() == 240, "All original levels imported")
	check(levels[0].password == "VVVV", "NES password 1-1")
	check(levels[1].password == "VPP3", "NES password 1-2")
	check(levels[10].time == 60, "NES timer")
	var engine := PuzzleEngine.new()
	for level in levels:
		engine.load_level(level)
		check(engine.remaining() >= 2, "Playable blocks in " + str(level.name))
		for block in engine.blocks:
			check(not engine.hits_wall(block.pos), "Block starts inside chamber")
		for i in range(60): engine.step()
		for block in engine.blocks:
			check(not engine.hits_wall(block.pos), "No wall penetration after settling " + str(level.name))
	engine.load_level(make_level([[2, 10, 8], [4, 10, 8]]))
	check(engine.move_block(102, 1), "Horizontal move allowed")
	for i in range(50): engine.step()
	check(engine.won, "Pair eliminates and completes level")
	check(engine.points == 100, "Pair scoring")
	engine.load_level(make_level([[2, 10, 8], [3, 10, 8], [4, 9, 8]]))
	for i in range(70): engine.step()
	check(engine.won, "Gravity resolves before matching: all three disappear")
	check(engine.points == 200, "Triple scoring")
	engine.load_level(make_level([[2, 10, 8], [3, 10, 8], [6, 10, 9], [7, 10, 9]]))
	for i in range(50): engine.step()
	check(engine.won, "Simultaneous distinct groups clear")
	check(engine.points == 400, "Original NES four-block scoring table")
	engine.load_level(make_level([[1, 10, 8], [8, 10, 8]]))
	check(not engine.move_block(101, -1), "Walls block movement")
	check(not engine.move_block(101, 0), "No vertical player moves")
	engine.load_level(make_level([[3, 8, 4], [3, 7, 8], [3, 6, 9], [7, 10, 8], [8, 10, 9]]))
	engine.platforms[0].dir = Vector2.UP
	engine.step()
	check(engine.block_by_id(73).pos.y == 111, "Elevator carries bottom block")
	check(engine.block_by_id(63).pos.y == 95, "Elevator carries entire stack")
	for i in range(300): engine.step()
	for block in engine.blocks:
		check(not engine.hits_wall(block.pos), "Elevator reverses below ceiling")
	engine.load_level(make_level([[3, 8, 5], [3, 7, 8], [4, 7, 6], [8, 10, 8]]))
	engine.step()
	check(engine.platforms[0].pos.x == 49, "Horizontal platform keeps moving under ledge")
	check(engine.block_by_id(73).pos.x == 48, "Ledge detaches the carried block")
	for i in range(32): engine.step()
	check(engine.block_by_id(73).pos.y > 112, "Detached block drops as platform moves away")
	# The first NES puzzle's documented seven-pair solution.
	engine.load_level(levels[0])
	for kind in [8, 9, 10, 11, 13, 14, 12]:
		for attempt in range(8):
			var candidates := engine.blocks.filter(func(block: Dictionary) -> bool: return block.kind == kind)
			if candidates.is_empty(): break
			candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.y < b.pos.y)
			var block: Dictionary = candidates[0]
			check(engine.move_block(block.id, -1), "NES 1-1 solution move")
			for i in range(80): engine.step()
	check(engine.won, "Original NES 1-1 solution completes")
	print("Engine checks complete: 240 imported levels, gravity, groups, walls, elevator stacks, and NES 1-1. Failures: ", failures)
	quit(1 if failures else 0)
