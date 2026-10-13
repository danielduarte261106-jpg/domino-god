extends Node

signal economy_changed

const MAX_LIVES := 3

var lives: int = MAX_LIVES
var coins: int = 0
var stars: int = 0
var prizes: int = 0
var selected_mode: String = "local_1v1"
var selected_environment: String = "board"
var target_score: int = 100



func start_game() -> void:
	lives = MAX_LIVES
	economy_changed.emit()


func lose_life() -> void:
	lives = maxi(0, lives - 1)
	economy_changed.emit()


func restore_life() -> bool:
	if lives >= MAX_LIVES:
		return false
	lives += 1
	economy_changed.emit()
	return true


func award_match(coin_amount: int = 20, star_amount: int = 1) -> void:
	coins += maxi(0, coin_amount)
	stars += maxi(0, star_amount)
	prizes += 1
	economy_changed.emit()


func award_trivia(coin_amount: int = 5, star_amount: int = 0, prize_amount: int = 0) -> void:
	coins += maxi(0, coin_amount)
	stars += maxi(0, star_amount)
	prizes += maxi(0, prize_amount)
	economy_changed.emit()
