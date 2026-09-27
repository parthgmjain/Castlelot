# Banners

Picked before a run starts (like Balatro's decks): a run-wide identity that lasts the whole run. White/Black just choose which side you play as, with no bonus attached; every other banner is a straight advantage/disadvantage pair - never a pure headstart. Numbers are placeholders (`Banners.gd`), same as the rest of the economy.

Picked as a dedicated two-step pre-game screen, Balatro-deck-select style: Start Menu -> **Choose your side** (White or Black) -> **Choose your banner** (the 15 trait banners) -> a real run begins immediately with both. `RunState.banners` ends up holding both ids. Combining a second trait banner after winning a run is a later mechanic, not built yet.

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

UI/flow (2026-09-26 redesign): `GameState.Screen` gained `BANNER_SELECT`, between `START_MENU` and `GAME`. `MenuFlow.start_pressed` now transitions to `BANNER_SELECT` instead of `GAME`; `Main._on_start_pressed` also calls `banner_screen.open()`. `BannerScreen` (`scripts/ui/BannerScreen.gd`) is a two-step picker: `open()`/`_show_side_step()` populates just White/Black, and choosing one calls `_show_trait_step()` which repopulates the same `list` with the 15 trait banners (`Banners.ids().filter(not is_side)`); its `_populate` helper uses `remove_child` (not just `queue_free`) so `get_child_count()` is accurate immediately, not just after the next frame. Choosing the trait emits `chosen(side_id, trait_id)`; `Main._on_banner_chosen` sets `state.screen = GAME` and calls `run_flow.start_run([side_id, trait_id])` directly - Start Menu -> Banner Select -> a real run begins, with no blank sandbox in between. The old standalone "Choose Banner" sandbox button/signal was removed as redundant once this became the real front door. The sandbox's own "Start Run" button is untouched and still starts a run with no banner (equivalent to White, no trait bonus) - kept as a dev/test convenience; ~600 existing gameplay tests still reach a blank, run-inactive sandbox via `TestCase.gd`'s `load_main()`, which presses Start then force-sets `state.screen = GAME` directly (bypassing the real picker) rather than actually completing a banner pick, since auto-picking one would start a real run and break every test that hand-builds its own sandbox world.
