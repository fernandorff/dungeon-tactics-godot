# Dungeon Tactics (Godot) — guide for AI agents

Godot 4.7.2 port of the web game at ../dungeon-tactics (TypeScript, Three.js). The web game is the reference: its rules,
content and behaviour are copied here, and the tests prove the copy plays the same.

## Rules

- **Typed GDScript** everywhere (`var x: int`, typed returns). Static rule classes with `class_name` (no autoloads for logic).
- **Everything in English**: code, comments, commits. Player text stays bilingual through `Texts.t("português", "English")`.
- **Comments explain why**, in one short line; the port keeps the web game's reasons where they still apply.
- **Content is data**: never hand-copy numbers; run `node tools/export.ts ../dungeon-tactics` to refresh `data/content.json`.
- **Determinism**: battle randomness only through `Rng` with its state in the battle state, in the web game's order.
- **JavaScript traps the port must keep**: `/` is a float division in JS (use `float()` or `Util.floor_div`), `sort` is
  stable (`Util.stable_sort`), Map order is insertion order (Dictionary keeps it), objects are compared by identity
  (`is_same`, never `==` on Dictionaries meant as identity).
- **Gates before every commit**: `sh tools/test.sh` all green. A rule change in the web game is re-exported and replayed.
- **Commits**: Conventional Commits in English, no tool signatures, straight to `master`.
- **No file passes 400 lines**: split by responsibility.
