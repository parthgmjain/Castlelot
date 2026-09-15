class_name Piece
extends RefCounted

enum Type { KING, QUEEN, ROOK, BISHOP, KNIGHT, PAWN }
enum Side { WHITE, BLACK }

const SYMBOLS := {
	Side.WHITE: {
		Type.KING: "♔",
		Type.QUEEN: "♕",
		Type.ROOK: "♖",
		Type.BISHOP: "♗",
		Type.KNIGHT: "♘",
		Type.PAWN: "♙",
	},
	Side.BLACK: {
		Type.KING: "♚",
		Type.QUEEN: "♛",
		Type.ROOK: "♜",
		Type.BISHOP: "♝",
		Type.KNIGHT: "♞",
		Type.PAWN: "♟",
	},
}

static func symbol(type: Type, side: Side) -> String:
	return SYMBOLS[side][type]
