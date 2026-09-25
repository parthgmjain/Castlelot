# Prophecy cards

One-time cards bought in the shop. You carry up to 3 (`RunConfig.HAND_SIZE`); discard any time; unused cards carry on from match to match (not into a new run). The rarer a card, the more powerful, the pricier and the less often the shop offers it. No prophecy can kill or remove a king (Reveal Weakness only freezes it).

Timing: **[M] ** played on your turn in a match (free, costs no move) - **[A] ** armed before a match, then fires by itself - **[S] ** played in the shop.
Status: [x] built, [ ] designed but not built yet. Numbers are placeholders (`Prophecies.gd`, `RunConfig.gd`).

Shop: 4 random built cards are for sale each visit (rarity odds 55 / 30 / 12 / 3%). With a full hand you must discard before buying.

### Common (18) - 4 gold
- [x] **Rising Tide** [M]: Every capture for the rest of the match scores +10.
- [x] **Blood Moon** [M]: Your next 3 captures score x1.5.
- [x] **Song of the Small** [M]: Captures by common-tier pieces score x1.5 this match.
- [x] **Waypoint** [M]: Move any of your pieces to an empty square in your zone.
- [x] **Swap Fates** [M]: Swap any two of your pieces.
- [x] **Wings** [M]: A piece of yours moves like a queen this turn.
- [x] **Broaden the Realm** [A]: Arm before a match: your zone is 6 tiles bigger.
- [x] **Call to Arms** [M]: Two temporary pawns appear in your zone.
- [x] **Iron Skin** [M]: A piece of yours can't be captured by pawns or knights this match.
- [x] **Curse of Stillness** [M]: An enemy piece can't move for 2 of the AI's turns.
- [x] **Banishing** [M]: Remove a common-tier enemy piece (never the king; no score).
- [x] **Sow Discord** [M]: The AI's next move is random.
- [x] **Purse of Gold** [S]: +12 gold.
- [x] **Lucky Draw** [S]: Your next lottery pull is free.
- [x] **Wider Net** [S]: Your next offer shows 7 cards.
- [x] **Haggler's Charm** [S]: Points and zone upgrades are half price this shop visit.
- [x] **Second Sight** [S]: Reroll the offer you're looking at.
- [x] **Merlin's Bargain** [S]: Destroy one of your pieces for 3x its points in gold.

### Uncommon (16) - 8 gold
- [x] **Omen of Plunder** [M]: Your next capture scores x2.
- [x] **Blessing of the Blade** [M]: Pick a piece type: its captures score x1.5 this match.
- [x] **Giant Slayer** [M]: Capturing a piece worth more than your capturer scores x1.5 this match.
- [x] **Marked for Death** [M]: Pick an enemy piece: capturing it scores x2.
- [x] **Quickening** [M]: +2 moves this match.
- [x] **Second Chance** [A]: Arm before a match: if you'd run out of moves short of the target, gain 2 moves once.
- [x] **Haste** [M]: Your next 3 moves cost nothing.
- [x] **Sanctuary** [M]: A piece of yours can't be captured for 3 of your turns.
- [x] **Reinforcements** [A]: Arm before a match: +5 allocated points this match.
- [x] **Rite of Rebirth** [M]: The last piece you lost this match returns to its starting square.
- [x] **Transmutation** [M]: A piece of yours becomes another of the same tier for this match.
- [x] **Guardian Spirit** [A]: Arm before a match: the first piece you'd lose for good stays in your roster.
- [x] **Shattered Shields** [M]: The enemy's protections and auras stop working this match.
- [x] **Reveal Weakness** [M]: The enemy king can't move for 3 turns.
- [x] **Loaded Dice** [S]: Your next pull's tier is at least Uncommon.
- [x] **Fair Trade** [S]: Your next trade-up costs 2 fewer pieces.

### Rare (11) - 15 gold
- [x] **Borrowed Hour** [M]: Take an extra move right now.
- [x] **Twin Sun** [M]: This turn you may move two different pieces.
- [x] **Turning Tide** [M]: Rewind the opponent's last move.
- [x] **Stone Ward** [M]: No piece can capture on a chosen square for 3 turns.
- [x] **Chain of Fate** [M]: Captures on consecutive turns build a multiplier: x1, x1.5, x2... It resets when you miss.
- [x] **Prophecy of Ruin** [M]: This match's target score is 20% lower.
- [x] **Gilded Ledger** [M]: Add 15% of the target score to your score now.
- [x] **Golden Tithe** [A]: Arm before a match: this match's payout is x1.5.
- [x] **Hex of the Boss** [M]: The boss's legendary is frozen for 3 turns.
- [x] **Mantle of the Phoenix** [A]: Arm before a match, pick a piece: the first time it's captured it returns 3 turns later.
- [x] **Field Promotion** [M]: Promote any pawn, anywhere, to a piece of your choice up to a rook.

### Legendary (5) - 30 gold
- [x] **Final Blow** [A]: Arm before a match: captures on your last move score x3.
- [x] **Frozen Moment** [M]: The AI skips its next turn.
- [x] **Echo of Steel** [M]: Copy one of your pieces onto a free zone square for this match.
- [x] **Queen's Favor** [S]: Your next 7-rare upgrade costs 5 rares.
- [x] **Unsealed Tomb** [S]: Unlock a random boss legendary for upgrades this run.

## How they work (built so far)
- Score effects (Omen, Rising Tide, Blood Moon, Song of the Small, Giant Slayer, Blessing, Chain of Fate, Final Blow) are `ProphecyEffect`s in `MatchState.prophecies`: they only ever touch YOUR captures, last one match, and are gone when the next match starts.
- "Next capture" counts victims: a multi-capture move uses up one use per piece taken.
- Chain of Fate: x1 on the first capturing turn, then +0.5 per consecutive capturing turn; a turn without a capture resets it.
- Final Blow stays armed until it actually fires (a match that ends early, or a last move that takes nothing, does not use it up).
- Prophecy of Ruin / Gilded Ledger can win the match on the spot if you are then at or past the target.
- Golden Tithe adds half of the win's payout (rounded) and is used up on that win.
- Shop effects wait in `RunState.shop_effects`: Lucky Draw, Loaded Dice, Wider Net, Fair Trade and Queen's Favor last until the next pull / offer / trade-up; Haggler's Charm ends when you leave the shop. A free pull does not make the next pull dearer.
- Merlin's Bargain lists your pieces (no king is ever in your roster); you can back out and keep the card.

## Stage 2 notes (time & position)
- Borrowed Hour and Twin Sun both grant one free move with any piece (the `bonus.kind = "any"` mechanism, same plumbing as a Ninja's bonus step). Twin Sun does not enforce "a *different* piece" - documented simplification.
- Sanctuary sets a `shielded` counter on the piece dict (ticks down on the owner's own turns, like a Dragon's `rest`); it follows the piece if it moves. Stone Ward sets `warded_squares` on the Board itself (ticks down every ply, either side) - so it stays on the square even if the original piece leaves.
- Frozen Moment adds to `MatchState.frozen_enemy_turns`; `MatchController.end_turn` hands the turn straight back to the player when the side about to move is frozen.
- Second Chance is armed like Final Blow: it becomes a `ProphecyEffect` at match start and is checked in `end_turn` right where "Out of moves" would otherwise finish the match.
- Turning Tide reuses `MoveEffects.rewind()` (the Chronomancer's own power) with no piece of its own; refused if the last move in history was your own or there is no history yet.
- Waypoint and Swap Fates are two-step choices: `MatchState.prophecy_pick` holds the first pick between calls to `Prophecies.play_in_match`; starting a fresh Play, or playing a *different* card, resets it. Waypoint's destinations are always inside your own zone (`Roster.free_squares`), so a pawn sent there can never promote - Swap Fates can (already tested), since your pieces can be anywhere on the board.
- Wings sets a `wings` flag read by `Piece.get_legal_moves`, generating queen moves instead of the piece's own for its very next move; the flag is cleared the moment it moves (in `MoveController.execute`), and capture-rule checks still use the piece's true type.
- Broaden the Realm and Reinforcements are consumed at `RunFlow.begin_match()` (before zones/deployment are set up), not during the match - so an unused armed card still shows correctly as armed if you never reach a new match.

## Stage 3 notes (pieces & enemies)
- Every piece is now tagged with a `home` (its starting square) when a match begins (`MoveEffects.mark_homes`, broadened from just Phoenix-type pieces to all of them). Rite of Rebirth uses this for any lost piece; a real Phoenix and Mantle of the Phoenix both still use it too.
- `MatchState.lost_this_match` remembers your own pieces as they leave the board (captures and Torchbearer-style losses alike), newest last; Rite of Rebirth pops the most recent one and refuses if its home square is occupied right now.
- Mantle of the Phoenix (armed) grants a per-instance "extra_on_captured" rebirth effect to whichever of your pieces is lost first - reuses the exact same `MatchState.revivals` queue a real Phoenix uses, so it waits for the square to clear too. `MoveEffects._effects()` now merges a piece's own type-level effects with any per-instance `extra_<key>` list, which is how a non-Phoenix piece can borrow the ability for one match.
- Curse of Stillness / Reveal Weakness / Hex of the Boss all set a `frozen` counter on the target piece dict (same shape as `rest`/`shielded`); `Piece.get_legal_moves` refuses to generate any moves for a frozen piece. It still can be captured - freezing isn't protection.
- Shattered Shields marks every enemy piece `shields_broken` for the match; `CaptureRules.can_capture` skips a piece's own PieceDefs protection and any neighbour's aura when that flag is set. Only the AI's *innate* (PieceDefs-driven) protections exist to shatter - the AI never casts prophecies of its own.
- Sow Discord adds to `MatchState.confused_moves`; `GreedyAI.choose_move` spends one to pick uniformly at random instead of evaluating, only for the side that isn't the player.
- Marked for Death sets `marked_for_death` directly on the targeted piece's dict (the very object referenced by `board.pieces`), and a passive `ProphecyEffect` checks that flag in `on_capture` - no need to track *which* piece by board/square once it's flagged.
- Transmutation and Field Promotion are two-step picks using the same `MatchState.prophecy_pick` pattern as Waypoint/Swap Fates; Transmutation's second-step options are every OTHER piece of the same tier (`Piece.types_in_tier`), Field Promotion's are the fixed list `[Rook, Bishop, Knight]` (never the queen).
- Guardian Spirit (armed) is resolved once, at `RunFlow.settle_if_finished()`, right where Phoenix revivals already exempt a piece from `Roster.settle`'s loss list - it only consumes the card if there is actually a first-lost piece to protect.
- Echo of Steel and Call to Arms both spawn with `MoveEffects.spawn()` (renamed from the private `_spawn`, now shared): no roster_id, so a copy or a temporary pawn simply vanishes with the rest of the board state if it survives to the next match.
