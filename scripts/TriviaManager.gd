extends Node

signal answer_resolved(correct: bool, life_restored: bool)

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func permutations_without_repetition(n: int, r: int) -> int:
	if n < 0 or r < 0 or r > n:
		return 0
	var result := 1
	for offset in range(r):
		result *= n - offset
	return result


func combinations_with_repetition(n: int, r: int) -> int:
	if n <= 0 or r < 0:
		return 0
	if r == 0:
		return 1
	return int(permutations_without_repetition(n + r - 1, r) / factorial(r))


func factorial(value: int) -> int:
	var result := 1
	for factor in range(2, value + 1):
		result *= factor
	return result


func make_question(hand_values: Array[int]) -> Dictionary:
	var question_pool: Array[Dictionary] = [
		{
			"category": "unit_iii",
			"prompt": "Unidad III · Probabilidad: si 3 de 8 resultados equiprobables son favorables, ¿cuál es la probabilidad?",
			"answer": "3/8",
			"choices": ["3/8", "5/8", "3/5", "1/8"]
		},
		{
			"category": "unit_iii",
			"prompt": "Unidad III · Estadística: ¿qué medida representa el valor central de una lista ordenada?",
			"answer": "Mediana",
			"choices": ["Mediana", "Moda", "Rango", "Media"]
		},
		{
			"category": "culture",
			"prompt": "Cultura general: ¿cuál es el planeta más grande del sistema solar?",
			"answer": "Júpiter",
			"choices": ["Júpiter", "Marte", "Venus", "Mercurio"]
		},
		{
			"category": "culture",
			"prompt": "Cultura general: ¿cuántos lados tiene un hexágono?",
			"answer": "6",
			"choices": ["6", "5", "7", "8"]
		}
	]

	var distinct_fruits: Array[int] = []
	for value in hand_values:
		if not distinct_fruits.has(value):
			distinct_fruits.append(value)

	var fruit_count := distinct_fruits.size()
	var answer: int
	var prompt: String
	if fruit_count >= 2:
		answer = permutations_without_repetition(fruit_count, 2)
		prompt = "Combinatoria · En tu mano hay %d tipos distintos de fruta. ¿Cuántas variaciones sin repetición de 2 frutas se pueden ordenar? (P(n, 2))" % fruit_count
	else:
		answer = combinations_with_repetition(fruit_count, 2)
		prompt = "Combinatoria · Con %d tipo de fruta distinto en tu mano, ¿cuántas parejas de 2 frutas se pueden elegir permitiendo repetición?" % fruit_count

	question_pool.append({
		"category": "combinatorics",
		"prompt": prompt,
		"answer": str(answer),
		"choices": _numeric_choices(answer)
	})
	return question_pool[_rng.randi_range(0, question_pool.size() - 1)]


func make_combinatorics_question(hand_values: Array[int]) -> Dictionary:
	var distinct_fruits: Array[int] = []
	for value in hand_values:
		if not distinct_fruits.has(value):
			distinct_fruits.append(value)
	var fruit_count: int = maxi(2, distinct_fruits.size())
	
	var q_type := _rng.randi_range(0, 2)
	var prompt: String
	var answer: int
	
	match q_type:
		0:
			# Combinaciones sin repetición C(n, 2)
			answer = int(fruit_count * (fruit_count - 1) / 2)
			prompt = "Reto Combinatorio: Tienes %d frutas distintas en mano. ¿Cuántas parejas no ordenadas C(%d, 2) puedes formar para el comodín?" % [fruit_count, fruit_count]
		1:
			# Variaciones / Permutaciones P(n, 2)
			answer = permutations_without_repetition(fruit_count, 2)
			prompt = "Reto Combinatorio: Con %d frutas distintas, ¿cuántas combinaciones ordenadas (extremo izq y der) P(%d, 2) existen?" % [fruit_count, fruit_count]
		_:
			# Combinaciones con repetición CR(n, 2)
			answer = combinations_with_repetition(fruit_count, 2)
			prompt = "Reto Combinatorio: Si se permite repetir fruta (dobles), ¿cuántas combinaciones CR(%d, 2) se pueden armar con %d frutas?" % [fruit_count, fruit_count]

	return {
		"category": "combinatorics",
		"prompt": prompt,
		"answer": str(answer),
		"choices": _numeric_choices(answer)
	}


func resolve_answer(question: Dictionary, submitted_answer: String) -> bool:
	var expected_answer: String = str(question.get("answer", ""))
	var correct: bool = submitted_answer.strip_edges().to_lower() == expected_answer.strip_edges().to_lower()
	var life_restored := false
	if correct:
		life_restored = GameEconomy.restore_life()
		var category: String = str(question.get("category", ""))
		if category == "combinatorics":
			GameEconomy.award_trivia(5, 1, 1)
		else:
			GameEconomy.award_trivia()
	answer_resolved.emit(correct, life_restored)
	return correct


func _numeric_choices(answer: int) -> Array[String]:
	var values: Array[int] = [answer, maxi(0, answer - 1), answer + 1, answer + 2]
	values.shuffle()
	var choices: Array[String] = []
	for value in values:
		var choice := str(value)
		if not choices.has(choice):
			choices.append(choice)
	return choices
