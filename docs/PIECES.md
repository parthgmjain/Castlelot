# Castlelot piece roster

Design by the game's author. Status: [x] built, [ ] not yet. Values are placeholders (points budget / capture score x10).
"Forward" for a piece means its heading toward the enemy zone (`PawnMovement.heading`), "sideways" is perpendicular to it.
The twelve legendary pieces ARE the twelve round bosses (`RunConfig.BOSSES`; the Knights of the Round Table are gone): each round's boss is named after its piece, fields that piece in its army, and the piece joins your roster when you win. There is no ability choice any more. Arthur (round 13) stays as the final boss.
Chess pieces (king, queen, rook, bishop, knight, pawn) are the base set; everything below is new.

## Tiers, points and slots (the shop's economy)

Four tiers. Points are what a piece costs against your allocated points (and capture score is points x10). Values are placeholders to balance later; the source of truth is `PieceDefs.gd` / `Piece.gd`.

**Common** (hold up to 5 types) - 11 pieces:
- 1 pt: Crab, Drummer, Pawn, Scout, Serf
- 2 pt: Archer, Militia, Pilgrim, Shieldbearer, Squire, Torchbearer

**Uncommon** (hold up to 5 types) - 13 pieces:
- 2 pt: Bard, Ferz Guard
- 3 pt: Bishop, Camel, Charger, Golem, Hawk, Knight, Monk, Ranger, Spearman, Tortoise, Zebra

**Rare** (hold up to 3 types) - 11 pieces:
- 4 pt: Alchemist, Catapult, Grasshopper, Lancer, Mirror, Ninja, Twin Rider
- 5 pt: Cannon, Ghost, Griffon, Rook

**Legendary** (hold up to 2 types) - 13 pieces:
- 9 pt: Queen
- 10 pt: Chronomancer, Hydra, Lich, Oracle, Phoenix, Titan, Warlord, Wraith
- 11 pt: Dragon, Paladin, Storm Witch
- 12 pt: Empress

How the shop uses them:
- You can hold at most 5 common, 5 uncommon, 3 rare and 2 legendary **types** at a time (`RunConfig.SLOTS_PER_TIER`); each type can be owned several times, except legendaries (one of each).
- A lottery pull pays, reveals the tier (common 60 / uncommon 30 / rare 10, legendaries are never drawn), then shows 5 cards from that tier: up to 3 types you already hold (+1 copy) and the rest new types. A new type takes a free slot, or, if the tier is full, replaces one of your types and keeps its number of pieces.
- Trading up: 5 commons -> a choice of uncommon cards, 5 uncommons -> a choice of rare cards, 7 rares -> a legendary (the queen, or any boss piece you have beaten this run and don't currently hold).
- Legendaries come only from those upgrades and from beating a boss. With both slots full you choose which of the three to give up (or decline the new one).

## Pawn tier (common)
- [x] Scout: 1 forward or 1 sideways (no capture); captures diagonally forward.
- [x] Shieldbearer: pawn move/capture, but can't be captured by a piece directly in front of it.
- [x] Archer: 1 forward. Instead of moving it can capture a piece exactly 2 squares straight ahead and stay put.
- [x] Serf: 1 diagonally forward (no capture); captures straight forward.
- [x] Militia: 1 orthogonally in any direction incl. backward (no capture); captures diagonally forward.
- [x] Crab: 1 sideways only (no capture); captures 1 diagonally in any direction.
- [x] Torchbearer: moves like a pawn. When captured, the capturing piece is destroyed too.
- [x] Drummer: 1 forward, can't capture. Friendly pawns next to it can move 2 forward.
- [x] Pilgrim: 1 forward or backward, or swaps places with an adjacent friendly piece.
- [x] Squire: moves like a pawn. Starting a turn next to a friendly knight, it can make a knight jump instead.

## Uncommon tier (rook/bishop/knight level)
- [x] Camel: 3-1 leaper.
- [x] Zebra: 3-2 leaper.
- [x] Twin Rider: one or two knight jumps in the same direction (the square between the jumps must be empty).
- [x] Ninja: knight move; after a capture it may move 1 more square.
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
- [x] Alchemist: king move, or swaps places with any friendly piece within 2 squares.
- [x] Ghost: up to 2 squares in any direction, passing through pieces.
- [x] Spearman: 1 square any direction; captures up to 2 squares straight ahead.
- [x] Bard: king move, can't capture. Adjacent friendly pieces can't be captured by pawns.
- [x] Griffon: 1 square diagonally, then up to 3 squares straight outward.

## Legendary tier (queen level, one per knight boss)
- [x] Paladin: bishop + knight. Adjacent friendly pieces can't be captured. When the king is attacked it can teleport next to the king.
- [x] Warlord: rook + knight. Every capture gives a bonus move with one pawn.
- [x] Empress: queen + knight.
- [x] Dragon: rook move, or breathes fire capturing every enemy up to 3 squares along one line, then rests a turn.
- [x] Phoenix: queen move. The first time it is captured it returns to its starting square 3 turns later.
- [x] Hydra: up to 2 squares any direction. When captured it splits into 4 knights (none adjacent) or 2 (any adjacent), never more than the empty squares beside it.
- [x] Wraith: queen move, phases through pieces. Can only be captured by pawns or other legendaries.
- [x] Lich: king move or 2-square leap. Every piece it captures returns as your pawn on your back rank.
- [x] Chronomancer: bishop move. Once per game it can undo the opponent's last move.
- [x] Titan: rook move that can capture up to 2 pieces in its path in one move.
- [x] Oracle: up to 3 squares any direction. Every second turn it takes two moves in a row.
- [x] Storm Witch: queen move, or teleports next to an enemy piece (no capture that turn).

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
- Swaps: "adjacent" is the 8 squares around the piece (across seams too); the Alchemist's "within 2" is any square up to 2 away in each direction, whatever stands between. Swapping a pawn into the enemy zone promotes it.
- Torchbearer: the capturer is destroyed whichever way it captured (an Archer's arrow too). The Torchbearer's side scores the destroyed piece, and if it was a king that side wins.
- Ninja: the extra step is one square in any direction, may capture, is free (costs no move), optional (Skip Bonus Move) and never chains into another bonus.
- Warlord: the bonus is a free, optional move of any one real pawn (never chains). A bonus nobody can use isn't offered.
- Lich: a captured piece returns as a pawn on the empty square of your own zone farthest from the enemy zone (with no zones, on the far end of the home row); it is a temporary pawn, not a roster piece.
- Phoenix: "3 turns later" is 3 of its owner's own turns. It returns to where it stood when the match began, waiting if that square is taken. It only ever returns once, and a Phoenix waiting to return isn't lost from your roster.
- Hydra: "next to it" is judged after the capturing piece has moved, counting any side; knights fill the free neighbouring squares in order right, left, down, up, then the diagonals.
- Drummer: boosts real pawns only (not Scouts etc.), from any square, when a friendly Drummer is on one of the 8 squares around it.
- Squire: the knight jumps are available only while a friendly Knight (the real piece) stands next to it.
- Paladin: "in check" means an enemy piece could capture (or burn) the king with its next move, and the teleport is available only then, to any empty square next to the king. Its aura protects the 8 squares around it from every attacker, but not the Paladin itself.
- Storm Witch: the teleport reaches any empty square next to any enemy piece, on any connected board. A teleport is a whole move, so it can't capture that turn.
- Oracle: "every second turn" counts the owner's completed turns: on turns 2, 4, 6, ... if the Oracle is the piece that moves, it may move once more (free, optional, never chains). Moving any other piece on those turns earns nothing.
- Chronomancer: "once per game" is once per match, per Chronomancer. The rewind is free and doesn't end your turn (you then move normally). It undoes the opponent's most recent move, including anything it set off, and is offered (right-click the orange ring on the square that piece moved to) only right after the opponent has moved. The AI never rewinds.
- Titan and Dragon are boss rewards: not in the lottery, and rewards are not wired to the knights yet.
- Boss matches: the boss's own piece is placed first and comes ON TOP of the boss army's budget (the army is still bought with the full budget, so a boss is never just its piece). The black points readout counts the boss piece too. A boss's piece is played by the ordinary greedy AI; the AI's Chronomancer never rewinds, and its Paladin/Storm Witch teleport like anyone's.
- Rewards are added to your roster as soon as you win the boss match (before the shop); a lost boss match gives nothing.

## The AI's random armies (2026-09-25)
The AI's incidental army each match (not the boss's own piece, which is always fielded via `reserved`) starts as chess pieces only and gradually picks up the other 38 pieces as a run goes on:
- Round 1 is exactly the five chess types (queen, rook, bishop, knight, pawn) - no extras at all.
- From round 2, common-tier extras start turning up, reaching full weight by round 5.
- From round 4, uncommon-tier extras start, full weight by round 8.
- From round 7, rare-tier extras start, full weight by round 12 (and Arthur, round 13).
- Legendaries never appear in a random army - they're earned, not drawn (a boss still always fields its own).

See `PieceSelector.EXTRA_TIER_UNLOCK` / `EXTRA_TIER_WEIGHTS` / `EXTRA_TIER_DECAYS` / `EXTRA_TIER_SUPPLY` for the placeholder numbers, and `RunFlow.begin_match` for where the run's round number is threaded in. The sandbox's own "Auto Place" buttons are unaffected (no round context = chess only), so existing sandbox testing keeps working as before.

## Tooltips (2026-09-25)
Every piece has a one-line `description` (`PieceDefs.description(type)` for the 43 extras, `Piece.CLASSIC_DESCRIPTIONS` for the six chess pieces, both reachable via `Piece.description(type)`), shown as a tooltip wherever a piece is offered before it's on the board: the sandbox's fixed chess buttons and its "More pieces..." dropdown, the deployment bench, the promotion picker, the shop's owned-piece rows, its lottery/trade-up cards, and every legendary/replacement/bargain choice button. Prophecies already had their description as visible text plus a tooltip on the title; the debug "Add prophecy..." dropdown and every piece-choice button a prophecy offers (Sanctuary, Transmutation's "become which piece", Field Promotion, etc.) now carry one too.
