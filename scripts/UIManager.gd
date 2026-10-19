extends CanvasLayer

signal help_requested
signal draw_requested
signal pass_requested
signal side_chosen(side: String)
signal restart_requested
signal menu_requested
signal mode_selected(mode: String)
signal pause_opened
signal pause_closed

const COLOR_BACKGROUND := Color("#1E1E1E")
const COLOR_ACCENT := Color("#ffd166")
const COLOR_ACTIVE_RING := Color("#61f2d0")
const COLOR_HEART := Color("#ff4757")

var _root: Control
var _theme: Theme

# Floating Top HUD (Transparent, No Panels)
var _hud_bar: Control
var _lives_label: Label
var _turn_info_label: Label
var _pause_btn: Button

# Floating Avatars (Top, Left, Right, Bottom)
var _avatar_nodes: Dictionary = {}

# Floating Hand (No Dock Container)
var _hand_row: HBoxContainer
var _ends_label: Label

# Discrete Floating Action Buttons (Robar & Pasar)
var _draw_btn: Button
var _pass_btn: Button
var _draw_pulse_tween: Tween
var _pass_pulse_tween: Tween

# Floating Help / Lifesaver Button (Trivia on Demand)
var _help_btn: Button
var _help_pulse_tween: Tween

# Contextual Side Chooser (when a piece matches both ends)
var _side_choice_bar: Control
var _side_left_btn: Button
var _side_right_btn: Button
var _side_choice_tween: Tween

# Floating Toast / Status
var _toast_label: Label
var _toast_tween: Tween

# Pause Modal
var _modal_overlay: ColorRect
var _modal_panel: PanelContainer
var _modal_tween: Tween
var _mode_buttons: Dictionary = {}
var _current_mode: String = "local_1v1"

# Visual Effects
var _confetti: CPUParticles2D
var _formula_label: Label


func _ready() -> void:
	layer = 10
	_build_theme()
	_build_interface()
	_build_effects()


func _build_theme() -> void:
	_theme = Theme.new()

	# Flat transparent / subtle button styles
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.18, 0.20, 0.24, 0.85)
	btn_normal.set_corner_radius_all(16)
	btn_normal.border_width_left = 1
	btn_normal.border_width_top = 1
	btn_normal.border_width_right = 1
	btn_normal.border_width_bottom = 1
	btn_normal.border_color = Color(1.0, 1.0, 1.0, 0.25)
	btn_normal.shadow_color = Color(0, 0, 0, 0.4)
	btn_normal.shadow_size = 6
	btn_normal.shadow_offset = Vector2(0, 3)
	btn_normal.content_margin_left = 20
	btn_normal.content_margin_right = 20
	btn_normal.content_margin_top = 14
	btn_normal.content_margin_bottom = 14

	var btn_hover := btn_normal.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.26, 0.30, 0.38, 0.95)
	btn_hover.border_color = COLOR_ACCENT

	var btn_pressed := btn_normal.duplicate() as StyleBoxFlat
	btn_pressed.bg_color = Color(0.12, 0.14, 0.18, 0.95)

	_theme.set_stylebox("normal", "Button", btn_normal)
	_theme.set_stylebox("hover", "Button", btn_hover)
	_theme.set_stylebox("pressed", "Button", btn_pressed)
	_theme.set_stylebox("focus", "Button", btn_hover)
	_theme.set_color("font_color", "Button", Color("#ffffff"))
	_theme.set_font_size("font_size", "Button", 22)

	_theme.set_color("font_color", "Label", Color("#f1f5f9"))
	_theme.set_font_size("font_size", "Label", 18)


func _build_interface() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _theme
	add_child(_root)

	_build_top_hud()
	_build_floating_avatars()
	_build_floating_hand()
	_build_discrete_action_buttons()
	_build_help_button()
	_build_side_choice_bar()
	_build_floating_toast()
	_build_modal_menu()


# -------------------------------------------------------------------------
# 1. TOP HUD (Minimalist, completely transparent, no enclosing box)
# -------------------------------------------------------------------------
func _build_top_hud() -> void:
	_hud_bar = Control.new()
	_hud_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hud_bar.anchor_left = 0.0
	_hud_bar.anchor_right = 1.0
	_hud_bar.anchor_top = 0.0
	_hud_bar.anchor_bottom = 0.0
	_hud_bar.offset_top = 18
	_hud_bar.offset_bottom = 64
	_hud_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hud_bar)

	# Vidas flotantes (Izquierda)
	_lives_label = Label.new()
	_lives_label.text = "♥♥♥"
	_lives_label.position = Vector2(24, 0)
	_lives_label.size = Vector2(180, 44)
	_lives_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lives_label.add_theme_font_size_override("font_size", 30)
	_lives_label.add_theme_color_override("font_color", COLOR_HEART)
	_lives_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_lives_label.add_theme_constant_override("shadow_offset_x", 2)
	_lives_label.add_theme_constant_override("shadow_offset_y", 2)
	_hud_bar.add_child(_lives_label)

	# Información de turno / partida (Centro)
	_turn_info_label = Label.new()
	_turn_info_label.text = "Dominó Clásico"
	_turn_info_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_turn_info_label.anchor_left = 0.5
	_turn_info_label.anchor_right = 0.5
	_turn_info_label.offset_left = -200
	_turn_info_label.offset_right = 200
	_turn_info_label.offset_top = 4
	_turn_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_info_label.add_theme_font_size_override("font_size", 19)
	_turn_info_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	_hud_bar.add_child(_turn_info_label)

	# Botón de Pausa flotante (Derecha)
	_pause_btn = Button.new()
	_pause_btn.text = "⏸"
	_pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pause_btn.anchor_left = 1.0
	_pause_btn.anchor_right = 1.0
	_pause_btn.offset_left = -64
	_pause_btn.offset_right = -20
	_pause_btn.offset_top = 0
	_pause_btn.offset_bottom = 44
	_pause_btn.flat = true
	_pause_btn.add_theme_font_size_override("font_size", 22)
	_pause_btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_pause_btn.pressed.connect(open_pause_modal)
	_setup_button_bounce(_pause_btn)
	_hud_bar.add_child(_pause_btn)


# -------------------------------------------------------------------------
# 2. FLOATING AVATARS (Estilo Dominó - Juego de Tablero)
# -------------------------------------------------------------------------
func _build_floating_avatars() -> void:
	# Top Avatar (J3 / CPU en 1v1): centrado exacto en pantalla 720px (360 - 50 = 310)
	_avatar_nodes["top"] = _create_avatar_view(
		Vector2(310, 105),
		"CPU",
		"🤖",
		true
	)

	# Left Avatar (J2 en 2v2): margen izquierdo seguro
	_avatar_nodes["left"] = _create_avatar_view(
		Vector2(20, 520),
		"J2",
		"👤",
		false
	)

	# Right Avatar (J4 en 2v2): simétrico al izquierdo (720 - 100 - 20 = 600)
	_avatar_nodes["right"] = _create_avatar_view(
		Vector2(600, 520),
		"J4",
		"👤",
		false
	)

	# Bottom Avatar (Jugador Principal - Tú): esquina inferior izquierda, arriba de la mano
	_avatar_nodes["bottom"] = _create_avatar_view(
		Vector2(24, 980),
		"Tú",
		"👑",
		true
	)


func _create_avatar_view(pos: Vector2, default_name: String, icon_emoji: String, default_visible: bool) -> Control:
	var container := Control.new()
	container.position = pos
	container.size = Vector2(100, 70)
	container.pivot_offset = Vector2(50, 35)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.visible = default_visible
	_root.add_child(container)

	# Círculo del Avatar
	var circle := Panel.new()
	circle.size = Vector2(52, 52)
	circle.position = Vector2(24, 0)
	var circle_style := StyleBoxFlat.new()
	circle_style.bg_color = Color(0.14, 0.17, 0.22, 0.95)
	circle_style.set_corner_radius_all(26)
	circle_style.border_width_left = 2
	circle_style.border_width_top = 2
	circle_style.border_width_right = 2
	circle_style.border_width_bottom = 2
	circle_style.border_color = Color(0.4, 0.45, 0.55)
	circle_style.shadow_color = Color(0, 0, 0, 0.5)
	circle_style.shadow_size = 8
	circle_style.shadow_offset = Vector2(0, 3)
	circle.add_theme_stylebox_override("panel", circle_style)
	container.add_child(circle)
	container.set_meta("circle_style", circle_style)

	var icon_lbl := Label.new()
	icon_lbl.text = icon_emoji
	icon_lbl.size = circle.size
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 24)
	circle.add_child(icon_lbl)

	# Badge de conteo de fichas restantes
	var tiles_badge := Label.new()
	tiles_badge.text = "7"
	tiles_badge.size = Vector2(28, 22)
	tiles_badge.position = Vector2(52, 32)
	tiles_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tiles_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tiles_badge.add_theme_font_size_override("font_size", 13)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.2, 0.25, 0.35)
	badge_style.set_corner_radius_all(8)
	tiles_badge.add_theme_stylebox_override("normal", badge_style)
	container.add_child(tiles_badge)
	container.set_meta("tiles_badge", tiles_badge)

	# Nombre y Puntuación discreta debajo
	var info_box := VBoxContainer.new()
	info_box.position = Vector2(0, 56)
	info_box.size = Vector2(100, 36)
	info_box.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(info_box)

	var name_lbl := Label.new()
	name_lbl.text = default_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98))
	info_box.add_child(name_lbl)
	container.set_meta("name_lbl", name_lbl)

	var score_lbl := Label.new()
	score_lbl.text = "0 pts"
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.add_theme_font_size_override("font_size", 14)
	score_lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	info_box.add_child(score_lbl)
	container.set_meta("score_lbl", score_lbl)

	return container


# -------------------------------------------------------------------------
# 3. FLOATING HAND (Sin Dock ni cajas inferiores)
# -------------------------------------------------------------------------
func _build_floating_hand() -> void:
	# Indicador sutil de extremos abiertos flotando sobre el área
	_ends_label = Label.new()
	_ends_label.text = "Extremos: —"
	_ends_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_ends_label.anchor_left = 0.5
	_ends_label.anchor_right = 0.5
	_ends_label.anchor_top = 1.0
	_ends_label.anchor_bottom = 1.0
	# Estrecho para no solapar con avatar izquierdo (X:110-210): empieza desde X:220
	_ends_label.offset_left = -140
	_ends_label.offset_right = 140
	_ends_label.offset_top = -230
	_ends_label.offset_bottom = -200
	_ends_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ends_label.add_theme_font_size_override("font_size", 17)
	_ends_label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	_root.add_child(_ends_label)

	# Contenedor de fichas de la mano
	_hand_row = HBoxContainer.new()
	_hand_row.name = "HandRow"
	_hand_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hand_row.anchor_left = 0.5
	_hand_row.anchor_right = 0.5
	_hand_row.anchor_top = 1.0
	_hand_row.anchor_bottom = 1.0
	_hand_row.offset_left = -345
	_hand_row.offset_right = 345
	# Empujado abajo para dejar espacio al ends_label (gap mínimo de 12px)
	_hand_row.offset_top = -185
	_hand_row.offset_bottom = -12
	_hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_row.add_theme_constant_override("separation", 6)
	_hand_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(_hand_row)


# -------------------------------------------------------------------------
# 4. DISCRETE ACTION BUTTONS (Robar / Pasar flotantes sutiles)
# -------------------------------------------------------------------------
func _build_discrete_action_buttons() -> void:
	# Botón Robar Ficha: zona superior de acción (sobre el área de bloqueo)
	_draw_btn = Button.new()
	_draw_btn.text = "🀄 Robar del Pozo"
	_draw_btn.custom_minimum_size = Vector2(0, 60)
	_draw_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_draw_btn.anchor_left = 0.5
	_draw_btn.anchor_right = 0.5
	_draw_btn.anchor_top = 1.0
	_draw_btn.anchor_bottom = 1.0
	# Zona de acción: Y 900–965 (encima del botón Ayuda a Y:985–1050)
	_draw_btn.offset_left = -130
	_draw_btn.offset_right = 130
	_draw_btn.offset_top = -380
	_draw_btn.offset_bottom = -320
	_draw_btn.pivot_offset = Vector2(130, 30)
	_draw_btn.add_theme_font_size_override("font_size", 22)
	_draw_btn.pressed.connect(func(): draw_requested.emit())
	_setup_button_bounce(_draw_btn)
	_draw_btn.visible = false
	_root.add_child(_draw_btn)

	# Botón Pasar Turno: misma zona que Robar (son mutuamente exclusivos)
	_pass_btn = Button.new()
	_pass_btn.text = "↷ Pasar Turno"
	_pass_btn.custom_minimum_size = Vector2(0, 60)
	_pass_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_pass_btn.anchor_left = 0.5
	_pass_btn.anchor_right = 0.5
	_pass_btn.anchor_top = 1.0
	_pass_btn.anchor_bottom = 1.0
	# Misma zona que Robar (nunca se muestran simultáneamente)
	_pass_btn.offset_left = -130
	_pass_btn.offset_right = 130
	_pass_btn.offset_top = -380
	_pass_btn.offset_bottom = -320
	_pass_btn.pivot_offset = Vector2(130, 30)
	_pass_btn.add_theme_font_size_override("font_size", 22)
	_pass_btn.pressed.connect(func(): pass_requested.emit())
	_setup_button_bounce(_pass_btn)
	_pass_btn.visible = false
	_root.add_child(_pass_btn)


# -------------------------------------------------------------------------
# 5. VOLUNTARY HELP / JOKER BUTTON (Salvavidas / Comodín bajo demanda)
# -------------------------------------------------------------------------
func _build_help_button() -> void:
	_help_btn = Button.new()
	_help_btn.text = "🛟 Ayuda"
	_help_btn.custom_minimum_size = Vector2(0, 60)
	_help_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_help_btn.anchor_left = 1.0
	_help_btn.anchor_right = 1.0
	_help_btn.anchor_top = 1.0
	_help_btn.anchor_bottom = 1.0
	_help_btn.offset_left = -160
	_help_btn.offset_right = -12
	_help_btn.offset_top = -252
	_help_btn.offset_bottom = -192
	_help_btn.pivot_offset = Vector2(74, 30)

	var help_style := StyleBoxFlat.new()
	help_style.bg_color = Color(0.22, 0.18, 0.12, 0.9)
	help_style.border_color = COLOR_ACCENT
	help_style.set_border_width_all(2)
	help_style.set_corner_radius_all(22)
	help_style.shadow_color = Color(0, 0, 0, 0.4)
	help_style.shadow_size = 8
	_help_btn.add_theme_stylebox_override("normal", help_style)
	_help_btn.add_theme_color_override("font_color", COLOR_ACCENT)
	_help_btn.add_theme_font_size_override("font_size", 22)

	_help_btn.pressed.connect(func(): help_requested.emit())
	_setup_button_bounce(_help_btn)
	_help_btn.visible = false
	_root.add_child(_help_btn)


func show_help_action(show: bool) -> void:
	if _help_btn != null:
		_help_btn.visible = show
		if show:
			_help_btn.move_to_front()
			if _help_pulse_tween != null and _help_pulse_tween.is_running():
				_help_pulse_tween.kill()
			_help_pulse_tween = create_tween().set_loops()
			_help_pulse_tween.tween_property(_help_btn, "scale", Vector2(1.08, 1.08), 0.45).set_trans(Tween.TRANS_SINE)
			_help_pulse_tween.tween_property(_help_btn, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
		else:
			if _help_pulse_tween != null and _help_pulse_tween.is_running():
				_help_pulse_tween.kill()
			_help_btn.scale = Vector2.ONE


func set_help_button_state(state: String) -> void:
	if _help_pulse_tween != null and _help_pulse_tween.is_running():
		_help_pulse_tween.kill()

	match state:
		"active":
			_help_btn.text = "✦ Comodín Listo"
			_help_btn.disabled = false
			_help_btn.add_theme_color_override("font_color", COLOR_ACTIVE_RING)
			_help_pulse_tween = create_tween().set_loops()
			_help_pulse_tween.tween_property(_help_btn, "scale", Vector2(1.08, 1.08), 0.45).set_trans(Tween.TRANS_SINE)
			_help_pulse_tween.tween_property(_help_btn, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
		"cooldown":
			_help_btn.text = "🛟 Recargando"
			_help_btn.disabled = true
			_help_btn.scale = Vector2.ONE
			_help_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_:
			_help_btn.text = "🛟 Ayuda"
			_help_btn.disabled = false
			_help_btn.scale = Vector2.ONE
			_help_btn.add_theme_color_override("font_color", COLOR_ACCENT)


# -------------------------------------------------------------------------
# 6. CONTEXTUAL SIDE CHOOSER (Empalme en ambos extremos)
# -------------------------------------------------------------------------
func _build_side_choice_bar() -> void:
	_side_choice_bar = Control.new()
	_side_choice_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_side_choice_bar.anchor_left = 0.5
	_side_choice_bar.anchor_right = 0.5
	_side_choice_bar.anchor_top = 1.0
	_side_choice_bar.anchor_bottom = 1.0
	_side_choice_bar.offset_left = -200
	_side_choice_bar.offset_right = 200
	# Zona superior: sobre los botones Robar/Pasar (Y:900-965), a Y:830-900
	_side_choice_bar.offset_top = -450
	_side_choice_bar.offset_bottom = -385
	_side_choice_bar.pivot_offset = Vector2(200, 32)
	_side_choice_bar.visible = false
	_root.add_child(_side_choice_bar)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 16)
	_side_choice_bar.add_child(hbox)

	_side_left_btn = Button.new()
	_side_left_btn.text = "◀ Izquierda"
	_side_left_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side_left_btn.custom_minimum_size = Vector2(0, 56)
	_side_left_btn.add_theme_font_size_override("font_size", 20)
	_side_left_btn.pressed.connect(_on_side_selected.bind("left"))
	_setup_button_bounce(_side_left_btn)
	hbox.add_child(_side_left_btn)

	_side_right_btn = Button.new()
	_side_right_btn.text = "Derecha ▶"
	_side_right_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side_right_btn.custom_minimum_size = Vector2(0, 56)
	_side_right_btn.add_theme_font_size_override("font_size", 20)
	_side_right_btn.pressed.connect(_on_side_selected.bind("right"))
	_setup_button_bounce(_side_right_btn)
	hbox.add_child(_side_right_btn)


func show_side_choice(_tile: Dictionary, left_fruit: String, right_fruit: String) -> void:
	_side_left_btn.text = "◀ %s" % left_fruit
	_side_right_btn.text = "%s ▶" % right_fruit
	_side_choice_bar.visible = true
	_side_choice_bar.scale = Vector2(0.8, 0.8)
	_side_choice_bar.modulate.a = 0.0
	if _side_choice_tween != null and _side_choice_tween.is_running():
		_side_choice_tween.kill()
	_side_choice_tween = create_tween().set_parallel(true)
	_side_choice_tween.tween_property(_side_choice_bar, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_side_choice_tween.tween_property(_side_choice_bar, "modulate:a", 1.0, 0.15)


func hide_side_choice() -> void:
	if not _side_choice_bar.visible:
		return
	if _side_choice_tween != null and _side_choice_tween.is_running():
		_side_choice_tween.kill()
	_side_choice_tween = create_tween().set_parallel(true)
	_side_choice_tween.tween_property(_side_choice_bar, "scale", Vector2(0.8, 0.8), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_side_choice_tween.tween_property(_side_choice_bar, "modulate:a", 0.0, 0.12)
	_side_choice_tween.chain().tween_callback(func(): _side_choice_bar.visible = false)


func _on_side_selected(side: String) -> void:
	hide_side_choice()
	side_chosen.emit(side)


# -------------------------------------------------------------------------
# 7. FLOATING TOAST (Aviso sutil de estado)
# -------------------------------------------------------------------------
func _build_floating_toast() -> void:
	_toast_label = Label.new()
	_toast_label.text = ""
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.anchor_left = 0.5
	_toast_label.anchor_right = 0.5
	_toast_label.offset_left = -260
	_toast_label.offset_right = 260
	# Desplazado abajo del avatar superior (cuyo texto llega a Y~202)
	# para evitar solapamiento: empieza en Y:215
	_toast_label.offset_top = 215
	_toast_label.offset_bottom = 290
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.add_theme_font_size_override("font_size", 18)
	_toast_label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.96))
	_toast_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_toast_label.add_theme_constant_override("shadow_offset_x", 2)
	_toast_label.add_theme_constant_override("shadow_offset_y", 2)
	_toast_label.modulate.a = 0.0
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toast_label)


func set_status(message: String) -> void:
	_toast_label.text = message
	if _toast_tween != null and _toast_tween.is_running():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_label, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(3.0)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.5)


# -------------------------------------------------------------------------
# 8. MODAL PAUSE & OPTIONS MENU
# -------------------------------------------------------------------------
func _build_modal_menu() -> void:
	_modal_overlay = ColorRect.new()
	_modal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_overlay.color = Color(0.06, 0.06, 0.08, 0.8)
	_modal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_overlay.visible = false
	_root.add_child(_modal_overlay)

	_modal_panel = PanelContainer.new()
	_modal_panel.set_anchors_preset(Control.PRESET_CENTER)
	_modal_panel.anchor_left = 0.5
	_modal_panel.anchor_right = 0.5
	_modal_panel.anchor_top = 0.5
	_modal_panel.anchor_bottom = 0.5
	_modal_panel.offset_left = -230
	_modal_panel.offset_right = 230
	_modal_panel.offset_top = -250
	_modal_panel.offset_bottom = 250
	_modal_panel.pivot_offset = Vector2(230, 250)
	_modal_overlay.add_child(_modal_panel)

	var modal_style := StyleBoxFlat.new()
	modal_style.bg_color = Color(0.12, 0.14, 0.18, 0.98)
	modal_style.set_corner_radius_all(24)
	modal_style.border_color = Color(0.3, 0.35, 0.45)
	modal_style.set_border_width_all(2)
	modal_style.shadow_color = Color(0, 0, 0, 0.5)
	modal_style.shadow_size = 24
	modal_style.shadow_offset = Vector2(0, 8)
	modal_style.content_margin_left = 24
	modal_style.content_margin_right = 24
	modal_style.content_margin_top = 22
	modal_style.content_margin_bottom = 22
	_modal_panel.add_theme_stylebox_override("panel", modal_style)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	_modal_panel.add_child(layout)

	# Título
	var title_row := HBoxContainer.new()
	layout.add_child(title_row)

	var title := Label.new()
	title.text = "Pausa"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(46, 46)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.pressed.connect(close_pause_modal)
	_setup_button_bounce(close_btn)
	title_row.add_child(close_btn)

	var sep := HSeparator.new()
	layout.add_child(sep)

	# Modos de juego
	var mode_label := Label.new()
	mode_label.text = "Modo de Juego"
	mode_label.add_theme_font_size_override("font_size", 16)
	layout.add_child(mode_label)

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	layout.add_child(mode_row)

	_create_mode_button(mode_row, "1 vs 1", "local_1v1")
	_create_mode_button(mode_row, "2 vs 2", "local_2v2")
	_create_mode_button(mode_row, "1 vs CPU", "vs_cpu")

	# Acciones
	var resume_btn := Button.new()
	resume_btn.text = "▶ Continuar"
	resume_btn.custom_minimum_size = Vector2(0, 56)
	resume_btn.add_theme_font_size_override("font_size", 22)
	resume_btn.pressed.connect(close_pause_modal)
	_setup_button_bounce(resume_btn)
	layout.add_child(resume_btn)

	var restart_btn := Button.new()
	restart_btn.text = "🔄 Reiniciar Partida"
	restart_btn.custom_minimum_size = Vector2(0, 56)
	restart_btn.add_theme_font_size_override("font_size", 20)
	restart_btn.pressed.connect(func():
		restart_requested.emit()
		close_pause_modal()
	)
	_setup_button_bounce(restart_btn)
	layout.add_child(restart_btn)

	var menu_btn := Button.new()
	menu_btn.text = "🏠 Salir al Menú"
	menu_btn.custom_minimum_size = Vector2(0, 56)
	menu_btn.add_theme_font_size_override("font_size", 20)
	menu_btn.pressed.connect(func():
		menu_requested.emit()
		close_pause_modal()
	)
	_setup_button_bounce(menu_btn)
	layout.add_child(menu_btn)


func _create_mode_button(parent: HBoxContainer, label_text: String, mode_id: String) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 56)
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(func():
		_set_active_mode_ui(mode_id)
		mode_selected.emit(mode_id)
	)
	_setup_button_bounce(btn)
	parent.add_child(btn)
	_mode_buttons[mode_id] = btn


func _set_active_mode_ui(mode_id: String) -> void:
	_current_mode = mode_id
	for m_id in _mode_buttons:
		var btn: Button = _mode_buttons[m_id]
		if m_id == mode_id:
			btn.add_theme_color_override("font_color", COLOR_ACCENT)
		else:
			btn.remove_theme_color_override("font_color")


func open_pause_modal() -> void:
	pause_opened.emit()
	_modal_overlay.visible = true
	_modal_overlay.modulate.a = 0.0
	_modal_panel.scale = Vector2(0.75, 0.75)

	if _modal_tween != null and _modal_tween.is_running():
		_modal_tween.kill()
	_modal_tween = create_tween().set_parallel(true)
	_modal_tween.tween_property(_modal_overlay, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
	_modal_tween.tween_property(_modal_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close_pause_modal() -> void:
	if not _modal_overlay.visible:
		return
	pause_closed.emit()
	if _modal_tween != null and _modal_tween.is_running():
		_modal_tween.kill()
	_modal_tween = create_tween().set_parallel(true)
	_modal_tween.tween_property(_modal_overlay, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_SINE)
	_modal_tween.tween_property(_modal_panel, "scale", Vector2(0.78, 0.78), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_modal_tween.chain().tween_callback(func(): _modal_overlay.visible = false)


# -------------------------------------------------------------------------
# 9. EFFECTS (Confetti & Formula)
# -------------------------------------------------------------------------
func _build_effects() -> void:
	_confetti = CPUParticles2D.new()
	_confetti.emitting = false
	_confetti.one_shot = true
	_confetti.amount = 80
	_confetti.lifetime = 1.2
	_confetti.explosiveness = 0.95
	_confetti.direction = Vector2(0, -1)
	_confetti.spread = 180.0
	_confetti.gravity = Vector2(0, 440)
	_confetti.initial_velocity_min = 140
	_confetti.initial_velocity_max = 380
	_confetti.angular_velocity_min = -320
	_confetti.angular_velocity_max = 320
	_confetti.scale_amount_min = 3.5
	_confetti.scale_amount_max = 7.5

	var color_gradient := Gradient.new()
	color_gradient.set_color(0, Color("#ff5d73"))
	color_gradient.add_point(0.25, Color("#ffd166"))
	color_gradient.add_point(0.5, Color("#61f2d0"))
	color_gradient.add_point(0.75, Color("#9a7bff"))
	color_gradient.set_color(1, Color("#ff8bd1"))

	_confetti.color_ramp = color_gradient
	_confetti.texture = _make_star_texture()
	_confetti.z_index = 100
	add_child(_confetti)

	_formula_label = Label.new()
	_formula_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_formula_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_formula_label.add_theme_font_size_override("font_size", 36)
	_formula_label.add_theme_color_override("font_color", COLOR_ACCENT)
	_formula_label.add_theme_color_override("font_shadow_color", Color("#000000"))
	_formula_label.add_theme_constant_override("shadow_offset_x", 3)
	_formula_label.add_theme_constant_override("shadow_offset_y", 3)
	_formula_label.set_anchors_preset(Control.PRESET_CENTER)
	_formula_label.anchor_left = 0.08
	_formula_label.anchor_right = 0.92
	_formula_label.anchor_top = 0.36
	_formula_label.anchor_bottom = 0.50
	_formula_label.modulate.a = 0.0
	_formula_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_formula_label)


func _make_star_texture() -> Texture2D:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			var dx := absf(x - 7.5)
			var dy := absf(y - 7.5)
			var in_star := dx < 2.0 or dy < 2.0 or absf(dx - dy) < 1.2
			if in_star:
				image.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(image)


func _setup_button_bounce(button: Button) -> void:
	button.pivot_offset = button.custom_minimum_size * 0.5
	button.mouse_entered.connect(_animate_button.bind(button, Vector2(1.06, 1.06)))
	button.mouse_exited.connect(_animate_button.bind(button, Vector2.ONE))
	button.button_down.connect(_animate_button.bind(button, Vector2(0.94, 0.94)))
	button.button_up.connect(_animate_button.bind(button, Vector2.ONE))


func _animate_button(button: Button, target_scale: Vector2) -> void:
	var tween := button.create_tween()
	tween.tween_property(button, "scale", target_scale, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# -------------------------------------------------------------------------
# PUBLIC API (HUD & Game Integration)
# -------------------------------------------------------------------------
func get_hand_container() -> HBoxContainer:
	return _hand_row


func get_ui_theme() -> Theme:
	return _theme


func update_hud(
	lives: int,
	max_lives: int,
	_coins: int,
	_stars: int,
	player_scores: Array,
	_team_scores: Array,
	current_player: int,
	mode_name: String,
	_joker_available: bool,
	hands: Array = []
) -> void:
	# Vidas flotantes
	_lives_label.text = "♥ ".repeat(clampi(lives, 0, max_lives)).strip_edges()
	if lives <= 0:
		_lives_label.text = "SIN VIDAS"

	_turn_info_label.text = "%s  ·  Meta: %d pts" % [mode_name, GameEconomy.target_score]

	# Configurar visibilidad y datos de Avatares según el modo
	var is_2v2 := mode_name == "2 vs 2 Local"
	_avatar_nodes["left"].visible = is_2v2
	_avatar_nodes["right"].visible = is_2v2

	var player_labels := ["Tú", "J2", "J3", "J4"]
	if mode_name == "1 vs CPU":
		player_labels[1] = "CPU"

	# Mapeo de avatares:
	# Bottom = Jugador 0 (Tú)
	# Top = Jugador 1 (en 1v1) o Jugador 2 (en 2v2)
	# Left = Jugador 1 (en 2v2)
	# Right = Jugador 3 (en 2v2)
	_update_avatar_data("bottom", 0, player_labels[0], player_scores, hands, current_player == 0)

	if is_2v2:
		_update_avatar_data("left", 1, player_labels[1], player_scores, hands, current_player == 1)
		_update_avatar_data("top", 2, player_labels[2], player_scores, hands, current_player == 2)
		_update_avatar_data("right", 3, player_labels[3], player_scores, hands, current_player == 3)
	else:
		_update_avatar_data("top", 1, player_labels[1], player_scores, hands, current_player == 1)


func _update_avatar_data(
	avatar_key: String,
	player_index: int,
	p_name: String,
	scores: Array,
	hands: Array,
	is_active_turn: bool
) -> void:
	var node: Control = _avatar_nodes.get(avatar_key)
	if node == null:
		return

	var name_lbl: Label = node.get_meta("name_lbl")
	var score_lbl: Label = node.get_meta("score_lbl")
	var tiles_badge: Label = node.get_meta("tiles_badge")
	var circle_style: StyleBoxFlat = node.get_meta("circle_style")

	name_lbl.text = p_name
	var score_val := int(scores[player_index]) if player_index < scores.size() else 0
	score_lbl.text = "%d pts" % score_val

	if player_index < hands.size():
		tiles_badge.text = str(hands[player_index].size())

	# Anillo luminoso para el jugador en turno
	if is_active_turn:
		circle_style.border_color = COLOR_ACTIVE_RING
		circle_style.border_width_left = 3
		circle_style.border_width_top = 3
		circle_style.border_width_right = 3
		circle_style.border_width_bottom = 3
		node.scale = Vector2(1.06, 1.06)
	else:
		circle_style.border_color = Color(0.35, 0.40, 0.48)
		circle_style.border_width_left = 2
		circle_style.border_width_top = 2
		circle_style.border_width_right = 2
		circle_style.border_width_bottom = 2
		node.scale = Vector2.ONE


func set_stock_count(count: int) -> void:
	_draw_btn.text = "🀄 Robar (%d)" % count
	_draw_btn.disabled = count <= 0


func set_ends(left_fruit: String, right_fruit: String) -> void:
	if left_fruit.is_empty() or left_fruit == "—":
		_ends_label.text = "Extremos: —"
	else:
		_ends_label.text = "Extremos: %s  |  %s" % [left_fruit, right_fruit]


func show_draw_action(show: bool) -> void:
	_draw_btn.visible = show
	if _draw_pulse_tween != null and _draw_pulse_tween.is_running():
		_draw_pulse_tween.kill()
	if show:
		_draw_pulse_tween = create_tween().set_loops()
		_draw_pulse_tween.tween_property(_draw_btn, "scale", Vector2(1.08, 1.08), 0.45).set_trans(Tween.TRANS_SINE)
		_draw_pulse_tween.tween_property(_draw_btn, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	else:
		_draw_btn.scale = Vector2.ONE


func show_pass_action(show: bool) -> void:
	_pass_btn.visible = show
	if _pass_pulse_tween != null and _pass_pulse_tween.is_running():
		_pass_pulse_tween.kill()
	if show:
		_pass_pulse_tween = create_tween().set_loops()
		_pass_pulse_tween.tween_property(_pass_btn, "scale", Vector2(1.08, 1.08), 0.45).set_trans(Tween.TRANS_SINE)
		_pass_pulse_tween.tween_property(_pass_btn, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	else:
		_pass_btn.scale = Vector2.ONE


func show_points(points: int, screen_position: Vector2) -> void:
	var label := Label.new()
	label.text = "+%d" % points
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", COLOR_ACCENT)
	label.add_theme_color_override("font_shadow_color", Color("#000000"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.position = screen_position
	label.size = Vector2(120, 44)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", screen_position.y - 80, 0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.75).set_delay(0.1)
	tween.finished.connect(label.queue_free)


func show_joker_formula(formula: String) -> void:
	_formula_label.text = "✦ COMODÍN COMBINATORIO ✦\n%s" % formula
	_formula_label.scale = Vector2(0.7, 0.7)
	_formula_label.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_formula_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_formula_label, "modulate:a", 1.0, 0.2)
	tween.chain().tween_property(_formula_label, "modulate:a", 0.0, 0.3).set_delay(1.0)
	play_celebration()


func play_celebration(screen_position: Vector2 = Vector2.ZERO) -> void:
	_confetti.position = screen_position
	if screen_position == Vector2.ZERO:
		_confetti.position = get_viewport().get_visible_rect().size * 0.5
	_confetti.restart()
	_confetti.emitting = true


func transition_environment(env: String) -> void:
	var is_board := (env == "board")
	# Modo oscuro: negro-azul profundo con neón cian
	# Modo tropical: verde selva oscuro con neón verde eléctrico
	var bg_color   := Color("#0D0D1A") if is_board else Color("#0A2A14")
	var accent_color := Color("#00f5ff") if is_board else Color("#39ff7a")

	var bg: ColorRect = _root.get_node_or_null("../../BackgroundLayer/BackgroundRect")
	if bg == null and get_parent() != null:
		bg = get_parent().get_node_or_null("BackgroundLayer/BackgroundRect")
	if bg == null:
		bg = get_tree().root.find_child("BackgroundRect", true, false)

	if bg != null:
		var tween := create_tween()
		tween.tween_property(bg, "color", bg_color, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if _theme != null:
		_theme.set_color("font_hover_color", "Button", accent_color)

	if _help_btn != null:
		_help_btn.add_theme_color_override("font_color", accent_color)
		var help_style := StyleBoxFlat.new()
		help_style.bg_color = Color(0.12, 0.14, 0.18, 0.9) if is_board else Color(0.15, 0.22, 0.18, 0.9)
		help_style.border_color = accent_color
		help_style.set_border_width_all(2)
		help_style.set_corner_radius_all(22)
		help_style.shadow_color = Color(0, 0, 0, 0.4)
		help_style.shadow_size = 8
		_help_btn.add_theme_stylebox_override("normal", help_style)

	if _pass_btn != null:
		_pass_btn.add_theme_color_override("font_hover_color", accent_color)
		var pass_style := StyleBoxFlat.new()
		pass_style.bg_color = Color(0.18, 0.20, 0.24, 0.9) if is_board else Color(0.18, 0.24, 0.20, 0.9)
		pass_style.border_color = accent_color
		pass_style.set_border_width_all(2)
		pass_style.set_corner_radius_all(18)
		pass_style.shadow_color = Color(0, 0, 0, 0.4)
		pass_style.shadow_size = 6
		_pass_btn.add_theme_stylebox_override("normal", pass_style)

	if _draw_btn != null:
		_draw_btn.add_theme_color_override("font_hover_color", accent_color)
		var draw_style := StyleBoxFlat.new()
		draw_style.bg_color = Color(0.18, 0.20, 0.24, 0.9) if is_board else Color(0.18, 0.24, 0.20, 0.9)
		draw_style.border_color = accent_color
		draw_style.set_border_width_all(2)
		draw_style.set_corner_radius_all(18)
		draw_style.shadow_color = Color(0, 0, 0, 0.4)
		draw_style.shadow_size = 6
		_draw_btn.add_theme_stylebox_override("normal", draw_style)


func show_victory_screen(winner_text: String) -> void:
	play_celebration()

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.98)
	style.border_color = COLOR_ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 16
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "🏆 ¡PARTIDA FINALIZADA! 🏆"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	vbox.add_child(title_lbl)

	var msg_lbl := Label.new()
	msg_lbl.text = winner_text
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_lbl.add_theme_font_size_override("font_size", 20)
	msg_lbl.add_theme_color_override("font_color", Color("#ffffff"))
	vbox.add_child(msg_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var repeat_btn := Button.new()
	repeat_btn.text = "🔄 Repetir"
	repeat_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	repeat_btn.custom_minimum_size = Vector2(0, 56)
	repeat_btn.add_theme_font_size_override("font_size", 20)
	repeat_btn.pressed.connect(func():
		overlay.queue_free()
		restart_requested.emit()
	)
	_setup_button_bounce(repeat_btn)
	btn_row.add_child(repeat_btn)

	var menu_btn := Button.new()
	menu_btn.text = "🏠 Menú"
	menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_btn.custom_minimum_size = Vector2(0, 56)
	menu_btn.add_theme_font_size_override("font_size", 20)
	menu_btn.pressed.connect(func():
		overlay.queue_free()
		menu_requested.emit()
	)
	_setup_button_bounce(menu_btn)
	btn_row.add_child(menu_btn)

	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = Vector2(240, 150)
	panel.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
