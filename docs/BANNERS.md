# Banners

Picked before a run starts (like Balatro's decks): a run-wide identity that lasts the whole run. White/Black just choose which side you play as, with no bonus attached; every other banner is a straight advantage/disadvantage pair - never a pure headstart. Numbers are placeholders (`Banners.gd`), same as the rest of the economy.

Today you pick exactly one banner per run via the "Choose Banner" button (`RunFlow.start_run`, `RunState.banners`). Combining a second banner after winning a run is a later mechanic, not built yet.

Status: [x] built.

### Side (2)
- [x] **White Banner**: Play as White.
- [x] **Black Banner**: Play as Black.

### Trades (15)
- [x] **Iron Banner**: +3 Moves every match / -2 starting Points.
- [x] **Vanguard Banner**: +3 starting Points / -3 Moves every match.
- [x] **Broad Banner**: +5 starting Zone tiles / -2 starting Points.
- [x] **Narrow Banner**: +3 starting Points / -3 starting Zone tiles.
- [x] **Prophetic Banner**: +1 prophecy hand size / -2 Moves every match.
- [x] **Merchant's Banner**: Shop prices -20% / interest cap halved.
- [x] **Banker's Banner**: Interest cap doubled / shop prices +20%.
- [x] **Twin Banner**: Start with 2 copies of a random common piece / -3 starting Points.
- [x] **Royal Banner**: Start with the Queen in your roster / -5 starting Points.
- [x] **Steady Banner**: Boards always start at this round's biggest size / AI budget +1 every match.
- [x] **Stormcaller Banner**: AI budget -1 for rounds 1-3 / target score +10% all run.
- [x] **Reckless Banner**: Gold rewards +25% / target score +15%.
- [x] **Hoarder's Banner**: Carry 4 prophecies instead of 3 / lottery pulls cost +2 gold.
- [x] **Erratic Banner**: Starting roster has 3 extra points of free pieces / composition is randomized, not chosen.
- [x] **Guardian's Banner**: Your first loss this run doesn't end it (retries the same match instead) / -4 Moves every match.

## Implementation notes (2026-09-26)

`RunState.banners` (an `Array` of `Banners.Id`, today always one element) is set by `RunState.begin(banner_ids, rng)`, which also applies every numeric effect: `allocated_points`/`zone_tiles`/`bonus_moves` get their deltas from `Banners.points_delta`/`zone_delta`/`moves_delta`, and the starting roster is either the normal `RunConfig.STARTING_ROSTER`, or (Erratic) a random army from `PieceSelector.select_army` at a bigger budget, plus Twin's copies / Royal's Queen from `Banners.starting_extra_pieces`.

`RunConfig.match_setup` reads `Banners.fixed_board_size`, `ai_budget_delta`, `target_multiplier`, and assigns `white_zone`/`black_zone` by `Banners.player_side(run)` rather than a literal side, so White/Black Banner actually swap which physical color you field. That swap also required threading a `side` parameter through `Roster.gd`'s functions (default `PLAYER_SIDE` = White, so every pre-banner call site is unaffected) and `MatchController.start` (a new `player_side` parameter, since it always builds a fresh `MatchState`, discarding whatever was set on the old one). `RunFlow.begin_match`/`ready_to_fight`/`settle_if_finished` all resolve the AI's side as `Piece.opponent(Banners.player_side(state.run))` instead of a literal `BLACK`.

Economy hooks: `Shop._haggled`, `Lottery.price` and `Prophecies.price` all multiply by `Banners.price_multiplier`; `Payout.calculate` takes an `interest_cap`/`gold_multiplier` (from `Banners.interest_cap`/`gold_multiplier`); `Prophecies.hand_full` reads `Banners.hand_size` instead of the raw `RunConfig.HAND_SIZE` constant.

Guardian's Banner: `RunFlow.result_continued` checks `run.banners.has(GUARDIAN) and not run.guardian_used` on a loss - if so it sets `guardian_used = true` and calls `begin_match()` again (retrying the same round/match) instead of `start_run()` (a full reset). The banner choice itself carries over a real restart (`start_run(state.run.banners)`), so losing a second time keeps the same banner on the new run.

UI: `BannerScreen` (`scripts/ui/BannerScreen.gd`) builds one button per `Banners.ids()` entry in `_ready()` and emits `chosen(id)`; a new "Choose Banner" button on `ControlPanel` opens it (`Main._on_banner_chosen` calls `run_flow.start_run([id])`). The existing "Start Run" button is untouched and still starts a run with no banner (equivalent to White, no trait bonus) - kept as-is deliberately, since ~40 existing tests across the suite call it directly expecting an immediate run start, and rewiring it behind the picker would have meant updating all of them for no functional gain yet.
