extends Control

const Board = preload("res://scripts/board.gd")
const BG := Color("101416")
const INK := Color("edf3ec")
const MUTED := Color("86928d")
const MINT := Color("85efbf")
var engine := PuzzleEngine.new()
var levels: Array = []
var level_index := 0
var mode := 0
var score := 0
var base_score := 0
var retries := 2
var seconds := 60.0
var board: Control
var stage_label: Label
var score_label: Label
var time_label: Label
var retry_label: Label
var moves_label: Label
var password_label: Label
var remaining_box: GridContainer
var modal: PanelContainer
var modal_body: VBoxContainer
var overlay: ColorRect
var paused := false
var result_shown := false
var mouse_selected := -1
var key_grabbing := false
var cursor := Vector2i(7, 6)
var input_cooldown := 0.0
var press_time := 0.0
var last_clear := 0
var muted := false
var completed: Dictionary = {}
var music: AudioStreamPlayer
var sound: AudioStreamPlayer
var level_world := 0
var font: Font = ThemeDB.fallback_font

func _ready() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	levels = parsed.levels
	_load_progress()
	_make_theme()
	_build_ui()
	_load_level(level_index)
	if ResourceLoader.exists("res://data/nes_music.wav"):
		music = AudioStreamPlayer.new()
		music.stream = load("res://data/nes_music.wav")
		music.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		music.volume_db = -16
		add_child(music)
		music.play()
	sound = AudioStreamPlayer.new()
	sound.volume_db = -20
	add_child(sound)
	get_tree().auto_accept_quit = true
	get_window().min_size = Vector2i(800, 560)
	if "--capture" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		await get_tree().process_frame
		var capture_path := "res://artifacts/godot-desktop.png" if OS.has_feature("editor") else "user://preview.png"
		get_viewport().get_texture().get_image().save_png(capture_path)
		get_tree().quit()

func _make_theme() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 18
	ui_theme.set_color("font_color", "Label", INK)
	ui_theme.set_color("font_color", "Button", INK)
	ui_theme.set_color("font_hover_color", "Button", MINT)
	ui_theme.set_color("font_pressed_color", "Button", MINT)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("1c2426") if state == "normal" else Color("303e3b")
		style.set_border_width_all(1)
		style.border_color = Color("394643") if state != "focus" else MINT
		style.set_corner_radius_all(5)
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		ui_theme.set_stylebox(state, "Button", style)
	theme = ui_theme

func _label(text: String, text_size: int = 18, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", text_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, tip: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	return button

func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer

func _divider() -> HSeparator:
	var line := HSeparator.new()
	line.modulate = Color("3b4844")
	return line

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	root.add_child(top)
	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 0)
	top.add_child(brand)
	brand.add_child(_label("PUZZNIC", 38))
	brand.add_child(_label("NINTENDO ENTERTAINMENT SYSTEM", 11, MINT))
	top.add_child(_spacer())
	top.add_child(_button("Niveles", "Seleccionar nivel", _show_levels))
	top.add_child(_button("◧", "Pantalla completa · F11", _fullscreen))
	top.add_child(_button("♪", "Activar o silenciar audio", _toggle_audio))
	top.add_child(_button("?", "Controles", _show_help))
	root.add_child(_divider())
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 36)
	root.add_child(content)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 245
	sidebar.add_theme_constant_override("separation", 8)
	content.add_child(sidebar)
	sidebar.add_child(_label("NIVEL", 12, MUTED))
	stage_label = _label("1-1", 46)
	sidebar.add_child(stage_label)
	sidebar.add_child(_divider())
	sidebar.add_child(_label("TIEMPO", 12, MUTED))
	time_label = _label("01:00", 36, MINT)
	sidebar.add_child(time_label)
	sidebar.add_child(_label("PUNTUACIÓN", 12, MUTED))
	score_label = _label("000000", 30)
	sidebar.add_child(score_label)
	var retry_row := HBoxContainer.new()
	retry_row.add_child(_label("REINTENTOS", 12, MUTED))
	retry_row.add_child(_spacer())
	retry_label = _label("2", 20)
	retry_row.add_child(retry_label)
	sidebar.add_child(retry_row)
	sidebar.add_child(_divider())
	remaining_box = GridContainer.new()
	remaining_box.columns = 2
	remaining_box.add_theme_constant_override("h_separation", 30)
	remaining_box.add_theme_constant_override("v_separation", 12)
	sidebar.add_child(remaining_box)
	var vertical_space := Control.new()
	vertical_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(vertical_space)
	sidebar.add_child(_label("CONTRASEÑA", 12, MUTED))
	password_label = _label("VVVV", 20, MUTED)
	sidebar.add_child(password_label)
	board = Board.new()
	board.engine = engine
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.cell_clicked.connect(_click_cell)
	board.swiped.connect(_move_selected)
	content.add_child(board)
	root.add_child(_divider())
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)
	bottom.add_child(_button("Ⅱ", "Pausa · Esc / Enter", _show_pause))
	bottom.add_child(_button("↻", "Reintentar · R", _confirm_retry))
	bottom.add_child(_spacer())
	moves_label = _label("00 MOVIMIENTOS", 12, MUTED)
	bottom.add_child(moves_label)
	bottom.add_child(_spacer())
	for direction in [Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]:
		var glyph := "←" if direction == Vector2i.LEFT else "→" if direction == Vector2i.RIGHT else "↑" if direction == Vector2i.UP else "↓"
		var button := _button(glyph, "Mover", func(): _touch_direction(direction))
		button.custom_minimum_size = Vector2(56, 48)
		bottom.add_child(button)
	overlay = ColorRect.new()
	overlay.color = Color(0.02, 0.03, 0.04, 0.86)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	modal = PanelContainer.new()
	modal.custom_minimum_size = Vector2(580, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("192022")
	panel_style.border_color = Color("485b51")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	for side in ["left", "right", "top", "bottom"]:
		panel_style.set("content_margin_" + side, 32)
	modal.add_theme_stylebox_override("panel", panel_style)
	center.add_child(modal)
	modal_body = VBoxContainer.new()
	modal_body.add_theme_constant_override("separation", 18)
	modal.add_child(modal_body)

func _level() -> Dictionary:
	return levels[level_index + (160 if mode == 1 else 0)]

func _load_level(index: int) -> void:
	level_index = clampi(index, 0, 159 if mode == 0 else 79)
	engine.load_level(_level())
	seconds = float(_level().time)
	base_score = score
	result_shown = false
	mouse_selected = -1
	last_clear = 0
	if not engine.blocks.is_empty():
		cursor = Vector2i(engine.blocks[0].pos / 16)
	board.cursor = cursor
	board.selected_id = -1
	_close_modal()
	_update_hud()
	_save_progress()

func _physics_process(delta: float) -> void:
	if paused:
		return
	input_cooldown = maxf(0, input_cooldown - delta)
	_handle_held_input(delta)
	engine.step()
	if engine.clear_frames == 27 and last_clear == 0:
		_play_effect(640 + engine.chain * 120, 0.13)
	last_clear = engine.clear_frames
	if engine.clear_frames == 0 and not engine.won:
		seconds = maxf(0, seconds - delta)
	score = base_score + engine.points
	var active := engine.block_by_id(mouse_selected)
	if not active.is_empty():
		cursor = Vector2i((active.pos + Vector2(8, 8)) / 16)
	board.cursor = cursor
	board.selected_id = mouse_selected
	_update_hud()
	if engine.won and not result_shown:
		_complete_level()
	elif seconds <= 0 and not result_shown:
		result_shown = true
		_open_modal("TIEMPO AGOTADO", "Nivel " + str(_level().name))
		modal_body.add_child(_button("Volver a jugar", "Reiniciar el nivel", func(): score = 0; retries = 2; _load_level(level_index)))

func _update_hud() -> void:
	stage_label.text = str(_level().name)
	time_label.text = "%02d:%02d" % [int(ceil(seconds)) / 60, int(ceil(seconds)) % 60]
	time_label.add_theme_color_override("font_color", Color("f28d99") if seconds < 10 else Color("eac174") if seconds < 30 else MINT)
	score_label.text = "%06d" % score
	retry_label.text = str(retries)
	moves_label.text = "%02d MOVIMIENTOS" % engine.moves
	password_label.text = str(_level().password)
	var counts: Array[int] = []
	counts.resize(8)
	counts.fill(0)
	for block in engine.blocks:
		counts[int(block.kind) - 8] += 1
	var signature := str(counts)
	if remaining_box.get_meta("counts", "") == signature:
		return
	remaining_box.set_meta("counts", signature)
	for child in remaining_box.get_children():
		remaining_box.remove_child(child)
		child.queue_free()
	for i in range(8):
		if counts[i] == 0:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var icon := TextureRect.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = board.symbols
		atlas.region = Rect2(i * 16, 0, 16, 16)
		icon.texture = atlas
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		row.add_child(_label("× " + str(counts[i]), 17, MUTED))
		remaining_box.add_child(row)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F11:
		_fullscreen()
	elif event.keycode == KEY_ESCAPE or event.keycode == KEY_ENTER:
		if paused:
			_close_modal()
		elif event.keycode == KEY_ESCAPE or event.keycode == KEY_ENTER:
			_show_pause()
	elif not paused and event.keycode == KEY_R:
		_confirm_retry()
	elif not paused and event.keycode == KEY_Z:
		_grab_cursor()
		key_grabbing = true
	elif not paused and event.keycode in [KEY_X, KEY_SPACE, KEY_SHIFT]:
		_grab_cursor()
		key_grabbing = true

func _handle_held_input(delta: float) -> void:
	var direction := Vector2i.ZERO
	if Input.is_physical_key_pressed(KEY_LEFT): direction = Vector2i.LEFT
	elif Input.is_physical_key_pressed(KEY_RIGHT): direction = Vector2i.RIGHT
	elif Input.is_physical_key_pressed(KEY_UP): direction = Vector2i.UP
	elif Input.is_physical_key_pressed(KEY_DOWN): direction = Vector2i.DOWN
	if direction == Vector2i.ZERO:
		press_time = 0
		return
	press_time += delta
	if input_cooldown > 0:
		return
	input_cooldown = 0.18 if press_time > 0.25 else 0.25
	if mode == 1:
		engine.begin_tilt(Vector2(direction))
		return
	var grabbing := Input.is_physical_key_pressed(KEY_Z) or Input.is_physical_key_pressed(KEY_X) or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_SHIFT)
	if key_grabbing and not grabbing:
		mouse_selected = -1
		key_grabbing = false
	if grabbing:
		key_grabbing = true
		_grab_cursor()
		if direction.x != 0:
			_move_selected(direction.x)
	elif mouse_selected >= 0 and direction.x != 0:
		_move_selected(direction.x)
	else:
		mouse_selected = -1
		cursor += direction
		cursor.x = clampi(cursor.x, 0, 9)
		cursor.y = clampi(cursor.y, 0, 11)

func _grab_cursor() -> void:
	var block := engine.block_at(cursor)
	if not block.is_empty():
		mouse_selected = block.id

func _click_cell(cell: Vector2i) -> void:
	if paused:
		return
	cursor = cell
	key_grabbing = false
	var block := engine.block_at(cell)
	mouse_selected = int(block.id) if not block.is_empty() else -1

func _move_selected(direction: int) -> void:
	if paused:
		return
	if mouse_selected < 0:
		_grab_cursor()
	if engine.move_block(mouse_selected, direction):
		_play_effect(300, 0.035)

func _touch_direction(direction: Vector2i) -> void:
	if mode == 1:
		engine.begin_tilt(Vector2(direction))
	elif mouse_selected >= 0 and direction.x != 0:
		_move_selected(direction.x)
	else:
		cursor += direction
		cursor.x = clampi(cursor.x, 0, 9)
		cursor.y = clampi(cursor.y, 0, 11)

func _open_modal(title: String, subtitle: String = "") -> void:
	paused = true
	overlay.visible = true
	for child in modal_body.get_children():
		modal_body.remove_child(child)
		child.queue_free()
	modal_body.add_child(_label(title, 28, MINT))
	if not subtitle.is_empty():
		modal_body.add_child(_label(subtitle, 17, MUTED))
	if music:
		music.stream_paused = true

func _close_modal() -> void:
	paused = false
	if overlay:
		overlay.visible = false
	if music:
		music.stream_paused = false

func _show_pause() -> void:
	_open_modal("PAUSA", "Nivel " + str(_level().name) + " · " + ("PUZZNIC" if mode == 0 else "GRAVNIC"))
	modal_body.add_child(_button("Continuar", "Volver al juego", _close_modal))
	modal_body.add_child(_button("Reintentar", "Reiniciar nivel", _confirm_retry))
	modal_body.add_child(_button("Niveles", "Seleccionar nivel", _show_levels))
	modal_body.add_child(_button("Contraseña", "Introducir contraseña de NES", _show_password))
	modal_body.add_child(_button("Gravnic" if mode == 0 else "Puzznic", "Cambiar modo de juego", func(): mode = 1 - mode; score = 0; retries = 2; _load_level(0)))

func _confirm_retry() -> void:
	_open_modal("REINTENTAR", "%d reintentos disponibles" % retries)
	modal_body.add_child(_button("Reiniciar nivel", "Usar un reintento", func():
		if retries > 0: retries -= 1
		else: retries = 2; score = 0
		_load_level(level_index)))
	modal_body.add_child(_button("Cancelar", "Volver al juego", _close_modal))

func _complete_level() -> void:
	result_shown = true
	var bonus := int(_level().stage_bonus) + int(seconds) * int(_level().time_bonus_per_second)
	score += bonus
	completed["%d:%d" % [mode, level_index]] = true
	_save_progress()
	_play_effect(960, 0.35)
	_open_modal("NIVEL COMPLETADO", "Nivel " + str(_level().name))
	modal_body.add_child(_label("+%d" % bonus, 48))
	modal_body.add_child(_label("PUNTUACIÓN  %06d" % score, 17, MUTED))
	var last := 159 if mode == 0 else 79
	modal_body.add_child(_button("Siguiente nivel" if level_index < last else "Volver al comienzo", "Continuar", func(): retries = 2; _load_level(level_index + 1 if level_index < last else 0)))
	modal_body.add_child(_button("Rejugar", "Repetir nivel", func(): _load_level(level_index)))

func _show_levels() -> void:
	level_world = level_index / 10
	_render_levels()

func _render_levels() -> void:
	_open_modal("PUZZNIC · NES" if mode == 0 else "GRAVNIC · NES", "160 niveles" if mode == 0 else "80 niveles")
	var navigation := HBoxContainer.new()
	navigation.add_child(_button("←", "Mundo anterior", func(): level_world = maxi(0, level_world - 1); _render_levels()))
	navigation.add_child(_spacer())
	navigation.add_child(_label("MUNDO %02d" % (level_world + 1), 20))
	navigation.add_child(_spacer())
	navigation.add_child(_button("→", "Mundo siguiente", func(): level_world = mini(15 if mode == 0 else 7, level_world + 1); _render_levels()))
	modal_body.add_child(navigation)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for i in range(10):
		var index := level_world * 10 + i
		var label := "%d-%d" % [level_world + 1, i + 1]
		if completed.has("%d:%d" % [mode, index]): label += " ✓"
		var button := _button(label, "Abrir nivel " + label, func(): retries = 2; score = 0; _load_level(index))
		button.custom_minimum_size = Vector2(96, 68)
		if index == level_index: button.modulate = MINT
		grid.add_child(button)
	modal_body.add_child(grid)
	modal_body.add_child(_button("Volver", "Cerrar niveles", _close_modal))

func _show_password() -> void:
	_open_modal("CONTRASEÑA", "Código original de NES")
	var input := LineEdit.new()
	input.max_length = 4
	input.placeholder_text = "VVVV"
	input.custom_minimum_size.y = 56
	input.add_theme_font_size_override("font_size", 28)
	modal_body.add_child(input)
	var error := _label("", 16, Color("f28d99"))
	modal_body.add_child(error)
	var submit := func():
		for level in levels:
			if str(level.password) == input.text.strip_edges().to_upper():
				mode = int(level.mode)
				score = 0
				retries = 2
				_load_level(int(level.index))
				return
		error.text = "Contraseña incorrecta"
	modal_body.add_child(_button("Abrir nivel", "Confirmar contraseña", submit))
	modal_body.add_child(_button("Volver", "Cerrar", _close_modal))
	input.text_submitted.connect(func(_text: String): submit.call())
	input.grab_focus()

func _show_help() -> void:
	_open_modal("CONTROLES", "PUZZNIC · NES")
	for text in ["Flechas: mover el cursor.", "Mantén Z, X o Espacio + ← / → para mover un bloque.", "Ratón: selecciona un bloque y arrástralo de lado.", "Une dos o más símbolos iguales para eliminarlos.", "Los bloques caen; las plataformas los transportan.", "Esc / Enter: pausa. R: reintentar. F11: pantalla completa."]:
		modal_body.add_child(_label(text, 16))
	modal_body.add_child(_button("Volver al juego", "Cerrar controles", _close_modal))

func _fullscreen() -> void:
	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _toggle_audio() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	_save_progress()

func _play_effect(frequency: float, duration: float) -> void:
	if sound == null or muted:
		return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(int(duration * 22050) * 2)
	for i in range(data.size() / 2):
		var phase := sin(TAU * frequency * i / 22050.0)
		var value := int((0.18 if phase > 0 else -0.18) * (1.0 - i / (duration * 22050)) * 32767)
		data.encode_s16(i * 2, value)
	stream.data = data
	sound.stream = stream
	sound.play()

func _load_progress() -> void:
	if "--test" in OS.get_cmdline_user_args():
		return
	var config := ConfigFile.new()
	if config.load("user://progress.cfg") == OK:
		level_index = int(config.get_value("game", "level", 0))
		mode = int(config.get_value("game", "mode", 0))
		completed = config.get_value("game", "completed", {})
		muted = bool(config.get_value("game", "muted", false))
	AudioServer.set_bus_mute(0, muted)

func _save_progress() -> void:
	if "--test" in OS.get_cmdline_user_args():
		return
	var config := ConfigFile.new()
	config.set_value("game", "level", level_index)
	config.set_value("game", "mode", mode)
	config.set_value("game", "completed", completed)
	config.set_value("game", "muted", muted)
	config.save("user://progress.cfg")
