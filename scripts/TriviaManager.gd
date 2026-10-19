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
			"category": "combinatorics",
			"prompt": "Combinatoria: ¿De cuántas formas se pueden ordenar 3 fichas distintas en una fila? (3!)",
			"answer": "6",
			"choices": ["6", "3", "9", "12"]
		},
		{
			"category": "combinatorics",
			"prompt": "Combinatoria: ¿Cuántas parejas distintas C(4, 2) se pueden formar con 4 frutas diferentes?",
			"answer": "6",
			"choices": ["6", "8", "4", "12"]
		},
		{
			"category": "combinatorics",
			"prompt": "Combinatoria: Si lanzas una moneda 3 veces, ¿cuántos resultados posibles (2³) existen?",
			"answer": "8",
			"choices": ["8", "6", "9", "16"]
		},
		{
			"category": "unit_iii",
			"prompt": "Probabilidad: Si en una bolsa hay 3 frutas rojas y 5 verdes, ¿cuál es la probabilidad de sacar una roja?",
			"answer": "3/8",
			"choices": ["3/8", "5/8", "3/5", "1/4"]
		},
		{
			"category": "unit_iii",
			"prompt": "Estadística: ¿Qué medida estadística representa el valor con mayor frecuencia en un conjunto de datos?",
			"answer": "Moda",
			"choices": ["Moda", "Mediana", "Media", "Varianza"]
		},
		{
			"category": "unit_iii",
			"prompt": "Estadística: En una lista ordenada de datos, ¿cómo se llama el valor que divide la muestra en dos partes iguales?",
			"answer": "Mediana",
			"choices": ["Mediana", "Media", "Rango", "Desviación"]
		},
		{
			"category": "culture",
			"prompt": "Cultura general: ¿Cuál es el planeta más grande de nuestro sistema solar?",
			"answer": "Júpiter",
			"choices": ["Júpiter", "Saturno", "Neptuno", "Marte"]
		},
		{
			"category": "culture",
			"prompt": "Cultura general: ¿Cuántos lados tiene un hexágono regular?",
			"answer": "6",
			"choices": ["6", "5", "7", "8"]
		},
		{
			"category": "culture",
			"prompt": "Cultura general: ¿Cuál es el elemento químico más abundante en el universo?",
			"answer": "Hidrógeno",
			"choices": ["Hidrógeno", "Oxígeno", "Helio", "Carbono"]
		},
		{
			"category": "culture",
			"prompt": "Cultura general: ¿En qué continente se encuentra la cordillera de los Andes?",
			"answer": "América",
			"choices": ["América", "Asia", "Europa", "África"]
		},
		{
			"category": "culture",
			"prompt": "Cultura general: ¿Cuántos grados suman los ángulos internos de un triángulo?",
			"answer": "180°",
			"choices": ["180°", "360°", "90°", "270°"]
		}
	]

	# También añadir dinámicamente un reto combinatorio basado en la mano actual
	var dynamic_q := make_combinatorics_question(hand_values)
	question_pool.append(dynamic_q)

	return question_pool[_rng.randi_range(0, question_pool.size() - 1)]


func make_combinatorics_question(hand_values: Array[int]) -> Dictionary:
	var distinct_fruits: Array[int] = []
	for value in hand_values:
		if not distinct_fruits.has(value):
			distinct_fruits.append(value)
	# Usar al menos 2 frutas distintas para que la pregunta sea significativa
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
	var submitted_clean: String = submitted_answer.strip_edges().to_lower()
	var expected_clean: String = expected_answer.strip_edges().to_lower()
	# Comparar como cadena primero; si ambas son números, comparar como entero para evitar falsos negativos
	var correct: bool
	if submitted_clean.is_valid_int() and expected_clean.is_valid_int():
		correct = int(submitted_clean) == int(expected_clean)
	else:
		correct = submitted_clean == expected_clean
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
	# Genera 4 opciones únicas: la correcta y 3 distractores cercanos
	var choices: Array[String] = []
	var candidates: Array[int] = [answer]
	# Añadir distractores: -2, -1, +1, +2, +3, +4 relativos a la respuesta
	for delta in [-2, -1, 1, 2, 3, 4]:
		var candidate: int = answer + delta
		if candidate >= 0 and not candidates.has(candidate):
			candidates.append(candidate)
		if candidates.size() >= 4:
			break
	# Si aún faltan (respuestas muy pequeñas como 0), agregar valores positivos ascendentes
	var extra := 5
	while candidates.size() < 4:
		if not candidates.has(extra):
			candidates.append(extra)
		extra += 1
	# Tomar los primeros 4, mezclar y convertir a String
	var pool: Array[int] = candidates.slice(0, 4)
	pool.shuffle()
	for value in pool:
		choices.append(str(value))
	return choices
