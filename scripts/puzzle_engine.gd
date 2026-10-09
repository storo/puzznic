class_name PuzzleEngine
extends RefCounted

const CELL := 16
const SIZE := Vector2(16, 16)
const DIRECTIONS := [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
const MATCH_POINTS := [
	[100, 200, 400, 600, 1000, 1200, 2000, 2000],
	[600, 1000, 1000, 1200, 2000, 2000, 2000, 2000],
	[1000, 1200, 2000, 2000, 2000, 2000, 2000, 2000],
]
var grid: Array = []
var blocks: Array[Dictionary] = []
var platforms: Array[Dictionary] = []
var mode := 0
var points := 0
var moves := 0
var clear_frames := 0
var cleared: Array[Dictionary] = []
var chain := 0
var tilt := Vector2.ZERO
var won := false
var changed := false

func load_level(level: Dictionary) -> void:
	grid = level.grid.duplicate(true)
	mode = int(level.mode)
	blocks.clear()
	platforms.clear()
	points = 0
	moves = 0
	clear_frames = 0
	cleared.clear()
	chain = 0
	tilt = Vector2.ZERO
	won = false
	for y in range(12):
		for x in range(10):
			var kind := int(grid[y][x])
			var pos := Vector2(x, y) * CELL
			if kind >= 8:
				blocks.append({"id": y * 10 + x, "kind": kind, "pos": pos, "target": pos, "moving": false, "falling": false})
				grid[y][x] = 0
			elif kind == 4 or kind == 5:
				platforms.append({"pos": pos, "kind": kind, "dir": Vector2.DOWN if kind == 4 else Vector2.RIGHT})
				grid[y][x] = 0
	changed = true

func rect_at(pos: Vector2) -> Rect2:
	return Rect2(pos + Vector2(0.01, 0.01), SIZE - Vector2(0.02, 0.02))

func hits_wall(pos: Vector2) -> bool:
	var rect := rect_at(pos)
	if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > 160 or rect.end.y > 192:
		return true
	for y in range(int(floor(rect.position.y / CELL)), int(floor(rect.end.y / CELL)) + 1):
		for x in range(int(floor(rect.position.x / CELL)), int(floor(rect.end.x / CELL)) + 1):
			if int(grid[y][x]) != 0:
				return true
	return false

func blocked(pos: Vector2, ignore_id: int = -1, ignore_platform: int = -1) -> bool:
	if hits_wall(pos):
		return true
	var rect := rect_at(pos)
	for block in blocks:
		if block.id != ignore_id and rect.intersects(rect_at(block.pos)):
			return true
	for i in range(platforms.size()):
		if i != ignore_platform and rect.intersects(rect_at(platforms[i].pos)):
			return true
	return false

func block_at(cell: Vector2i) -> Dictionary:
	var center := Vector2(cell) * CELL + SIZE / 2
	for block in blocks:
		if Rect2(block.pos, SIZE).has_point(center):
			return block
	return {}

func block_by_id(id: int) -> Dictionary:
	for block in blocks:
		if block.id == id:
			return block
	return {}

func move_block(id: int, direction: int) -> bool:
	if mode != 0 or clear_frames > 0 or won or abs(direction) != 1:
		return false
	var block := block_by_id(id)
	if block.is_empty() or block.moving or block.falling:
		return false
	if not is_equal_approx(fmod(block.pos.x, CELL), 0):
		return false
	var target: Vector2 = block.pos + Vector2(direction * CELL, 0)
	if blocked(target, id):
		return false
	block.target = target
	block.moving = true
	moves += 1
	chain = 0
	return true

func begin_tilt(direction: Vector2) -> bool:
	if mode != 1 or clear_frames > 0 or won or tilt != Vector2.ZERO:
		return false
	tilt = direction
	moves += 1
	chain = 0
	return true

func advance_platforms() -> void:
	for index in range(platforms.size()):
		var platform := platforms[index]
		var delta: Vector2 = platform.dir
		var riders: Array[int] = []
		var supports: Array[Vector2] = [platform.pos]
		# Follow the whole stack so elevators carry every supported block.
		var found := true
		while found:
			found = false
			for block in blocks:
				if block.id in riders or block.moving:
					continue
				for support in supports:
					if is_equal_approx(block.pos.y + CELL, support.y) and abs(block.pos.x - support.x) < CELL - 0.01:
						riders.append(block.id)
						supports.append(block.pos)
						found = true
						break
		var collision := hits_wall(platform.pos + delta)
		var riders_blocked := false
		for block in blocks:
			if block.id in riders:
				if hits_wall(block.pos + delta):
					riders_blocked = true
				for other in blocks:
					if other.id not in riders and rect_at(block.pos + delta).intersects(rect_at(other.pos)):
						riders_blocked = true
			elif rect_at(platform.pos + delta).intersects(rect_at(block.pos)):
				collision = true
		if collision or (riders_blocked and platform.kind == 4):
			platform.dir = -platform.dir
			continue
		platform.pos += delta
		for block in blocks:
			if block.id in riders and not riders_blocked:
				block.pos += delta
				block.target = block.pos
				block.falling = false

func step() -> void:
	changed = false
	if won:
		return
	if clear_frames > 0:
		clear_frames -= 1
		changed = true
		if clear_frames == 0:
			cleared.clear()
			won = remaining() == 0
		return
	if mode == 0:
		advance_platforms()
		for block in blocks:
			if block.moving:
				block.pos = block.target
				if block.pos == block.target:
					block.moving = false
		var order := blocks.duplicate()
		order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.y > b.pos.y)
		for block in order:
			block.falling = false
			if block.moving:
				continue
			for pixel in range(2):
				if not blocked(block.pos + Vector2.DOWN, block.id):
					block.pos.y += 1
					block.target = block.pos
					block.falling = true
	else:
		if tilt != Vector2.ZERO:
			var order := blocks.duplicate()
			order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.dot(tilt) > b.pos.dot(tilt))
			var moved := false
			for block in order:
				if block.kind >= 12:
					continue
				for pixel in range(2):
					if not blocked(block.pos + tilt, block.id):
						block.pos += tilt
						block.target = block.pos
						moved = true
			if not moved:
				tilt = Vector2.ZERO
	var settling := tilt != Vector2.ZERO
	for block in blocks:
		if block.moving or block.falling:
			settling = true
	if not settling:
		check_matches()
	changed = true

func check_matches() -> void:
	var matched: Array[int] = []
	var groups: Array[int] = []
	var seen: Array[int] = []
	for block in blocks:
		if block.id in seen or (mode == 1 and block.kind >= 12):
			continue
		var group: Array[Dictionary] = [block]
		seen.append(block.id)
		var index := 0
		while index < group.size():
			var current := group[index]
			for other in blocks:
				if other.id in seen or other.kind != current.kind:
					continue
				var offset: Vector2 = other.pos - current.pos
				var touching := (is_equal_approx(abs(offset.x), CELL) and is_equal_approx(offset.y, 0)) or (is_equal_approx(abs(offset.y), CELL) and is_equal_approx(offset.x, 0))
				if touching:
					seen.append(other.id)
					group.append(other)
			index += 1
		if group.size() >= 2:
			groups.append(group.size())
			for item in group:
				matched.append(item.id)
	if matched.is_empty():
		return
	var score_index := mini(matched.size() - 2, 6)
	points += 2000 if chain >= 3 else MATCH_POINTS[chain][score_index]
	chain += 1
	cleared.clear()
	for block in blocks:
		if block.id in matched:
			cleared.append(block.duplicate())
	blocks = blocks.filter(func(block: Dictionary) -> bool: return block.id not in matched)
	clear_frames = 28

func remaining() -> int:
	var count := 0
	for block in blocks:
		if mode == 0 or block.kind < 12:
			count += 1
	return count
