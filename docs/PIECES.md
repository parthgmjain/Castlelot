# Castlelot piece roster

Design by the game's author. Status: [x] built, [ ] not yet. Values are placeholders (points budget / capture score x10).
"Forward" for a piece means its heading toward the enemy zone (`PawnMovement.heading`), "sideways" is perpendicular to it.
Legendary pieces are rewards for beating a Knight of the Round Table (there is no ability choice any more).
Chess pieces (king, queen, rook, bishop, knight, pawn) are the base set; everything below is new.

## Pawn tier (common)
- [x] Scout: 1 forward or 1 sideways (no capture); captures diagonally forward.
- [x] Shieldbearer: pawn move/capture, but can't be captured by a piece directly in front of it.
- [x] Archer: 1 forward. Instead of moving it can capture a piece exactly 2 squares straight ahead and stay put.
- [x] Serf: 1 diagonally forward (no capture); captures straight forward.
- [x] Militia: 1 orthogonally in any direction incl. backward (no capture); captures diagonally forward.
- [x] Crab: 1 sideways only (no capture); captures 1 diagonally in any direction.
- [ ] Torchbearer: moves like a pawn. When captured, the capturing piece is destroyed too.
- [ ] Drummer: 1 forward, can't capture. Friendly pawns next to it can move 2 forward.
- [ ] Pilgrim: 1 forward or backward, or swaps places with an adjacent friendly piece.
- [ ] Squire: moves like a pawn. Starting a turn next to a friendly knight, it can make a knight jump instead.

## Uncommon tier (rook/bishop/knight level)
- [x] Camel: 3-1 leaper.
- [x] Zebra: 3-2 leaper.
- [x] Twin Rider: one or two knight jumps in the same direction (the square between the jumps must be empty).
- [ ] Ninja: knight move; after a capture it may move 1 more square.
- [x] Hawk: leaps exactly 2 or 3 squares in any straight or diagonal direction.
- [x] Cannon: rook move; captures by jumping over exactly one piece.
- [x] Charger: rook move of at least 2 squares.
- [x] Ranger: up to 3 squares orthogonally.
- [x] Lancer: any distance forward, only 1 square backward or sideways.
- [x] Catapult: never moves. Captures any piece exactly 3 squares away orthogonally, over blockers.
- [x] Tortoise: up to 2 squares orthogonally; can only be captured from behind or the sides.
- [x] Mirror: bishop move that can bounce off a board edge once per move.
- [x] Monk: up to 3 squares diagonally, or 1 square orthogonally without capturing.
- [x] Ferz Guard: 1 square diagonally or leaps 2 squares diagonally.
- [x] Grasshopper: along any queen line, must hop over one piece and land directly behind it.
- [x] Golem: 1 square orthogonally; can't be captured by pawns or knights.
- [ ] Alchemist: king move, or swaps places with any friendly piece within 2 squares.
- [x] Ghost: up to 2 squares in any direction, passing through pieces.
- [x] Spearman: 1 square any direction; captures up to 2 squares straight ahead.
- [x] Bard: king move, can't capture. Adjacent friendly pieces can't be captured by pawns.
- [x] Griffon: 1 square diagonally, then up to 3 squares straight outward.

## Legendary tier (queen level, one per knight boss)
- [ ] Paladin: bishop + knight. Adjacent friendly pieces can't be captured. When the king is attacked it can teleport next to the king.
- [ ] Warlord: rook + knight. Every capture gives a bonus move with one pawn.
- [ ] Empress: queen + knight.
- [x] Dragon: rook move, or breathes fire capturing every enemy up to 3 squares along one line, then rests a turn.
- [ ] Phoenix: queen move. The first time it is captured it returns to its starting square 3 turns later.
- [ ] Hydra: up to 2 squares any direction. When captured it splits into 4 knights (none adjacent) or 2 (any adjacent), never more than the empty squares beside it.
- [x] Wraith: queen move, phases through pieces. Can only be captured by pawns or other legendaries.
- [ ] Lich: king move or 2-square leap. Every piece it captures returns as your pawn on your back rank.
- [ ] Chronomancer: bishop move. Once per game it can undo the opponent's last move.
- [x] Titan: rook move that can capture up to 2 pieces in its path in one move.
- [ ] Oracle: up to 3 squares any direction. Every second turn it takes two moves in a row.
- [ ] Storm Witch: queen move, or teleports next to an enemy piece (no capture that turn).

## Assumptions made while building (change freely)
- Only the real pawn promotes; pawn-tier pieces that "move like a pawn" do not.
- "Check" does not exist in this game; Paladin's clause will mean "the king is attacked".
- Legendary boss pieces are reward-only: not in the lottery or trade-up pool. The queen stays a lottery legendary.
- The AI's random armies keep using the six chess pieces for now.
- "Attack without moving" (Archer, Catapult, Dragon) is made with a right-click on the orange ring; a left click does the ordinary move, and on a square that only has an attack it fires too.
- Archer's arrow needs a clear line (anything between blocks it, and it can't hit the adjacent square). Catapult lobs over blockers.
- Titan: after taking a piece it may run on over empty squares and take a second enemy, landing there. A friend behind the first piece blocks it.
- Dragon: fire is orthogonal, burns every enemy within 3 squares in one line and passes over friends unharmed. It rests through its side's next turn (not in the sandbox, where there are no turns).
- Protection is one rule for every attack (`CaptureRules`, applied around `Piece.get_legal_moves`): protected pieces just drop out of an attacker's moves, and a Dragon's flame skips them but still burns the rest of the line.
- Shieldbearer: "directly in front" means the one square ahead of it along its heading; a rook further up the file can still take it.
- Tortoise: "from the front" means any attacker on the front side of it (measured along its heading, across board seams too); beside or behind is fine.
- Golem: "pawns or knights" means only the real Pawn and Knight types.
- Bard: its aura shields the friendly pieces on the 8 squares around it (including across seams) from pawns only; the Bard itself is not covered.
- Wraith: "legendaries" includes the queen; pawns can still take it.
- Paladin is left for the teleport batch, since it needs both its aura and the king teleport.
- Titan and Dragon are boss rewards: not in the lottery, and rewards are not wired to the knights yet.
