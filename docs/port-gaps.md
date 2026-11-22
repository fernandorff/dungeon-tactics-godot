# What the Godot port still misses to equal the web game (21/11/2026)

Read-only survey of D:\Projetos\dungeon-tactics against this port. Sizes: S small, M medium, L large.

Spot-checked on 21/11:
- `ui/battle_view.gd` draws only BoxMesh (lines 122, 150, 283);
- the repo has no .ogg or .wav file;
- `options_window.gd` is 46 lines long; `end_screen.gd` is 48.

The rest comes from file and function names; treat it as likely.

In progress on 21/11:
- portraits;
- floating numbers;
- music;
- the AI with the new abilities;
- walk and range outlines;
- greyed Agir;
- free area aim;
- cursor stutter.

## By what a player notices first
1. **Battle look**, all L:
   - painted terrain (`scene/board.ts`, `terrain*.ts`);
   - KayKit models and animations (`scene/units.ts`, `fx.ts`);
   - water (`water*.ts`);
   - props and trees (`trees.ts`, `props.ts`, `bridge.ts`);
   - scenery past the edge (`ambience*.ts`);
   - time of day and lights (M).
2. **Weight of blows and the event sequence**:
   - `hit-weight.ts` and `scene/unit-hits.ts` (M);
   - `scene/unit-events.ts`, `unit-moves.ts` and `before-event.ts` (L);
   - the battle clock and speeds, `scene/timeline.ts` and `timing.ts` (M).
3. **Battle HUD**:
   - ~~3D command menu with the action sheet (`menu3d/*`, L)~~ ported from the code on 22/11 (see below);
   - ability icons atlas (`icons.ts`, M);
   - ~~3D turn list with queue projection (`turn3d/*`, L)~~ ported from the code on 22/11 (see below);
   - ~~combat bar (`bar3d/*`, M)~~ ported from the code on 22/11 (see below);
   - forecast with push and life after (`forecast.ts`, S);
   - status window and unit peek (M);
   - charge and counter lines (M);
   - ~~hints and banners (`hints3d/*`, M)~~ ported from the code on 22/11 (see below);
   - corner buttons (S).
4. **Expedition map as a drawing** (`town3d/map3d.ts`, `map-draw.ts`), L.
5. ~~**Dialogue box** (typing, voices, talking face, text speed; `window3d/talk3d.ts`), M~~ ported from the code on 22/11 (see below). ~~**Results board** (`result3d/*`, `tally.ts`), M~~ ported from the code on 22/11 (see below). Also confetti and defeat (S), and the survival countdown (S).
6. **Options**, beyond language and volumes:
   - text speed, key hints, fast battle, back to title, reduce motion, layout mode, on-screen buttons, slow-motion deaths, fps counter, fullscreen, pad side, mark style, town grid (S each);
   - the categories with description and help windows (M).
7. **Input**:
   - key and pad glyphs (`glyphs.ts`, `key-hints.ts`, M);
   - full keyboard map (M);
   - gamepad (M);
   - touch gestures: drag, pinch, rotate, tap slack (M).
8. **Town**:
   - walkable look (M);
   - town HUD (S);
   - touch joystick (M);
   - shop and tavern parchment views (M);
   - party sheet with attribute origins (M);
   - street menu and gate (S).
9. **Title**:
   - art and camera spin (M);
   - loading cover (S);
   - rotate note (S);
   - full credits (S);
   - save slots with faces (S).
10. **Marks**:
    - mark styles (Simple, Light, Stone, Neon) (M);
    - shot trajectory with the X past the stop (M);
    - camera: orthographic, 45° turns, follow, action camera (M).
11. **Sound**: every effect, fanfare and speech blip (`sound.ts`), M.
12. **Rules**: no known gap. The goldens cover `shared/`. Check i18n coverage (`i18n.ts` against `game/texts.gd`), S.

Open question: is there a camp screen apart from the expedition map? The survey found none in the web game.

## Ported from the web code (not from captures)

22/11 — 3D command menu (`menu3d/*`) on the shared 3D kit (`ui3d/*`):
- `src/ui/ui3d/`: `layer3d.gd` (layer.ts: one orthographic camera in page px, flat then deep pass), `stage_layout.gd`
  (layout.ts), `spring3d.gd` (spring.ts), `panel3d.gd` + `paper.gdshaderinc` + `paper3d`/`band3d` shaders (panel.ts),
  `icon3d`/`icon3d_hull` shaders (icons.ts), `text3d.gd` (text.ts).
- `src/ui/hud/`: `menu3d.gd`, `menu3d_column.gd`, `menu3d_sheet.gd`, `menu3d_icon.gd`, `menu_layout.gd`; `menu_view.gd`
  gained `changes`.
- `tools/export-menu.mjs` runs the web's own code: the models (glb), the painted detail (its canvas code in headless
  Chrome) and `tests/golden/menu.json`; `tests/menu_tests.gd` replays 144 layouts, 80 text sizes, 6 spring traces and
  every page step against it.
- Checked side by side with the live site at 1920x1080 (Agir list, action sheet): same places, colours and models.
- Known differences: the text halo is one soft outline (the web blurs a shadow); the web's Tab focus on the menu
  buttons is not ported (the port's keys drive the menu).

22/11 — 3D combat bar (`bar3d/*`) on the same kit:
- `src/ui/hud/bar_layout.gd` (bar-layout.ts), `bar3d.gd`, `bar3d_part.gd`, `bar3d_sheet.gd` (bar3d.ts), and
  `src/ui/ui3d/sheet3d`/`plate3d` shaders with `bar3d.gdshaderinc` (plates.ts); `bar_view.gd` gained the "+4" life back
  per turn. The 2D `combat_bar.gd` and `unit_sheet.gd` are gone.
- `tools/export-bar.mjs` writes `tests/golden/bar.json` from bar-layout.ts; `tests/bar_tests.gd` replays both sheets,
  the plate and 72 `hang` cases.
- Checked side by side with the live site at 1920x1080 (Facada aimed at an ally): same plate, bars, blinking part and
  portraits. `Text3d` now thickens its glyphs like the web's same-ink stroke (embolden 0.48).
- Known difference: no rendered-portrait fallback for a unit without a face sheet (every unit has one today).

22/11 — 3D turn list (`turn3d/*`) on the same kit:
- `src/ui/hud/queue_layout.gd` (queue-layout.ts and the sizes of queue-view.ts), `queue_view.gd` (queue-view.ts),
  `turn3d.gd` and `turn3d_card.gd` (turn3d.ts), `turn3d_tip.gd` (card-tip.ts), `src/ui/ui3d/card3d.gdshader` (card.ts);
  `src/ui/ui3d/part3d.gd` + `box3d.gdshader` (hints3d.ts Part, shared with the hints next). The 2D `turn_list.gd` and
  `turn_card.gd` are gone.
- `tools/export-turn.mjs` writes the cards' paint and digit atlas (the web's own code, the atlas drawn in headless
  Chrome) and `tests/golden/turn.json`; `tests/turn_tests.gd` replays 180 list layouts, 90 line layouts, line widths,
  card matching and repeats.
- Checked side by side with the live site at 1920x1080: same cards, numbers, bars, target mark and order.
- Every 3D label now draws its halo one priority under its letters (`Text3d.order`: at the same priority Godot sorted
  them at random and greyed some lines), starts on a whole pixel (`Text3d.put`) and is emboldened 0.9 to the web's weight.
- Known differences: the title does not fold the list (dt:turnsFold); scrolling is the wheel or a drag on the list.

22/11 — banner, Height corner and key hints (`hints3d/hints3d.ts`, `hints-view.ts`) on the same kit:
- `src/ui/hud/hints3d.gd` (hints3d.ts: the pill springing in, the Height number's bounce, the tile line, the rows),
  `hints_layout.gd` (hints-view.ts layRow, heightBox, messageScale). `HudHints` keeps only the corner buttons and the
  last input (a finger hides the rows). The banner names the ability while it plays (before-event.ts), then the summary.
- `tools/export-hints.mjs` draws each key cap with glyph-art.ts' own drawKey in headless Chrome (`assets/ui/caps/`) and
  writes `tests/golden/hints.json`; `tests/hints_tests.gd` replays the Height boxes, 30 hint rows and the phone scale.
- `Text3d.label(..., shadow)`: the web's hard dark outline for a text with no plate; `Part3d.image` for the caps.
- Checked side by side with the live site at 1920x1080: same pill, Height, tile line and hint row.
- Known differences: the keys are the port's (P for Options, Q/E camera, no R), the outlined text has no soft drop
  shadow under the outline, and no pad glyphs (the port reads no gamepad hints yet).

22/11 — results board (`result3d/*`, `tally.ts`, the boards of `end-screens.ts` and `room-end.ts`) on the same kit:
- `src/game/tally.gd` (tally.ts: damage and takedowns per unit, the highlight, the end rows, the row lines),
  `src/ui/hud/result_layout.gd` + `result_view.gd` (result-layout.ts, result-view.ts), `result3d.gd` (result3d.ts:
  veil, band, plates, faces through `src/ui/ui3d/face3d.gdshader`, buttons with the glove), `src/ui/battle_end.gd`
  (the boards). The 2D `end_screen.gd` and the plain dialogs at the end of a skirmish and of Until Dawn are gone.
- `tools/export-result.mjs` writes `tests/golden/result.json`; `tests/result_tests.gd` replays 25 layouts and the web's
  five tally cases.
- The turn list empties when the battle is over (hud.ts `queued = null`). `Portraits.sheet_of` gives a Roster sheet
  (dev-h0) its class's model, as dev-roster.ts does: the room heroes but the Warrior had no face anywhere.
- Checked against the web's own board (sandbox spec `result3d-vitoria`, 1920x1080): same band, plates, columns, faces,
  buttons and glove. A click on the button goes on to the expedition map.
- Known differences: a standalone battle's second button goes back to the title (the web's goes to the town); no
  confetti; a face without a sheet is left out (the web falls back to the rendered portrait).

22/11 — speech box (`talk.ts`, `window3d/talk3d.ts`, `talk-layout.ts`, `talk-face.ts`) on the same kit:
- `src/ui/talk_layout.gd` (talk-layout.ts), `src/ui/talk3d.gd` (talk.ts' typing at the text speed, the speaker's blip
  every other letter, the mouth cycle, Enter/click/Esc/Skip; talk3d.ts' parchment, name plaque, face frame, hint, ▼;
  talk-face.ts' hop). The town talks through it (town-folk.ts talkTo: a rumour, or a party member's greeting and then
  the Party screen); its own 2D panels step out while someone talks. `Sound.blip` finally has its caller.
- `tools/export-talk.mjs` writes `tests/golden/talk.json`; `tests/talk_tests.gd` replays 50 layouts and the mouth cycle.
- Checked by a shot (`--shot talk`): Aldo's rumour typed, his face in the corner, the plaque, hint and Skip in place.
- Known differences: no `dark` opening narration and no place strip (the port has no story opening); the hint is plain
  text, not key caps.

Every piece of the web's 3D interface listed above is now ported from its code.
