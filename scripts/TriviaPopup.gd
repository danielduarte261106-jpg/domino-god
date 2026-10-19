extends Control

signal answered(correct: bool)
signal combinatorics_correct

const UNIT_III_TIME_LIMIT := 20.0

var _question: Dictionary = {}
var _card: PanelContainer
var _question_label: Label
var _choices_box: VBoxContainer
var _feedback_label: Label
var _timer_bar: ProgressBar
var _timer: Timer
var _answered := false
var _timer_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_interface()
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_expired)
	add_child(_timer)
	visible = false


func show_question(question: Dictionary) -> void:
	_question = question
	_answered = false
	_question_label.text = str(question.get("prompt", "Responde la pregunta para recuperar una vida."))
	_feedback_label.text = ""
	var category: String = str(question.get("category", ""))
	var timed_question: bool = category == "unit_iii" or category == "combinatorics"
	_timer_bar.visible = timed_question
	_timer.stop()
	if _timer_tween != null and _timer_tween.is_running():
		_timer_tween.kill()
	if timed_question:
		_timer_bar.value = 100.0
		_timer.start(UNIT_III_TIME_LIMIT)
		_timer_tween = create_tween()
		_timer_tween.tween_property(_timer_bar, "value", 0.0, UNIT_III_TIME_LIMIT).set_trans(Tween.TRANS_LINEAR)
	for child in _choices_box.get_children():
		child.queue_free()
	for choice in question.get("choices", []):
		var button := Button.new()
		button.text = str(choice)
		button.custom_minimum_size = Vector2(0, 60)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(func(): _submit(str(choice), false, button))
		_choices_box.add_child(button)
	visible = true
	await get_tree().process_frame
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.78, 0.78)
	_card.modulate.a = 0.0
	move_to_front()
	var entrance := create_tween().set_parallel(true)
	entrance.tween_property(_card, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	entrance.tween_property(_card, "modulate:a", 1.0, 0.2)


func _build_interface() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.08, 0.06, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(580, 0)
	center.add_child(_card)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	_card.add_child(layout)

	var heading := Label.new()
	heading.text = "Trivia CombiFrutas"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 34)
	layout.add_child(heading)

	_question_label = Label.new()
	_question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_question_label.custom_minimum_size = Vector2(520, 90)
	_question_label.add_theme_font_size_override("font_size", 22)
	layout.add_child(_question_label)

	_timer_bar = ProgressBar.new()
	_timer_bar.min_value = 0
	_timer_bar.max_value = 100
	_timer_bar.value = 100
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size = Vector2(0, 18)
	layout.add_child(_timer_bar)

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 10)
	layout.add_child(_choices_box)

	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(_feedback_label)


func _submit(choice: String, timed_out: bool = false, pressed_button: Button = null) -> void:
	if _answered:
		return
	_answered = true
	_timer.stop()
	if _timer_tween != null and _timer_tween.is_running():
		_timer_tween.kill()

	var correct := TriviaManager.resolve_answer(_question, choice)
	var expected_answer: String = str(_question.get("answer", "")).strip_edges().to_lower()

	# Deshabilitar botones para evitar clics múltiples
	for child in _choices_box.get_children():
		if child is Button:
			child.disabled = true

	if correct:
		# Opción correcta seleccionada: marcar en verde directamente
		for child in _choices_box.get_children():
			if child is Button and child.text.strip_edges().to_lower() == expected_answer:
				var green_style := StyleBoxFlat.new()
				green_style.bg_color = Color("#2ecc71")
				green_style.set_corner_radius_all(14)
				child.add_theme_stylebox_override("normal", green_style)
				child.add_theme_stylebox_override("disabled", green_style)
				child.add_theme_color_override("font_color", Color.WHITE)
				child.add_theme_color_override("font_disabled_color", Color.WHITE)
		_feedback_label.text = "¡Correcto!"
		_feedback_label.add_theme_color_override("font_color", Color("#2ecc71"))
		var category: String = str(_question.get("category", ""))
		if category == "combinatorics":
			combinatorics_correct.emit()
		await get_tree().create_timer(1.2).timeout
	else:
		# Opción incorrecta: marcar primero la opción elegida en rojo
		for child in _choices_box.get_children():
			if child is Button:
				var is_chosen: bool = (child == pressed_button) or (pressed_button == null and child.text.strip_edges().to_lower() == choice.strip_edges().to_lower())
				if is_chosen:
					var red_style := StyleBoxFlat.new()
					red_style.bg_color = Color("#e74c3c")
					red_style.set_corner_radius_all(14)
					child.add_theme_stylebox_override("normal", red_style)
					child.add_theme_stylebox_override("disabled", red_style)
					child.add_theme_color_override("font_color", Color.WHITE)
					child.add_theme_color_override("font_disabled_color", Color.WHITE)
		_feedback_label.text = "¡Incorrecto!"
		_feedback_label.add_theme_color_override("font_color", Color("#e74c3c"))

		# Pequeña pausa y luego señalar en verde la opción correcta
		await get_tree().create_timer(0.4).timeout
		for child in _choices_box.get_children():
			if child is Button and child.text.strip_edges().to_lower() == expected_answer:
				var green_style := StyleBoxFlat.new()
				green_style.bg_color = Color("#2ecc71")
				green_style.set_corner_radius_all(14)
				child.add_theme_stylebox_override("normal", green_style)
				child.add_theme_stylebox_override("disabled", green_style)
				child.add_theme_color_override("font_color", Color.WHITE)
				child.add_theme_color_override("font_disabled_color", Color.WHITE)

		await get_tree().create_timer(1.2).timeout

	visible = false
	answered.emit(correct)


func _on_timer_expired() -> void:
	if not _answered:
		_submit("", true, null)
