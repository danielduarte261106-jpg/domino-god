extends Control

signal combinatorial_joker_played(fruit_count: int, formula: String)

const TILE_SCENE: PackedScene = preload("res://scenes/FruitTile.tscn")
const TRIVIA_SCENE: PackedScene = preload("res://scenes/TriviaPopup.tscn")
const UI_MANAGER_SCRIPT: Script = preload("res://scripts/UIManager.gd")
const FRUIT_NAMES: Array[String] = ["Manzana", "Banana", "Cereza", "Fresa", "Naranja", "Pera", "Uva"]
const FRUIT_POINTS: Dictionary = {
	0: 1, # Manzana
	1: 2, # Banana
	2: 3, # Cereza
	3: 4, # Fresa
	4: 5, # Naranja
	5: 6, # Pera
	6: 7  # Uva
}
const STARTING_HAND_SIZE := 7

const TILE_LENGTH := 152.0
const TILE_WIDTH := 76.0
const TILE_GAP := 6.0
const BOARD_LIMIT_X := 360.0
const ROW_SPACING := 184.0

var all_tiles: Array[Dictionary] = []
var hands: Array = []
var stock: Array[Dictionary] = []
var played_tiles: Array[Dictionary] = []
var board_placements: Array[Dictionary] = []
var left_tip_position := Vector2.ZERO
var right_tip_position := Vector2.ZERO
var left_direction := Vector2.LEFT
var right_direction := Vector2.RIGHT
var player_scores: Array[int] = []
var team_scores: Array[int] = [0, 0]
var fruit_textures: Array[Texture2D] = []
var game_mode: String = "local_1v1"
var player_count: int = 2
var current_player: int = 0
var left_end: int = -1
var right_end: int = -1
var selected_tile_id: int = -1
var joker_available := true
var joker_active := false
var game_finished := false
var ai_busy := false
var placement_pending := false
var consecutive_passes := 0
var round_generation := 0
var _camera: Camera2D
var _board_layer: Node2D
var _background_layer: CanvasLayer
var _ui_layer: CanvasLayer
var _ui_manager: CanvasLayer
var _environment_tween: Tween
var _camera_tween: Tween
var _background_overlay: ColorRect
var _current_environment := "garden"
var _background: ColorRect
var _environment_label: Label
var _lives_label: Label
var _inventory_label: Label
var _score_label: Label
var _status_label: Label
var _ends_label: Label
var _turn_label: Label
var _hand_title: Label
var _hand_row: HBoxContainer
var _trivia_popup: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameEconomy.start_game()
	if "selected_mode" in GameEconomy:
		game_mode = GameEconomy.selected_mode
	if "selected_environment" in GameEconomy:
		_current_environment = GameEconomy.selected_environment
	_build_interface()
	_load_fruit_textures()
	_start_round()
	_ui_manager.transition_environment(_current_environment)
	GameEconomy.economy_changed.connect(_update_hud)
	_update_hud()


func _build_interface() -> void:
	_camera = get_node("Camera2D")
	_board_layer = get_node("BoardWorld")
	_camera.position = get_viewport_rect().size * Vector2(0.5, 0.44)
	_board_layer.position = _camera.position
	_camera.enabled = true

	_background_layer = CanvasLayer.new()
	_background_layer.name = "BackgroundLayer"
	_background_layer.layer = -1
	add_child(_background_layer)
	_ui_manager = UI_MANAGER_SCRIPT.new()
	add_child(_ui_manager)

	_hand_row = _ui_manager.get_hand_container()

	_ui_manager.help_requested.connect(_on_help_requested)
	_ui_manager.draw_requested.connect(_draw_tile)
	_ui_manager.pass_requested.connect(_pass_turn)
	_ui_manager.side_chosen.connect(_on_side_chosen)
	_ui_manager.restart_requested.connect(_start_round)
	_ui_manager.menu_requested.connect(_go_to_menu)
	_ui_manager.mode_selected.connect(_set_game_mode)
	combinatorial_joker_played.connect(_on_combinatorial_joker_played)

	_background = ColorRect.new()
	_background.name = "BackgroundRect"
	_background.color = Color("#1E1E1E")
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background_layer.add_child(_background)
	_background_overlay = ColorRect.new()
	_background_overlay.color = Color("#121212")
	_background_overlay.modulate.a = 0.0
	_background_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background_layer.add_child(_background_overlay)

	_trivia_popup = TRIVIA_SCENE.instantiate()
	_trivia_popup.theme = _ui_manager.call("get_ui_theme") as Theme
	_trivia_popup.answered.connect(_on_trivia_answered)
	_trivia_popup.combinatorics_correct.connect(_on_combinatorics_correct)
	_ui_manager.add_child(_trivia_popup)


func _add_button_feedback(node: Node) -> void:
	if node is Button and not node is DominoPiece:
		var button := node as Button
		button.pivot_offset = button.custom_minimum_size * 0.5
		button.mouse_entered.connect(_animate_button.bind(button, Vector2(1.035, 1.035)))
		button.mouse_exited.connect(_animate_button.bind(button, Vector2.ONE))
	for child in node.get_children():
		_add_button_feedback(child)


func _animate_button(button: Button, target_scale: Vector2) -> void:
	var tween := button.create_tween()
	tween.tween_property(button, "scale", target_scale, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _load_fruit_textures() -> void:
	fruit_textures.resize(FRUIT_NAMES.size())
	var desktop_fruit_dir := OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP).path_join("frutas")
	var desktop_files := _image_files(desktop_fruit_dir)
	if not desktop_files.is_empty():
		_assign_texture_files(desktop_files, true)
	else:
		var bundled_files := _image_files("res://assets/frutas")
		if not bundled_files.is_empty():
			_assign_texture_files(bundled_files, false)
		else:
			push_warning("No se encontraron imágenes de frutas. Se mostrarán los nombres como alternativa.")


func _image_files(directory_path: String) -> Array[String]:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return []
	var files: Array[String] = []
	for file_name in directory.get_files():
		var extension := file_name.get_extension().to_lower()
		if extension in ["png", "jpg", "jpeg", "webp"]:
			files.append(directory_path.path_join(file_name))
	files.sort()
	return files


func _assign_texture_files(files: Array[String], from_filesystem: bool) -> void:
	var assigned := 0
	for file_path in files:
		var fruit_index := _fruit_index_for_file(file_path.get_file().get_basename())
		if fruit_index < 0:
			fruit_index = assigned
		if fruit_index >= FRUIT_NAMES.size() or fruit_textures[fruit_index] != null:
			continue
		var texture: Texture2D
		if from_filesystem:
			var image := Image.new()
			var error := image.load(file_path)
			if error != OK:
				push_warning("No se pudo cargar la imagen de fruta: %s" % file_path)
				continue
			texture = ImageTexture.create_from_image(image)
		else:
			var loaded_resource := ResourceLoader.load(file_path) as Texture2D
			if loaded_resource == null:
				push_warning("El recurso no es una textura válida: %s" % file_path)
				continue
			texture = loaded_resource
		fruit_textures[fruit_index] = texture
		assigned += 1


func _fruit_index_for_file(file_stem: String) -> int:
	var normalized_stem := file_stem.to_lower()
	for index in range(FRUIT_NAMES.size()):
		if normalized_stem.contains(FRUIT_NAMES[index].to_lower()):
			return index
	return -1


func _start_round(reset_scores: bool = true) -> void:
	GameEconomy.start_game()
	round_generation += 1
	ai_busy = false
	placement_pending = false
	if game_mode == "local_2v2":
		player_count = 4
	else:
		player_count = 2
	_build_domino_set()
	all_tiles.shuffle()
	hands.clear()
	if reset_scores or player_scores.size() != player_count:
		player_scores.clear()
		for player_index in range(player_count):
			player_scores.append(0)
		team_scores = [0, 0]
	for player_index in range(player_count):
		hands.append([])
	stock.clear()
	played_tiles.clear()
	board_placements.clear()
	left_tip_position = Vector2.ZERO
	right_tip_position = Vector2.ZERO
	left_direction = Vector2.LEFT
	right_direction = Vector2.RIGHT
	current_player = 0
	consecutive_passes = 0
	left_end = -1
	right_end = -1
	selected_tile_id = -1
	joker_available = true
	joker_active = false
	game_finished = false
	var tile_index := 0
	for player_index in range(player_count):
		for _tile_in_hand in range(STARTING_HAND_SIZE):
			if tile_index >= all_tiles.size():
				break
			hands[player_index].append(all_tiles[tile_index])
			tile_index += 1
	for remaining_index in range(tile_index, all_tiles.size()):
		stock.append(all_tiles[remaining_index])
	_set_status("Primera jugada: puedes abrir con cualquier ficha.")
	_refresh_board()
	_refresh_hand(true)
	_update_hud()
	_schedule_cpu_turn()


func _set_game_mode(selected_mode: String) -> void:
	if selected_mode not in ["local_1v1", "local_2v2", "vs_cpu"]:
		push_error("Modo de juego desconocido: %s" % selected_mode)
		return
	game_mode = selected_mode
	_start_round()


func _build_domino_set() -> void:
	all_tiles.clear()
	var tile_id := 0
	for first_fruit in range(FRUIT_NAMES.size()):
		for second_fruit in range(first_fruit, FRUIT_NAMES.size()):
			all_tiles.append({
				"id": tile_id,
				"a": first_fruit,
				"b": second_fruit
			})
			tile_id += 1
	assert(all_tiles.size() == 28, "El dominó doble-seis debe contener exactamente 28 fichas.")


func _can_place_tile(tile: Dictionary, side: String = "") -> bool:
	if joker_active:
		return true
	if played_tiles.is_empty():
		return true
	var first: int = int(tile["a"])
	var second: int = int(tile["b"])
	if side == "left":
		return first == left_end or second == left_end
	elif side == "right":
		return first == right_end or second == right_end
	return (first == left_end or second == left_end or first == right_end or second == right_end)


func _attempt_place(side: String) -> void:
	if game_finished or ai_busy or placement_pending:
		return
	if selected_tile_id < 0:
		_set_status("Primero selecciona una ficha de tu mano.")
		return
	var tile := _find_hand_tile(selected_tile_id)
	if tile.is_empty():
		_set_status("La ficha seleccionada ya no está en tu mano.")
		return
	if played_tiles.is_empty():
		_place_tile(tile, side, int(tile["a"]), int(tile["b"]))
		return

	if not _can_place_tile(tile, side):
		_on_invalid_move()
		return

	var target_end: int = left_end if side == "left" else right_end
	var first: int = int(tile["a"])
	var second: int = int(tile["b"])

	if joker_active:
		joker_active = false
		_place_tile(tile, side, target_end, second if first == target_end else first, true)
		return

	if first == target_end:
		_place_tile(tile, side, first, second)
	elif second == target_end:
		_place_tile(tile, side, second, first)
	else:
		_on_invalid_move()


func _place_tile(
	tile: Dictionary,
	side: String,
	attached_fruit: int,
	exposed_fruit: int,
	uses_joker: bool = false
) -> void:
	var player_hand: Array = hands[current_player]
	var available_fruits_before_play := _available_fruit_count()
	var points_gained := _tile_points(tile)
	var scoring_team := current_player % 2
	player_hand.erase(tile)
	played_tiles.append(tile)
	selected_tile_id = -1

	_place_tile_on_board(tile, side, attached_fruit, exposed_fruit)

	if played_tiles.size() == 1:
		left_end = int(tile["a"])
		right_end = int(tile["b"])
	elif side == "left":
		left_end = exposed_fruit
	else:
		right_end = exposed_fruit
	joker_active = false
	player_scores[current_player] += points_gained
	team_scores[scoring_team] += points_gained
	if uses_joker:
		joker_available = false
		var possible_combinations := available_fruits_before_play * (available_fruits_before_play - 1) / 2
		_set_status("Comodín: C(%d, 2) = %d parejas justifican la jugada." % [
			available_fruits_before_play,
			possible_combinations
		])
	else:
		_set_status("Conectaste %s - %s y sumaste %d puntos frutales." % [
		FRUIT_NAMES[attached_fruit],
		FRUIT_NAMES[exposed_fruit],
		points_gained
		])
	_refresh_board()
	_refresh_hand()
	_update_hud()
	_ui_manager.show_points(points_gained, get_viewport_rect().size * 0.5 + Vector2(0, 70))
	if player_hand.is_empty():
		_end_round(scoring_team, 0, false)
		return
	_advance_turn()


func _place_tile_on_board(
	tile: Dictionary,
	side: String,
	attached_fruit: int,
	exposed_fruit: int
) -> void:
	var is_double: bool = (tile["a"] == tile["b"])

	# CASO 1: Primera ficha del juego en el origen central (Vector2.ZERO de BoardWorld)
	if board_placements.is_empty():
		var center_pos := Vector2.ZERO
		var rot := (PI * 0.5) if is_double else 0.0

		left_direction = Vector2.LEFT
		right_direction = Vector2.RIGHT

		if is_double:
			left_tip_position = Vector2(-TILE_WIDTH * 0.5, 0.0)
			right_tip_position = Vector2(TILE_WIDTH * 0.5, 0.0)
		else:
			left_tip_position = Vector2(-TILE_LENGTH * 0.5, 0.0)
			right_tip_position = Vector2(TILE_LENGTH * 0.5, 0.0)

		board_placements.append({
			"tile": tile,
			"position": center_pos,
			"rotation": rot,
			"first_fruit": int(tile["a"]),
			"second_fruit": int(tile["b"]),
			"is_double": is_double
		})
		return

	# CASO 2: Extensión de la cadena en el extremo izquierdo o derecho
	var is_left := (side == "left")
	var tip := left_tip_position if is_left else right_tip_position
	var dir := left_direction if is_left else right_direction

	# Dimensión de la ficha a lo largo de la dirección actual
	var tile_dim_along_dir := TILE_WIDTH if is_double else TILE_LENGTH
	var far_edge_x := tip.x + dir.x * (TILE_GAP + tile_dim_along_dir)

	# Detección de límite horizontal para curva en U (Snaking)
	var needs_turn := false
	if dir.x < -0.5 and far_edge_x < -BOARD_LIMIT_X:
		needs_turn = true
	elif dir.x > 0.5 and far_edge_x > BOARD_LIMIT_X:
		needs_turn = true

	var center_pos := Vector2.ZERO
	var rot := 0.0
	var f1 := attached_fruit
	var f2 := exposed_fruit

	if needs_turn:
		# Giro en U: extremo izquierdo baja (+Y), extremo derecho sube (-Y)
		var turn_y_dir := 1.0 if is_left else -1.0

		# La ficha se orienta verticalmente para servir de conector entre filas
		rot = (PI * 0.5) if turn_y_dir > 0.0 else (-PI * 0.5)
		if is_double:
			rot = 0.0

		# Ancho en X de la pieza de giro
		var turn_x_span := TILE_LENGTH if is_double else TILE_WIDTH

		# Desplazamiento vertical (Y) = ancho de dos fichas + 16.0 para evitar colisiones
		var vertical_displacement := (TILE_WIDTH * 2.0) + 16.0

		# Posición central en X: contigua al extremo previo respetando TILE_GAP
		center_pos.x = tip.x + dir.x * (TILE_GAP + turn_x_span * 0.5)
		# Posición central en Y: a medio camino entre la fila previa y la nueva fila
		center_pos.y = tip.y + turn_y_dir * (vertical_displacement * 0.5)

		f1 = attached_fruit
		f2 = exposed_fruit

		# Se invierte la dirección de avance horizontal para la nueva fila
		var new_dir := -dir

		# El nuevo extremo (tip) de inicio para la nueva fila horizontal
		# Se ancla en el borde interior de la ficha conectora para asegurar separación TILE_GAP
		var new_tip := Vector2(
			center_pos.x + new_dir.x * (turn_x_span * 0.5),
			tip.y + turn_y_dir * vertical_displacement
		)

		if is_left:
			left_tip_position = new_tip
			left_direction = new_dir
		else:
			right_tip_position = new_tip
			right_direction = new_dir
	else:
		# Avance recto a lo largo del vector director actual
		if is_double:
			# Ficha doble cruzada perpendicularmente
			rot = dir.angle() + (PI * 0.5)
			center_pos = tip + dir * (TILE_GAP + TILE_WIDTH * 0.5)
			var new_tip := tip + dir * (TILE_GAP + TILE_WIDTH)
			if is_left:
				left_tip_position = new_tip
			else:
				right_tip_position = new_tip
		else:
			rot = dir.angle()
			center_pos = tip + dir * (TILE_GAP + TILE_LENGTH * 0.5)
			var new_tip := tip + dir * (TILE_GAP + TILE_LENGTH)
			if is_left:
				left_tip_position = new_tip
			else:
				right_tip_position = new_tip

	board_placements.append({
		"tile": tile,
		"position": center_pos,
		"rotation": rot,
		"first_fruit": f1,
		"second_fruit": f2,
		"is_double": is_double
	})


func _play_combinatorial_joker(
	tile: Dictionary,
	side: String,
	attached_fruit: int,
	exposed_fruit: int
) -> bool:
	placement_pending = true
	var action_round := round_generation
	var action_player := current_player
	var fruit_count := _available_fruit_count()
	combinatorial_joker_played.emit(fruit_count, available_combinations_text(fruit_count))
	await get_tree().create_timer(0.85).timeout
	if action_round != round_generation:
		return false
	placement_pending = false
	if game_finished or action_player != current_player or _find_hand_tile(int(tile["id"])).is_empty():
		return false
	_place_tile(tile, side, attached_fruit, exposed_fruit, true)
	return true


func available_combinations_text(fruit_count: int) -> String:
	return "C(%d, 2) = %d" % [fruit_count, fruit_count * (fruit_count - 1) / 2]


func _tile_points(tile: Dictionary) -> int:
	return int(FRUIT_POINTS.get(int(tile["a"]), 0)) + int(FRUIT_POINTS.get(int(tile["b"]), 0))


func _is_combinatorial_pair(tile: Dictionary) -> bool:
	var first: int = tile["a"]
	var second: int = tile["b"]
	if first == second:
		return false
	var fruit_set: Array[int] = _available_fruits(hands[current_player])
	return fruit_set.size() > 1 and fruit_set.has(first) and fruit_set.has(second)


func _available_fruit_count() -> int:
	return _available_fruits(hands[current_player]).size()


func _available_fruits(player_hand: Array) -> Array[int]:
	var fruit_set: Array[int] = []
	for hand_tile in player_hand:
		for value in [int(hand_tile["a"]), int(hand_tile["b"])]:
			if not fruit_set.has(value):
				fruit_set.append(value)
	for value in [left_end, right_end]:
		if value >= 0 and not fruit_set.has(value):
			fruit_set.append(value)
	return fruit_set


func _activate_joker() -> void:
	if game_finished or ai_busy or placement_pending:
		return
	if not joker_available:
		_set_status("El comodín ya se usó en esta partida.")
		return
	joker_active = not joker_active
	_set_status("Comodín activo: selecciona una ficha distinta y colócala en un extremo." if joker_active else "Comodín desactivado.")


func _draw_tile() -> void:
	if game_finished or ai_busy or placement_pending:
		return
	if stock.is_empty():
		_set_status("El pozo está vacío. Puedes pasar si no tienes jugadas.")
		return
	hands[current_player].append(stock.pop_back())
	_set_status("Robaste una ficha. Fichas restantes: %d. Juega o pasa." % stock.size())
	_refresh_hand()
	_update_hud()


func _pass_turn() -> void:
	if game_finished or ai_busy or placement_pending:
		return
	if _has_legal_move(hands[current_player]):
		_set_status("Tienes una jugada disponible; no puedes pasar.")
		return
	if not stock.is_empty():
		_set_status("Aún quedan fichas en el pozo; roba antes de pasar.")
		return
	_set_status("El jugador %d pasa." % (current_player + 1))
	_advance_turn(true)


func _has_legal_move(player_hand: Array) -> bool:
	if joker_active and not player_hand.is_empty():
		return true
	if player_hand.is_empty():
		return false
	if played_tiles.is_empty():
		return true
	for tile in player_hand:
		var first: int = int(tile["a"])
		var second: int = int(tile["b"])
		if first == left_end or second == left_end or first == right_end or second == right_end:
			return true
	return false


func _advance_turn(passed: bool = false) -> void:
	current_player = (current_player + 1) % player_count
	selected_tile_id = -1
	if passed:
		consecutive_passes += 1
	else:
		consecutive_passes = 0
	if consecutive_passes >= player_count:
		_finish_blocked_round()
		return
	_refresh_hand()
	_update_hud()
	_schedule_cpu_turn()


func _finish_blocked_round() -> void:
	var remaining_by_team: Array[int] = [0, 0]
	for player_index in range(player_count):
		for tile in hands[player_index]:
			remaining_by_team[player_index % 2] += _tile_points(tile)
	var winning_team: int = 0 if remaining_by_team[0] <= remaining_by_team[1] else 1
	var bonus_points: int = remaining_by_team[1 - winning_team]
	_end_round(winning_team, bonus_points, true)


func _end_round(winning_team: int, bonus_points: int = 0, is_blocked: bool = false) -> void:
	if bonus_points > 0:
		team_scores[winning_team] += bonus_points
		player_scores[winning_team] += bonus_points
		_update_hud()

	var target: int = GameEconomy.target_score
	if team_scores[0] >= target or team_scores[1] >= target:
		game_finished = true
		var final_winner: int = 0 if team_scores[0] >= team_scores[1] else 1
		var winner_msg := "¡Equipo %d gana la partida con %d puntos! (Meta: %d)" % [
			final_winner + 1,
			team_scores[final_winner],
			target
		]
		_set_status(winner_msg)
		if _ui_manager != null and _ui_manager.has_method("show_victory_screen"):
			_ui_manager.show_victory_screen(winner_msg)
		else:
			_ui_manager.play_celebration()
		if final_winner == 0:
			GameEconomy.award_match()
	else:
		if is_blocked:
			_set_status("Ronda bloqueada. Equipo %d suma %d pts. Marcador: [%d - %d] / Meta: %d" % [
				winning_team + 1,
				bonus_points,
				team_scores[0],
				team_scores[1],
				target
			])
		else:
			_set_status("Ronda finalizada. Equipo %d dominó. Marcador: [%d - %d] / Meta: %d" % [
				winning_team + 1,
				team_scores[0],
				team_scores[1],
				target
			])
		await get_tree().create_timer(2.0).timeout
		if not game_finished:
			_start_round(false)


func _schedule_cpu_turn() -> void:
	if game_mode == "vs_cpu" and current_player == 1 and not game_finished:
		call_deferred("_run_cpu_turn")


func _run_cpu_turn() -> void:
	if ai_busy or game_finished or game_mode != "vs_cpu" or current_player != 1:
		return
	ai_busy = true
	_refresh_hand()
	_set_status("La CPU está evaluando su mano y los extremos...")
	await get_tree().create_timer(0.65).timeout
	while not game_finished and current_player == 1:
		var cpu_hand: Array = hands[current_player]
		var move: Dictionary = AIManager.choose_best_move(
			cpu_hand,
			left_end,
			right_end,
			played_tiles.is_empty(),
			FRUIT_POINTS,
			joker_available
		)
		if not move.is_empty():
			if bool(move["uses_joker"]):
				var joker_placed: bool = await _play_combinatorial_joker(
					move["tile"],
					str(move["side"]),
					int(move["attached_fruit"]),
					int(move["exposed_fruit"])
				)
				ai_busy = false
				if not joker_placed:
					return
			else:
				ai_busy = false
				_place_tile(
					move["tile"],
					str(move["side"]),
					int(move["attached_fruit"]),
					int(move["exposed_fruit"])
				)
			return
		if stock.is_empty():
			ai_busy = false
			_set_status("La CPU no tiene jugadas y pasa.")
			_advance_turn(true)
			return
		cpu_hand.append(stock.pop_back())
		_refresh_hand()
		_update_hud()
		await get_tree().create_timer(0.2).timeout


func _on_invalid_move() -> void:
	joker_active = false
	var player_hand: Array = hands[current_player] if current_player < hands.size() else []
	if not _has_legal_move(player_hand) and stock.is_empty():
		_set_status("Sin jugadas válidas: puedes usar 🛟 Ayuda para obtener un comodín o Pasar Turno.")
		_ui_manager.show_pass_action(true)
		_ui_manager.set_help_button_state("ready")
	else:
		_set_status("Esa ficha no coincide con los extremos del tablero. Usa 🛟 Ayuda si estás bloqueado.")


func _on_help_requested() -> void:
	if game_finished or ai_busy or placement_pending:
		return
	if current_player != 0 and game_mode == "vs_cpu":
		return
	_set_status("Reto Combinatorio: responde antes de que termine el tiempo para ganar el Comodín.")
	var q: Dictionary = TriviaManager.make_combinatorics_question(_hand_fruit_values())
	_trivia_popup.show_question(q)


func _on_trivia_answered(correct: bool) -> void:
	if correct:
		joker_active = true
		joker_available = true
		_ui_manager.set_help_button_state("active")
		_ui_manager.play_celebration()
		_set_status("¡Respuesta correcta! COMODÍN ACTIVO: Esta ronda puedes jugar cualquier ficha de tu mano sin importar el extremo.")
		_update_hud()
	else:
		joker_active = false
		_ui_manager.set_help_button_state("cooldown")
		GameEconomy.lives -= 1
		_set_status("Respuesta incorrecta. Pierdes 1 vida y pasas tu turno.")
		_update_hud()

		if GameEconomy.lives <= 0:
			game_finished = true
			_ui_manager.show_victory_screen("¡Te quedaste sin vidas! El Oponente gana.")
			return

		_advance_turn(true)


func _hand_fruit_values() -> Array[int]:
	var values: Array[int] = []
	for tile in hands[current_player]:
		values.append(int(tile["a"]))
		values.append(int(tile["b"]))
	return values


func _find_hand_tile(tile_id: int) -> Dictionary:
	for tile in hands[current_player]:
		if int(tile["id"]) == tile_id:
			return tile
	return {}


func _refresh_board() -> void:
	for child in _board_layer.get_children():
		_board_layer.remove_child(child)
		child.queue_free()
	_ui_manager.hide_side_choice()
	if board_placements.is_empty():
		_ui_manager.set_ends("—", "—")
	else:
		for placement in board_placements:
			var tile: Dictionary = placement["tile"]
			var tile_view := _make_tile_button(tile, false)
			tile_view.pivot_offset = Vector2(TILE_LENGTH * 0.5, TILE_WIDTH * 0.5)
			tile_view.position = placement["position"] - tile_view.pivot_offset
			tile_view.rotation = placement["rotation"]
			tile_view.set_tile(
				int(placement["first_fruit"]),
				int(placement["second_fruit"]),
				FRUIT_NAMES,
				fruit_textures,
				int(tile["id"])
			)
			_board_layer.add_child(tile_view)
		_ui_manager.set_ends(FRUIT_NAMES[left_end], FRUIT_NAMES[right_end])
	_update_board_camera()


func _refresh_hand(is_deal: bool = false) -> void:
	for child in _hand_row.get_children():
		_hand_row.remove_child(child)
		child.queue_free()
	if game_mode == "vs_cpu" and current_player == 1:
		var hidden_hand := Label.new()
		hidden_hand.text = "%d fichas ocultas" % hands[current_player].size()
		_hand_row.add_child(hidden_hand)
	else:
		var hand_tiles: Array = hands[current_player]
		var count := hand_tiles.size()
		var spacing := 6.0
		# Anchura máxima disponible en el HBoxContainer centrado
		var max_hand_width := 670.0
		# Ancho vertical calculado para que las 7 fichas (o más) quepan exactamente sin scroll
		var tile_width := clampf((max_hand_width - float(maxi(0, count - 1)) * spacing) / maxf(1.0, float(count)), 46.0, 84.0)

		for index in range(count):
			var tile: Dictionary = hand_tiles[index]
			var tile_view := _make_tile_button(tile, true)
			tile_view.set_vertical(true, tile_width)
			tile_view.pressed.connect(_on_hand_tile_clicked.bind(tile))
			_hand_row.add_child(tile_view)
			if is_deal:
				tile_view.animate_deal(index * 0.08)
	_update_hud()


func _on_side_chosen(side: String) -> void:
	_attempt_place(side)


func _on_hand_tile_clicked(tile: Dictionary) -> void:
	if game_finished or ai_busy or placement_pending:
		return
	if game_mode == "vs_cpu" and current_player == 1:
		return

	selected_tile_id = int(tile["id"])
	for child in _hand_row.get_children():
		if child is DominoPiece:
			child.set_selected(child.piece_id == selected_tile_id)

	# Si la mesa está vacía, se puede abrir con cualquier ficha directamente
	if played_tiles.is_empty():
		_attempt_place("left")
		return

	if joker_active:
		_ui_manager.show_side_choice(tile, FRUIT_NAMES[left_end], FRUIT_NAMES[right_end])
		return

	var first: int = int(tile["a"])
	var second: int = int(tile["b"])

	var matches_left: bool = (first == left_end or second == left_end)
	var matches_right: bool = (first == right_end or second == right_end)

	if matches_left and not matches_right:
		_attempt_place("left")
	elif matches_right and not matches_left:
		_attempt_place("right")
	elif matches_left and matches_right:
		# La ficha coincide en ambos extremos: desplegar selector flotante contextual
		_ui_manager.show_side_choice(tile, FRUIT_NAMES[left_end], FRUIT_NAMES[right_end])
	else:
		_on_invalid_move()


func _make_tile_button(tile: Dictionary, selectable: bool) -> DominoPiece:
	var tile_view := TILE_SCENE.instantiate() as DominoPiece
	tile_view.set_tile(int(tile["a"]), int(tile["b"]), FRUIT_NAMES, fruit_textures, int(tile["id"]))
	tile_view.set_interaction(_camera, selectable)
	if selectable:
		tile_view.set_selected(int(tile["id"]) == selected_tile_id)
		tile_view.drag_started.connect(_on_piece_drag_started)
		tile_view.drag_dropped.connect(_on_piece_drag_dropped)
	return tile_view


func _on_piece_drag_started(tile_id: int) -> void:
	if game_finished or placement_pending or ai_busy:
		return
	selected_tile_id = tile_id
	for child in _hand_row.get_children():
		if child is DominoPiece:
			child.set_selected(child.piece_id == tile_id)


func _on_piece_drag_dropped(tile_id: int, world_position: Vector2) -> void:
	if game_finished or ai_busy or placement_pending:
		return
	selected_tile_id = tile_id
	if board_placements.is_empty():
		_attempt_place("left")
		return

	var global_left_tip := _board_layer.to_global(left_tip_position)
	var global_right_tip := _board_layer.to_global(right_tip_position)

	var dist_left := world_position.distance_to(global_left_tip)
	var dist_right := world_position.distance_to(global_right_tip)

	var min_dist := minf(dist_left, dist_right)
	# Umbral en píxeles ajustado por el zoom de la cámara
	if min_dist * _camera.zoom.x > 380.0:
		_set_status("Suelta la ficha cerca de uno de los extremos de la cadena.")
		return

	var side := "left" if dist_left < dist_right else "right"
	_attempt_place(side)


func _update_board_camera() -> void:
	if board_placements.is_empty():
		var viewport_size := get_viewport_rect().size
		var default_center := viewport_size * Vector2(0.5, 0.44)
		if _camera_tween != null and _camera_tween.is_running():
			_camera_tween.kill()
		_camera_tween = create_tween().set_parallel(true)
		_camera_tween.tween_property(_camera, "global_position", default_center, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_camera_tween.tween_property(_camera, "zoom", Vector2.ONE, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		return

	var min_coord := Vector2(INF, INF)
	var max_coord := Vector2(-INF, -INF)
	var half_len := TILE_LENGTH * 0.5
	var half_wid := TILE_WIDTH * 0.5

	# Cálculo exacto del AABB abarcando cada ficha con su rotación real
	for placement in board_placements:
		var pos: Vector2 = placement["position"]
		var rot: float = float(placement["rotation"])
		var extent_x := absf(half_len * cos(rot)) + absf(half_wid * sin(rot))
		var extent_y := absf(half_len * sin(rot)) + absf(half_wid * cos(rot))
		min_coord.x = minf(min_coord.x, pos.x - extent_x)
		min_coord.y = minf(min_coord.y, pos.y - extent_y)
		max_coord.x = maxf(max_coord.x, pos.x + extent_x)
		max_coord.y = maxf(max_coord.y, pos.y + extent_y)

	var board_rect := Rect2(min_coord, max_coord - min_coord)
	var board_center_global := _board_layer.to_global(board_rect.get_center())

	var padding := 60.0
	var total_width := board_rect.size.x + padding * 2.0
	var total_height := board_rect.size.y + padding * 2.0

	# Área segura en modo Portrait (720x1280) entre Top HUD y Bottom Hand
	var safe_width := 640.0
	var safe_height := 720.0

	var zoom_x := safe_width / maxf(total_width, 1.0)
	var zoom_y := safe_height / maxf(total_height, 1.0)
	var zoom_factor := clampf(minf(zoom_x, zoom_y), 0.32, 1.0)
	var target_zoom := Vector2(zoom_factor, zoom_factor)

	# Compensación para centrar visualmente dentro de la zona de juego despejada
	var target_camera_pos := board_center_global + Vector2(0.0, 50.0)

	if _camera_tween != null and _camera_tween.is_running():
		_camera_tween.kill()
	_camera_tween = create_tween().set_parallel(true)
	_camera_tween.tween_property(_camera, "global_position", target_camera_pos, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(_camera, "zoom", target_zoom, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _select_tile(tile_id: int) -> void:
	if game_finished:
		return
	selected_tile_id = tile_id
	_refresh_hand()


func _toggle_environment() -> void:
	_current_environment = "board" if _current_environment == "garden" else "garden"
	var is_garden := _current_environment == "garden"
	if _environment_label != null:
		_environment_label.text = "Huerto Tropical" if is_garden else "Pizarrón Matemático"
	_background_overlay.color = Color("#eaf4df") if is_garden else Color("#17243d")
	if _environment_tween != null and _environment_tween.is_running():
		_environment_tween.kill()
	_environment_tween = create_tween()
	_environment_tween.tween_property(_background_overlay, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	_environment_tween.tween_callback(func() -> void:
		_background.color = _background_overlay.color
		_background_overlay.modulate.a = 0.0
	)
	_ui_manager.transition_environment(_current_environment)


func _update_hud() -> void:
	if not is_node_ready() or _ui_manager == null:
		return
	_ui_manager.set_stock_count(stock.size())
	if not hands.is_empty() and current_player < hands.size():
		var can_move: bool = _has_legal_move(hands[current_player])
		var is_human: bool = not (game_mode == "vs_cpu" and current_player == 1)
		_ui_manager.show_draw_action(is_human and not can_move and not stock.is_empty())
		_ui_manager.show_pass_action(is_human and not can_move and stock.is_empty())
		_ui_manager.show_help_action(is_human and not can_move)
		_ui_manager.update_hud(
			GameEconomy.lives,
			GameEconomy.MAX_LIVES,
			GameEconomy.coins,
			GameEconomy.stars,
			player_scores,
			team_scores,
			current_player,
			_mode_display_name(),
			joker_available,
			hands
		)


func _on_combinatorial_joker_played(_fruit_count: int, formula: String) -> void:
	_ui_manager.show_joker_formula(formula)


func _on_combinatorics_correct() -> void:
	_ui_manager.play_celebration()


func _mode_display_name() -> String:
	match game_mode:
		"local_2v2":
			return "2 vs 2 Local"
		"vs_cpu":
			return "1 vs CPU"
		_:
			return "1 vs 1 Local"


func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message
	_ui_manager.set_status(message)


func _go_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
