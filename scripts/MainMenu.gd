extends Control

const COLOR_BG := Color("#1E1E1E")
const COLOR_ACCENT := Color("#ffd166")
const COLOR_MINT := Color("#61f2d0")
const COLOR_HEART := Color("#ff4757")
const COLOR_TEXT_MUTED := Color(0.72, 0.78, 0.86)

var _main_menu_box: VBoxContainer
var _mode_menu_box: VBoxContainer
var _title_box: VBoxContainer
var _title_tween: Tween
var _current_environment_label: Label
var _instructions_dialog: Control


func _ready() -> void:
	theme = _build_theme()
	_build_interface()
	_animate_entrance()


func _build_theme() -> Theme:
	var menu_theme := Theme.new()

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.18, 0.22, 0.92)
	normal.border_color = Color(0.35, 0.40, 0.50, 0.6)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(18)
	normal.shadow_color = Color(0, 0, 0, 0.45)
	normal.shadow_size = 8
	normal.shadow_offset = Vector2(0, 4)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.26, 0.32, 0.96)
	hover.border_color = COLOR_MINT

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.12, 0.14, 0.18, 0.98)
	pressed.border_color = COLOR_ACCENT

	menu_theme.set_stylebox("normal", "Button", normal)
	menu_theme.set_stylebox("hover", "Button", hover)
	menu_theme.set_stylebox("pressed", "Button", pressed)
	menu_theme.set_stylebox("focus", "Button", hover)
	menu_theme.set_color("font_color", "Button", Color("#ffffff"))
	menu_theme.set_color("font_hover_color", "Button", COLOR_ACCENT)
	menu_theme.set_color("font_pressed_color", "Button", COLOR_MINT)
	menu_theme.set_font_size("font_size", "Button", 22)

	menu_theme.set_color("font_color", "Label", Color("#f1f5f9"))
	menu_theme.set_font_size("font_size", "Label", 16)
	return menu_theme


func _build_interface() -> void:
	# Fondo Oscuro Premium
	var background := ColorRect.new()
	background.color = COLOR_BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# Barra Superior de Estado (Economía)
	_build_top_stats()

	# Contenedor Central
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var main_vbox := VBoxContainer.new()
	main_vbox.custom_minimum_size = Vector2(500, 0)
	main_vbox.add_theme_constant_override("separation", 24)
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(main_vbox)

	# Título Estilizado
	_build_title(main_vbox)

	# Contenedor de Botones Principales
	_main_menu_box = VBoxContainer.new()
	_main_menu_box.add_theme_constant_override("separation", 14)
	main_vbox.add_child(_main_menu_box)

	_add_menu_button(_main_menu_box, "▶  JUGAR", _show_mode_selection, true)
	var env_btn := _add_menu_button(_main_menu_box, "🎨  AMBIENTE", _toggle_environment)
	_current_environment_label = Label.new()
	_current_environment_label.text = "Tablero: %s" % _environment_display_name()
	_current_environment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_current_environment_label.add_theme_font_size_override("font_size", 13)
	_current_environment_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	_main_menu_box.add_child(_current_environment_label)

	_add_menu_button(_main_menu_box, "📖  CÓMO JUGAR", _show_instructions)
	_add_menu_button(_main_menu_box, "🚪  SALIR", _quit_game)

	# Contenedor de Selección de Modo (inicialmente oculto)
	_mode_menu_box = VBoxContainer.new()
	_mode_menu_box.add_theme_constant_override("separation", 14)
	_mode_menu_box.visible = false
	main_vbox.add_child(_mode_menu_box)

	var mode_title := Label.new()
	mode_title.text = "Elige tu Modo de Juego"
	mode_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_title.add_theme_font_size_override("font_size", 18)
	mode_title.add_theme_color_override("font_color", COLOR_MINT)
	_mode_menu_box.add_child(mode_title)

	var target_label := Label.new()
	target_label.text = "🎯 Límite de Puntos para Victoria"
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_label.add_theme_font_size_override("font_size", 16)
	target_label.add_theme_color_override("font_color", COLOR_ACCENT)
	_mode_menu_box.add_child(target_label)

	var target_options := OptionButton.new()
	target_options.custom_minimum_size = Vector2(0, 56)
	target_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_options.add_theme_font_size_override("font_size", 18)
	target_options.add_item("50 Puntos", 0)
	target_options.add_item("100 Puntos (Estándar)", 1)
	target_options.add_item("150 Puntos", 2)
	match GameEconomy.target_score:
		50: target_options.selected = 0
		150: target_options.selected = 2
		_: target_options.selected = 1
	target_options.item_selected.connect(func(index: int):
		match index:
			0: GameEconomy.target_score = 50
			1: GameEconomy.target_score = 100
			2: GameEconomy.target_score = 150
	)
	_mode_menu_box.add_child(target_options)

	_add_menu_button(_mode_menu_box, "👤  1 vs 1 Local", _start_mode.bind("local_1v1"))
	_add_menu_button(_mode_menu_box, "🤖  1 vs CPU", _start_mode.bind("vs_cpu"))
	_add_menu_button(_mode_menu_box, "👥  2 vs 2 Parejas", _start_mode.bind("local_2v2"))
	_add_menu_button(_mode_menu_box, "⬅  Volver", _show_main_menu)

	# Diálogo de Instrucciones
	_build_instructions_dialog()


func _build_top_stats() -> void:
	var stats_bar := HBoxContainer.new()
	stats_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	stats_bar.anchor_left = 0.0
	stats_bar.anchor_right = 1.0
	stats_bar.offset_top = 22
	stats_bar.offset_left = 28
	stats_bar.offset_right = -28
	stats_bar.offset_bottom = 60
	stats_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stats_bar)

	var lives_lbl := Label.new()
	lives_lbl.text = "♥♥♥"
	lives_lbl.add_theme_font_size_override("font_size", 24)
	lives_lbl.add_theme_color_override("font_color", COLOR_HEART)
	stats_bar.add_child(lives_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_bar.add_child(spacer)

	var coins_lbl := Label.new()
	coins_lbl.text = "🪙 %d" % GameEconomy.coins
	coins_lbl.add_theme_font_size_override("font_size", 18)
	coins_lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	stats_bar.add_child(coins_lbl)

	var separator := Label.new()
	separator.text = "  ·  "
	separator.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	stats_bar.add_child(separator)

	var stars_lbl := Label.new()
	stars_lbl.text = "⭐ %d" % GameEconomy.stars
	stars_lbl.add_theme_font_size_override("font_size", 18)
	stars_lbl.add_theme_color_override("font_color", COLOR_MINT)
	stats_bar.add_child(stars_lbl)


func _build_title(parent: VBoxContainer) -> void:
	_title_box = VBoxContainer.new()
	_title_box.add_theme_constant_override("separation", 6)
	_title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(_title_box)

	var badge := Label.new()
	badge.text = "🍎 · 🍌 · 🍒 · 🍇"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 22)
	_title_box.add_child(badge)

	var title := Label.new()
	title.text = "COMBIFRUTAS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", COLOR_ACCENT)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	_title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "DOMINÓ ESTRATÉGICO · MATEMÁTICAS 2D"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	_title_box.add_child(subtitle)

	# Animación de respiración / flotación en el título
	_title_box.pivot_offset = Vector2(250, 45)
	if _title_tween != null and _title_tween.is_running():
		_title_tween.kill()
	_title_tween = create_tween().set_loops()
	_title_tween.tween_property(_title_box, "position:y", -6.0, 1.8).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_title_tween.tween_property(_title_box, "position:y", 6.0, 1.8).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _add_menu_button(parent: VBoxContainer, label: String, callback: Callable, is_primary: bool = false) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 56)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(callback)
	parent.add_child(button)

	button.pivot_offset = Vector2(200, 28)

	if is_primary:
		var style: StyleBoxFlat = button.get_theme_stylebox("normal").duplicate()
		style.border_color = COLOR_MINT
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_color_override("font_color", COLOR_MINT)
		button.add_theme_font_size_override("font_size", 24)

	# Micro-interacciones de escala y retroalimentación
	button.mouse_entered.connect(_animate_button.bind(button, Vector2(1.035, 1.035)))
	button.mouse_exited.connect(_animate_button.bind(button, Vector2.ONE))
	button.button_down.connect(_animate_button.bind(button, Vector2(0.96, 0.96)))
	button.button_up.connect(_animate_button.bind(button, Vector2.ONE))
	return button


func _animate_button(button: Button, target_scale: Vector2) -> void:
	var tween := button.create_tween()
	tween.tween_property(button, "scale", target_scale, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate_entrance() -> void:
	_title_box.modulate.a = 0.0
	_title_box.position.y -= 40.0
	var title_tween := create_tween().set_parallel(true)
	title_tween.tween_property(_title_box, "modulate:a", 1.0, 0.4)
	title_tween.tween_property(_title_box, "position:y", _title_box.position.y + 40.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var index := 0
	for child in _main_menu_box.get_children():
		if child is Button:
			child.modulate.a = 0.0
			child.scale = Vector2(0.85, 0.85)
			child.position.x -= 30.0

			var delay := 0.15 + index * 0.07
			var tween := create_tween().set_parallel(true)
			tween.tween_property(child, "modulate:a", 1.0, 0.25).set_delay(delay)
			tween.tween_property(child, "scale", Vector2.ONE, 0.35).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(child, "position:x", child.position.x + 30.0, 0.35).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			index += 1


func _show_mode_selection() -> void:
	var tween := create_tween()
	tween.tween_property(_main_menu_box, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		_main_menu_box.visible = false
		_mode_menu_box.visible = true
		_mode_menu_box.modulate.a = 0.0
		var in_tween := create_tween()
		in_tween.tween_property(_mode_menu_box, "modulate:a", 1.0, 0.2)
		var index := 0
		for child in _mode_menu_box.get_children():
			if child is Button:
				child.scale = Vector2(0.9, 0.9)
				var btn_tween := create_tween()
				btn_tween.tween_property(child, "scale", Vector2.ONE, 0.25).set_delay(index * 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				index += 1
	)


func _show_main_menu() -> void:
	var tween := create_tween()
	tween.tween_property(_mode_menu_box, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		_mode_menu_box.visible = false
		_main_menu_box.visible = true
		_main_menu_box.modulate.a = 0.0
		var in_tween := create_tween()
		in_tween.tween_property(_main_menu_box, "modulate:a", 1.0, 0.2)
	)


func _start_mode(mode: String) -> void:
	GameEconomy.selected_mode = mode
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _toggle_environment() -> void:
	var current: String = GameEconomy.selected_environment
	GameEconomy.selected_environment = "garden" if current == "board" else "board"
	if _current_environment_label != null:
		_current_environment_label.text = "Tablero: %s" % _environment_display_name()


func _environment_display_name() -> String:
	return "Huerto Tropical" if GameEconomy.selected_environment == "garden" else "Pizarrón Oscuro"


func _build_instructions_dialog() -> void:
	_instructions_dialog = Control.new()
	_instructions_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_instructions_dialog.visible = false
	add_child(_instructions_dialog)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_instructions_dialog.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_instructions_dialog.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(560, 480)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.14, 0.16, 0.20, 0.98)
	card_style.border_color = COLOR_MINT
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(24)
	card_style.shadow_color = Color(0, 0, 0, 0.6)
	card_style.shadow_size = 18
	card_style.content_margin_left = 32
	card_style.content_margin_right = 32
	card_style.content_margin_top = 28
	card_style.content_margin_bottom = 28
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	card.add_child(content)

	var title := Label.new()
	title.text = "📖 Reglas de CombiFrutas"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COLOR_ACCENT)
	content.add_child(title)

	var text := Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.text = "• Conecta fichas haciendo coincidir la fruta en cualquiera de los dos extremos abiertos.\n\n• Fichas Dobles: se colocan cruzadas perpendicularmente respecto a la cadena.\n\n• Giro en U (Snaking): el tablero se curva automáticamente al llegar al borde de la pantalla.\n\n• Reto de Ayuda 🛟: responde el reto combinatorio para desbloquear el Comodín Matemático y recuperar vidas.\n\n• ¡Vacía tu mano para ganar la partida y sumar estrellas!"
	text.add_theme_font_size_override("font_size", 16)
	text.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98))
	content.add_child(text)

	var close_btn := Button.new()
	close_btn.text = "Entendido"
	close_btn.custom_minimum_size = Vector2(0, 56)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(func(): _instructions_dialog.visible = false)
	content.add_child(close_btn)
	_setup_dialog_button(close_btn)


func _setup_dialog_button(btn: Button) -> void:
	btn.pivot_offset = btn.custom_minimum_size * 0.5
	btn.mouse_entered.connect(_animate_button.bind(btn, Vector2(1.05, 1.05)))
	btn.mouse_exited.connect(_animate_button.bind(btn, Vector2.ONE))


func _show_instructions() -> void:
	_instructions_dialog.visible = true
	_instructions_dialog.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_instructions_dialog, "modulate:a", 1.0, 0.2)


func _quit_game() -> void:
	get_tree().quit()
