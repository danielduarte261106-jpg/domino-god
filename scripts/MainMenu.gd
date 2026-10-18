extends Control

# ── Colores base (modo oscuro = default) ──────────────────────────────────────
const COLOR_BG_DARK      := Color("#0D0D1A")   # noche profunda casi negra-azul
const COLOR_BG_TROPICAL  := Color("#0A2A14")   # verde selva oscuro
const COLOR_ACCENT       := Color("#ffd166")   # dorado cálido
const COLOR_MINT         := Color("#61f2d0")   # menta neón
const COLOR_HEART        := Color("#ff4757")   # rojo vivo
const COLOR_TROPIC_GREEN := Color("#39ff7a")   # verde neón tropical
const COLOR_TROPIC_LIME  := Color("#c8ff00")   # lima eléctrica
const COLOR_NEON_PURPLE  := Color("#c77dff")   # púrpura neón (modo oscuro)
const COLOR_NEON_CYAN    := Color("#00f5ff")   # cian neón (modo oscuro)
const COLOR_TEXT_MUTED   := Color(0.72, 0.78, 0.86)


var _main_menu_box: VBoxContainer
var _mode_menu_box: VBoxContainer
var _title_box: VBoxContainer
var _title_tween: Tween
var _current_environment_label: Label
var _instructions_dialog: Control
var _background: ColorRect
var _bg_overlay_a: ColorRect
var _env_particles: CPUParticles2D
var _env_tween: Tween
var _logo_title_lbl: Label
var _slot_panel: Panel

# --- Slot logo ---
var _slot_reels: Array[Label] = []          # 3 etiquetas de rodillos
var _slot_fruits: Array[String] = ["🍎", "🍌", "🍒", "🍇", "🍓", "🍊", "🍋"]
var _slot_indices: Array[int]  = [0, 2, 4]  # indices actuales por rodillo
var _slot_tweens: Array        = []         # tweens por rodillo
var _marquee_bulbs: Array[Label] = []       # bombillas de marquesina
var _marquee_tween: Tween
var _title_color_tween: Tween


func _ready() -> void:
	theme = _build_theme()
	_build_interface()
	_animate_entrance()


func _build_theme() -> Theme:
	var menu_theme := Theme.new()

	var is_tropical := (GameEconomy.selected_environment == "garden")
	var accent := COLOR_TROPIC_GREEN if is_tropical else COLOR_NEON_CYAN
	var border_idle := Color(accent.r, accent.g, accent.b, 0.4)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.10, 0.14, 0.88) if not is_tropical else Color(0.04, 0.18, 0.08, 0.88)
	normal.border_color = border_idle
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(20)
	normal.shadow_color = Color(0, 0, 0, 0.6)
	normal.shadow_size = 10
	normal.shadow_offset = Vector2(0, 4)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	normal.content_margin_top = 14
	normal.content_margin_bottom = 14

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.12, 0.18, 0.28, 0.96) if not is_tropical else Color(0.06, 0.28, 0.12, 0.96)
	hover.border_color = accent
	hover.shadow_size = 14

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.06, 0.08, 0.12, 0.98) if not is_tropical else Color(0.03, 0.14, 0.06, 0.98)
	pressed.border_color = COLOR_ACCENT

	menu_theme.set_stylebox("normal", "Button", normal)
	menu_theme.set_stylebox("hover", "Button", hover)
	menu_theme.set_stylebox("pressed", "Button", pressed)
	menu_theme.set_stylebox("focus", "Button", hover)
	menu_theme.set_color("font_color", "Button", Color("#ffffff"))
	menu_theme.set_color("font_hover_color", "Button", accent)
	menu_theme.set_color("font_pressed_color", "Button", COLOR_ACCENT)
	menu_theme.set_font_size("font_size", "Button", 22)

	menu_theme.set_color("font_color", "Label", Color("#f1f5f9"))
	menu_theme.set_font_size("font_size", "Label", 16)
	return menu_theme


func _build_interface() -> void:
	# ── Fondo principal (capa 1) ──────────────────────────────────────────────
	_background = ColorRect.new()
	_background.color = COLOR_BG_DARK
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_background)

	# Capa de acento radial (capa 2) - da el efecto de gradiente superior
	_bg_overlay_a = ColorRect.new()
	_bg_overlay_a.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_overlay_a.color = Color(COLOR_NEON_PURPLE.r, COLOR_NEON_PURPLE.g, COLOR_NEON_PURPLE.b, 0.12)
	_bg_overlay_a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_overlay_a)

	# ── Partículas de ambiente ────────────────────────────────────────────────
	_env_particles = CPUParticles2D.new()
	_env_particles.emitting = true
	_env_particles.amount = 28
	_env_particles.lifetime = 5.0
	_env_particles.explosiveness = 0.0
	_env_particles.direction = Vector2(0, -1)
	_env_particles.spread = 60.0
	_env_particles.gravity = Vector2(0, -20)
	_env_particles.initial_velocity_min = 30
	_env_particles.initial_velocity_max = 70
	_env_particles.angular_velocity_min = -60
	_env_particles.angular_velocity_max = 60
	_env_particles.scale_amount_min = 2.0
	_env_particles.scale_amount_max = 5.0
	_env_particles.position = Vector2(360, 900)
	var grad := Gradient.new()
	grad.set_color(0, Color(COLOR_NEON_CYAN.r, COLOR_NEON_CYAN.g, COLOR_NEON_CYAN.b, 0.8))
	grad.set_color(1, Color(COLOR_NEON_PURPLE.r, COLOR_NEON_PURPLE.g, COLOR_NEON_PURPLE.b, 0.0))
	_env_particles.color_ramp = grad
	add_child(_env_particles)


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
	_title_box.add_theme_constant_override("separation", 8)
	_title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(_title_box)

	# =========================================================
	# MARQUESINA superior con bombillas parpadeantes
	# =========================================================
	var marquee_row := HBoxContainer.new()
	marquee_row.alignment = BoxContainer.ALIGNMENT_CENTER
	marquee_row.add_theme_constant_override("separation", 6)
	_title_box.add_child(marquee_row)

	_marquee_bulbs.clear()
	for i in range(11):
		var bulb := Label.new()
		bulb.text = "o"
		bulb.add_theme_font_size_override("font_size", 14)
		bulb.add_theme_color_override("font_color", COLOR_ACCENT)
		marquee_row.add_child(bulb)
		_marquee_bulbs.append(bulb)
	_start_marquee_animation()

	# =========================================================
	# TEXTO COMBIFRUTAS con color alternante (cyan <-> magenta)
	# =========================================================
	_logo_title_lbl = Label.new()
	_logo_title_lbl.text = "COMBIFRUTAS"
	_logo_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_logo_title_lbl.add_theme_font_size_override("font_size", 56)
	_logo_title_lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	_logo_title_lbl.add_theme_color_override("font_shadow_color", COLOR_NEON_PURPLE)
	_logo_title_lbl.add_theme_constant_override("shadow_offset_x", 0)
	_logo_title_lbl.add_theme_constant_override("shadow_offset_y", 5)
	_logo_title_lbl.add_theme_constant_override("shadow_size", 10)
	_title_box.add_child(_logo_title_lbl)
	_start_title_color_cycle()

	# =========================================================
	# SLOT: 3 rodillos animados dentro de un panel tipo maquina
	# =========================================================
	var slot_wrapper := CenterContainer.new()
	slot_wrapper.custom_minimum_size = Vector2(0, 90)
	_title_box.add_child(slot_wrapper)

	_slot_panel = Panel.new()
	_slot_panel.custom_minimum_size = Vector2(260, 82)
	var sp_style := StyleBoxFlat.new()
	sp_style.bg_color = Color(0.05, 0.05, 0.10, 0.98)
	sp_style.set_corner_radius_all(16)
	sp_style.border_color = COLOR_ACCENT
	sp_style.set_border_width_all(3)
	sp_style.shadow_color = Color(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 0.6)
	sp_style.shadow_size = 16
	_slot_panel.add_theme_stylebox_override("panel", sp_style)
	slot_wrapper.add_child(_slot_panel)

	var slot_row := HBoxContainer.new()
	slot_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_row.add_theme_constant_override("separation", 0)
	_slot_panel.add_child(slot_row)

	_slot_reels.clear()
	_slot_tweens.clear()
	for i in range(3):
		# separador entre rodillos
		if i > 0:
			var sep := ColorRect.new()
			sep.color = Color(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 0.5)
			sep.custom_minimum_size = Vector2(2, 60)
			sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			slot_row.add_child(sep)

		var reel := Label.new()
		reel.text = _slot_fruits[_slot_indices[i]]
		reel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		reel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reel.add_theme_font_size_override("font_size", 42)
		slot_row.add_child(reel)
		_slot_reels.append(reel)
		_slot_tweens.append(null)
		_start_reel_spin(i)

	# Subtitulo (solo caracteres ASCII seguros)
	var subtitle := Label.new()
	subtitle.text = "DOMINO  *  ESTRATEGIA  *  COMBINATORIA"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(COLOR_MINT.r, COLOR_MINT.g, COLOR_MINT.b, 0.70))
	_title_box.add_child(subtitle)

	# Marquesina inferior (espejo)
	var marquee_bot := HBoxContainer.new()
	marquee_bot.alignment = BoxContainer.ALIGNMENT_CENTER
	marquee_bot.add_theme_constant_override("separation", 6)
	_title_box.add_child(marquee_bot)
	for i in range(11):
		var bulb := Label.new()
		bulb.text = "o"
		bulb.add_theme_font_size_override("font_size", 14)
		# alterna fase con marquesina superior
		var is_lit := (i % 2 == 1)
		bulb.add_theme_color_override("font_color",
			COLOR_ACCENT if is_lit else Color(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 0.25))
		marquee_bot.add_child(bulb)

	# Flotacion del bloque completo
	_title_box.pivot_offset = Vector2(250, 100)
	if _title_tween != null and _title_tween.is_running():
		_title_tween.kill()
	_title_tween = create_tween().set_loops()
	_title_tween.tween_property(_title_box, "position:y", -7.0, 1.9).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_title_tween.tween_property(_title_box, "position:y", 7.0, 1.9).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# =========================================================
# Animacion marquesina: bombillas van encendiendo de izq a der en bucle
# =========================================================
func _start_marquee_animation() -> void:
	if _marquee_tween != null and _marquee_tween.is_running():
		_marquee_tween.kill()
	_marquee_tween = create_tween().set_loops()
	var ON  := COLOR_ACCENT
	var OFF := Color(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 0.2)
	for i in _marquee_bulbs.size():
		var b: Label = _marquee_bulbs[i]
		_marquee_tween.tween_callback(func(): b.add_theme_color_override("font_color", ON)).set_delay(0.08)
		_marquee_tween.tween_callback(func(): b.add_theme_color_override("font_color", OFF)).set_delay(0.08)
	_marquee_tween.tween_interval(0.3)


# =========================================================
# Color alternante del titulo: dorado -> cian -> magenta -> dorado
# =========================================================
func _start_title_color_cycle() -> void:
	if _title_color_tween != null and _title_color_tween.is_running():
		_title_color_tween.kill()
	if _logo_title_lbl == null:
		return
	_title_color_tween = create_tween().set_loops()
	_title_color_tween.tween_property(_logo_title_lbl, "modulate", Color(1.0, 0.82, 0.3), 0.9).set_trans(Tween.TRANS_SINE)
	_title_color_tween.tween_property(_logo_title_lbl, "modulate", Color(0.3, 1.0, 1.0), 0.9).set_trans(Tween.TRANS_SINE)
	_title_color_tween.tween_property(_logo_title_lbl, "modulate", Color(1.0, 0.4, 1.0), 0.9).set_trans(Tween.TRANS_SINE)
	_title_color_tween.tween_property(_logo_title_lbl, "modulate", Color.WHITE, 0.9).set_trans(Tween.TRANS_SINE)


# =========================================================
# Reel spin: cada rodillo cambia de fruta a intervalos escalonados
# =========================================================
func _start_reel_spin(reel_idx: int) -> void:
	var delay_sec := 0.55 + reel_idx * 0.35
	var t := create_tween()
	t.tween_interval(delay_sec)
	t.tween_callback(func(): _spin_reel_step(reel_idx))


func _spin_reel_step(reel_idx: int) -> void:
	if _slot_reels.size() <= reel_idx:
		return
	var reel: Label = _slot_reels[reel_idx]

	# animacion de salida: escala Y a 0
	var out_t := reel.create_tween()
	out_t.tween_property(reel, "scale", Vector2(1.0, 0.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	out_t.tween_callback(func():
		# cambiar fruta
		_slot_indices[reel_idx] = (_slot_indices[reel_idx] + 1) % _slot_fruits.size()
		reel.text = _slot_fruits[_slot_indices[reel_idx]]
		# animacion de entrada: escala Y de 0 a 1
		var in_t := reel.create_tween()
		in_t.tween_property(reel, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		in_t.tween_callback(func(): _schedule_next_spin(reel_idx))
	)


func _schedule_next_spin(reel_idx: int) -> void:
	# intervalo variable para efecto mas natural: 1.0s - 2.5s escalonado
	var interval := 1.0 + reel_idx * 0.45
	var t := create_tween()
	t.tween_interval(interval)
	t.tween_callback(func(): _spin_reel_step(reel_idx))


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
	# Ciclar: board → garden → board (2 opciones bien diferenciadas)
	GameEconomy.selected_environment = "garden" if current == "board" else "board"
	if _current_environment_label != null:
		_current_environment_label.text = "Tablero: %s" % _environment_display_name()
	_apply_environment_theme()


func _environment_display_name() -> String:
	return "🌴 Huerto Tropical" if GameEconomy.selected_environment == "garden" else "🌑 Pizarrón Oscuro"


func _apply_environment_theme() -> void:
	var is_tropical := (GameEconomy.selected_environment == "garden")

	# ── Paleta de colores según modo ──────────────────────────────────────────
	var bg_target   := COLOR_BG_TROPICAL if is_tropical else COLOR_BG_DARK
	var ovr_color   := Color(COLOR_TROPIC_GREEN.r, COLOR_TROPIC_GREEN.g, COLOR_TROPIC_GREEN.b, 0.10) if is_tropical \
					 else Color(COLOR_NEON_PURPLE.r, COLOR_NEON_PURPLE.g, COLOR_NEON_PURPLE.b, 0.12)
	var accent_col  := COLOR_TROPIC_GREEN if is_tropical else COLOR_NEON_CYAN
	var title_glow  := Color(COLOR_TROPIC_LIME.r, COLOR_TROPIC_LIME.g, COLOR_TROPIC_LIME.b, 0.85) if is_tropical \
					 else Color(COLOR_NEON_PURPLE.r, COLOR_NEON_PURPLE.g, COLOR_NEON_PURPLE.b, 0.9)

	# Transición suave del fondo
	if _env_tween != null and _env_tween.is_running():
		_env_tween.kill()
	_env_tween = create_tween().set_parallel(true)
	_env_tween.tween_property(_background, "color", bg_target, 0.55).set_trans(Tween.TRANS_SINE)
	_env_tween.tween_property(_bg_overlay_a, "color", ovr_color, 0.55).set_trans(Tween.TRANS_SINE)

	# ── Partículas de ambiente ────────────────────────────────────────────────
	if _env_particles != null:
		var grad2 := Gradient.new()
		var p_color := COLOR_TROPIC_GREEN if is_tropical else COLOR_NEON_CYAN
		grad2.set_color(0, Color(p_color.r, p_color.g, p_color.b, 0.9))
		grad2.set_color(1, Color(p_color.r, p_color.g, p_color.b, 0.0))
		_env_particles.color_ramp = grad2
		_env_particles.initial_velocity_min = 50 if is_tropical else 30
		_env_particles.initial_velocity_max = 100 if is_tropical else 70
		_env_particles.amount = 40 if is_tropical else 22
		# Modo tropical: partículas suben como burbujas con algo de spread lateral
		_env_particles.spread = 80.0 if is_tropical else 55.0

	# ── Logo: color del texto y brillo del slot según modo ────────────────────
	if _logo_title_lbl != null:
		_logo_title_lbl.add_theme_color_override("font_shadow_color", title_glow)

	if _slot_panel != null:
		var ds := StyleBoxFlat.new()
		ds.bg_color = Color(0.04, 0.16, 0.06, 0.95) if is_tropical else Color(0.05, 0.05, 0.10, 0.98)
		ds.set_corner_radius_all(16)
		ds.border_color = accent_col
		ds.set_border_width_all(3)
		ds.shadow_color = Color(accent_col.r, accent_col.g, accent_col.b, 0.55)
		ds.shadow_size = 16
		_slot_panel.add_theme_stylebox_override("panel", ds)

	# ── Reconstruir tema de botones ───────────────────────────────────────────
	theme = _build_theme()


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
