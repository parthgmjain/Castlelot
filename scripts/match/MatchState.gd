class_name MatchState
extends RefCounted

var active: bool = false
var player_side: Piece.Side = Piece.Side.WHITE
var turn_side: Piece.Side = Piece.Side.WHITE

## Whoever made the latest move; debug mode passes the turn on from them.
var last_mover: Piece.Side = Piece.Side.WHITE

## The player's remaining moves; the match is lost when they run out.
var moves_left: int = 0
var target_score: int = 0
var scores: Dictionary = { Piece.Side.WHITE: 0, Piece.Side.BLACK: 0 }

## "" while undecided, then "win" or "loss".
var result: String = ""
var result_reason: String = ""
var last_event: String = ""

## Roster ids that were on the board when the match began, to work out which were lost.
var deployed_roster_ids: Array = []

## Prophecies working this match (ProphecyEffect); unlike `modifiers` they never carry over.
var prophecies: Array = []

## A bonus move being offered to the side to move ({} when none): { kind, side, label, ... }.
## While it is pending the turn doesn't pass; taking it is free and optional. See MoveEffects.
var bonus: Dictionary = {}

## Snapshots of the boards taken before each move, newest last (see MoveEffects): what a
## Chronomancer rewinds to. Each also records who moved and where the moved piece ended up.
var history: Array = []

## How many turns each side has completed (an Oracle moves twice on every second one).
var turns_taken: Dictionary = { Piece.Side.WHITE: 0, Piece.Side.BLACK: 0 }

## Pieces waiting to return to the board: [{ piece, board, square, turns, side }].
var revivals: Array = []

## Set once the result has been paid out / shown, so it only happens once.
var settled: bool = false

## ScoreModifier instances (planet cards, jokers, abilities) applied to every capture.
var modifiers: Array = []
