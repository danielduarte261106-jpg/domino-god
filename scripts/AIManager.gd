class_name AIManager
extends RefCounted


static func choose_best_move(
	player_hand: Array,
	left_end: int,
	right_end: int,
	board_is_empty: bool,
	fruit_points: Dictionary,
	joker_available: bool
) -> Dictionary:
	var legal_moves: Array[Dictionary] = []
	var available_fruits := _available_fruits(player_hand, left_end, right_end)

	for tile in player_hand:
		var first: int = int(tile["a"])
		var second: int = int(tile["b"])
		var score := _tile_score(tile, fruit_points)
		if board_is_empty:
			# Primera ficha: se coloca en el lado izquierdo por convención
			legal_moves.append(_make_move(tile, "left", first, second, false, score))
			continue
		# Lado izquierdo: la fruta que toca el tablero es la que coincide con left_end
		if first == left_end:
			legal_moves.append(_make_move(tile, "left", first, second, false, score))
		elif second == left_end:
			legal_moves.append(_make_move(tile, "left", second, first, false, score))
		# Lado derecho: la fruta que toca el tablero es la que coincide con right_end
		if first == right_end:
			legal_moves.append(_make_move(tile, "right", first, second, false, score))
		elif second == right_end:
			legal_moves.append(_make_move(tile, "right", second, first, false, score))

	if not legal_moves.is_empty():
		legal_moves.sort_custom(_sort_by_score)
		return legal_moves[0]

	if joker_available:
		var possible_pairs := available_fruits.size() * (available_fruits.size() - 1) / 2
		if possible_pairs > 0:
			for tile in player_hand:
				var first: int = int(tile["a"])
				var second: int = int(tile["b"])
				if first == second or not available_fruits.has(first) or not available_fruits.has(second):
					continue
				var side := "right" if right_end >= 0 else "left"
				legal_moves.append(_make_move(
					tile, side, first, second, true, _tile_score(tile, fruit_points)
				))
		if not legal_moves.is_empty():
			legal_moves.sort_custom(_sort_by_score)
			return legal_moves[0]

	return {}


static func _available_fruits(player_hand: Array, left_end: int, right_end: int) -> Array[int]:
	var fruits: Array[int] = []
	for tile in player_hand:
		for fruit in [int(tile["a"]), int(tile["b"])]:
			if not fruits.has(fruit):
				fruits.append(fruit)
	for fruit in [left_end, right_end]:
		if fruit >= 0 and not fruits.has(fruit):
			fruits.append(fruit)
	return fruits


static func _tile_score(tile: Dictionary, fruit_points: Dictionary) -> int:
	return int(fruit_points.get(int(tile["a"]), 0)) + int(fruit_points.get(int(tile["b"]), 0))


static func _make_move(
	tile: Dictionary,
	side: String,
	attached_fruit: int,
	exposed_fruit: int,
	uses_joker: bool,
	score: int
) -> Dictionary:
	return {
		"tile": tile,
		"side": side,
		"attached_fruit": attached_fruit,
		"exposed_fruit": exposed_fruit,
		"uses_joker": uses_joker,
		"score": score
	}


static func _sort_by_score(first_move: Dictionary, second_move: Dictionary) -> bool:
	return int(first_move["score"]) > int(second_move["score"])
