# Prophecy cards

One-time cards bought in the shop. You carry up to 3 (`RunConfig.HAND_SIZE`); discard any time; unused cards carry on from match to match (not into a new run). The rarer a card, the more powerful, the pricier and the less often the shop offers it. No prophecy can kill or remove a king (Reveal Weakness only freezes it).

Timing: **[M] ** played on your turn in a match (free, costs no move) - **[A] ** armed before a match, then fires by itself - **[S] ** played in the shop.
Status: [x] built, [ ] designed but not built yet. Numbers are placeholders (`Prophecies.gd`, `RunConfig.gd`).

Shop: 4 random built cards are for sale each visit (rarity odds 55 / 30 / 12 / 3%). With a full hand you must discard before buying.

### Common (18) - 4 gold
- [x] **Rising Tide** [M]: Every capture for the rest of the match scores +10.
- [x] **Blood Moon** [M]: Your next 3 captures score x1.5.
- [x] **Song of the Small** [M]: Captures by common-tier pieces score x1.5 this match.
- [ ] **Waypoint** [M]: Move any of your pieces to an empty square in your zone.
- [ ] **Swap Fates** [M]: Swap any two of your pieces.
- [ ] **Wings** [M]: A piece of yours moves like a queen this turn.
- [ ] **Broaden the Realm** [A]: Arm before a match: your zone is 6 tiles bigger.
- [ ] **Call to Arms** [M]: Two temporary pawns appear in your zone.
- [ ] **Iron Skin** [M]: A piece of yours can't be captured by pawns or knights this match.
- [ ] **Curse of Stillness** [M]: An enemy piece can't move for 2 of the AI's turns.
- [ ] **Banishing** [M]: Remove a common-tier enemy piece (never the king; no score).
- [ ] **Sow Discord** [M]: The AI's next move is random.
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
- [ ] **Marked for Death** [M]: Pick an enemy piece: capturing it scores x2.
- [ ] **Quickening** [M]: +2 moves this match.
- [ ] **Second Chance** [A]: Arm before a match: if you'd run out of moves short of the target, gain 2 moves once.
- [ ] **Haste** [M]: Your next 3 moves cost nothing.
- [ ] **Sanctuary** [M]: A piece of yours can't be captured for 3 of your turns.
- [ ] **Reinforcements** [A]: Arm before a match: +5 allocated points this match.
- [ ] **Rite of Rebirth** [M]: The last piece you lost this match returns to its starting square.
- [ ] **Transmutation** [M]: A piece of yours becomes another of the same tier for this match.
- [ ] **Guardian Spirit** [A]: Arm before a match: the first piece you'd lose for good stays in your roster.
- [ ] **Shattered Shields** [M]: The enemy's protections and auras stop working this match.
- [ ] **Reveal Weakness** [M]: The enemy king can't move for 3 turns.
- [x] **Loaded Dice** [S]: Your next pull's tier is at least Uncommon.
- [x] **Fair Trade** [S]: Your next trade-up costs 2 fewer pieces.

### Rare (11) - 15 gold
- [ ] **Borrowed Hour** [M]: Take an extra move right now.
- [ ] **Twin Sun** [M]: This turn you may move two different pieces.
- [ ] **Turning Tide** [M]: Rewind the opponent's last move.
- [ ] **Stone Ward** [M]: No piece can capture on a chosen square for 3 turns.
- [x] **Chain of Fate** [M]: Captures on consecutive turns build a multiplier: x1, x1.5, x2... It resets when you miss.
- [x] **Prophecy of Ruin** [M]: This match's target score is 20% lower.
- [x] **Gilded Ledger** [M]: Add 15% of the target score to your score now.
- [x] **Golden Tithe** [A]: Arm before a match: this match's payout is x1.5.
- [ ] **Hex of the Boss** [M]: The boss's legendary is frozen for 3 turns.
- [ ] **Mantle of the Phoenix** [A]: Arm before a match, pick a piece: the first time it's captured it returns 3 turns later.
- [ ] **Field Promotion** [M]: Promote any pawn, anywhere, to a piece of your choice up to a rook.

### Legendary (5) - 30 gold
- [x] **Final Blow** [A]: Arm before a match: captures on your last move score x3.
- [ ] **Frozen Moment** [M]: The AI skips its next turn.
- [ ] **Echo of Steel** [M]: Copy one of your pieces onto a free zone square for this match.
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
