class_name GameState
extends RefCounted

var boards: Array = []
var attach_info: Array = []
var connections: Array = []

var current_side: Piece.Side = Piece.Side.WHITE
var zone_edit_mode: bool = false

var active_board: Board = null
var active_square: Vector2i = Vector2i(-1, -1)
var current_moves: Array = []

func clear_active() -> void:
	active_board = null
	active_square = Vector2i(-1, -1)
	current_moves = []
