# Dungeon Tactics (Godot)

Godot 4.7 port of [Dungeon Tactics](https://github.com/fernandorff/dungeon-tactics), a turn-based tactics game in the
style of Final Fantasy Tactics with a Darkest Dungeon-style loop (town, descent, camp, return). Written in typed GDScript.

The rules are a line-by-line port of the web game's engine, checked against it: `tools/export.ts` plays reference
battles, crawl rooms and expedition maps with the web engine, and `tests/run_tests.gd` replays the same seeds here and
must give the same events, turn by turn.

## Commands

```sh
node tools/export.ts ../dungeon-tactics   # content (data/content.json) and reference runs (tests/golden) from the web game
sh tools/test.sh [filter]                  # headless tests (GODOT=path to the Godot 4.7.2 executable)
godot --path .                             # play: title, town, expedition, rooms, quick battles, Until Dawn
godot --path . -- --shot town out.png      # one screenshot of a screen (title, town, map, room, battle, act), then quit
```

## Layout

- `src/engine/`: the battle rules (grid, half tiles, pathing, combat, shots, pushes, counters, turn queue, AI, items, saves).
- `src/crawl/`: the procedural rooms and the expedition.
- `src/game/`: the screens' rules without nodes (saves, party, chest, expedition flow, the turn menu, the town walk).
- `src/ui/`: the screens, built in code: simple 3D (boxes for tiles, capsules for units) and Control panels.
- `src/content.gd`: the game's data, read from `data/content.json`.
- `tests/`: the golden replays and unit tests.

MIT licence, as the web game.
