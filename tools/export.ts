// Exports the web game's content and reference runs (golden files) for the Godot port to read and match.
// Run: node tools/export.ts [path to the dungeon-tactics repo]  (default: ../dungeon-tactics)
// The content is data in the web game (src/content); the port reads the same numbers from data/content.json, so a
// balance change there reaches here with one run of this script. The golden files are AI-vs-AI battles, crawl rooms and
// expedition maps played by the web engine: tests/run_tests.gd plays the same seeds and must give the same events.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const repo = resolve(process.argv[2] ?? '../dungeon-tactics');
const out = resolve('.');
const mod = (p: string) => import(pathToFileURL(resolve(repo, p)).href);

const units = await mod('src/content/units.ts');
const abilities = await mod('src/content/abilities.ts');
const items = await mod('src/content/items.ts');
const party = await mod('src/content/party.ts');
const rooms = await mod('src/content/crawl/rooms.ts');
const town = await mod('src/content/crawl/town.ts');
const residents = await mod('src/content/crawl/residents.ts');
const scen = await mod('src/shared/battle/scenarios.ts');
const half = await mod('src/shared/battle/half.ts');
const battleMod = await mod('src/shared/battle/battle.ts');
const ai = await mod('src/shared/battle/ai.ts');
const gen = await mod('src/shared/crawl/generate.ts');
const exp = await mod('src/shared/crawl/expedition.ts');
const queue = await mod('src/shared/battle/turn-queue.ts');
const options = await mod('src/shared/battle/options.ts');
const bag = await mod('src/shared/battle/bag.ts');
const flooded = await mod('src/content/maps/flooded-crypt.ts');
const act = await mod('src/client/act-flow.ts');

const content = {
  units: units.UNIT_LIST,
  abilities: abilities.ABILITY_LIST,
  items: items.ITEM_LIST,
  consumables: items.CONSUMABLES,
  item_range: items.ITEM_RANGE,
  start_bag: items.START_BAG,
  jobs: party.JOBS,
  story: party.STORY,
  starting_weapon: party.STARTING_WEAPON,
  recruit_names: party.RECRUIT_NAMES,
  maps: scen.MAPS,
  first_battle: scen.FIRST_BATTLE.id,
  crawl: {
    version: gen.CRAWL_VERSION,
    party: rooms.CRAWL_PARTY,
    groups: rooms.CRAWL_GROUPS,
    boss: rooms.CRAWL_BOSS,
    themes: rooms.CRAWL_THEMES,
    run: rooms.CRAWL_RUN,
    gold: rooms.CRAWL_GOLD,
  },
  town: {
    places: town.TOWN_PLACES,
    start: town.TOWN_START,
    guild_spots: town.GUILD_SPOTS,
    guild_line: town.GUILD_LINE,
    class_voice: town.CLASS_VOICE,
    townsfolk: town.TOWNSFOLK,
    map: town.TOWN,
  },
  residents: residents.RESIDENTS,
  other_prisoners: residents.OTHER_PRISONERS,
  crypt_key: flooded.CRYPT_KEY,
  faces: JSON.parse(readFileSync(resolve(repo, 'src/content/faces.json'), 'utf8')),
};
mkdirSync(resolve(out, 'data'), { recursive: true });
writeFileSync(resolve(out, 'data/content.json'), JSON.stringify(content, null, 1));

// ---- golden runs ----
const golden = resolve(out, 'tests/golden');
mkdirSync(golden, { recursive: true });
const MAX_TURNS = 400;

// an AI-vs-AI battle, turn by turn: who played, the events and the rng after, and the final state
function play(sc: { id: string }, seed: number) {
  const b = battleMod.Battle.start(sc, seed);
  const start = structuredClone(b.state);
  const turns: unknown[] = [];
  while (!b.over && b.state.turnsPlayed < MAX_TURNS) {
    const actor = b.actor.id;
    const events = ai.playAiTurn(b);
    turns.push({ actor, events, rng: b.state.rng, units: b.state.units.map((u: { id: string; hp: number; pos: unknown; ct: number }) => [u.id, u.hp, u.pos, u.ct]) });
  }
  return { scenario: sc.id, seed, start, turns, final: b.state };
}

const battles: unknown[] = [];
for (const sc of scen.MAPS) {
  battles.push(play(sc, 7));
  battles.push(play(half.halve(sc), 11));
}
writeFileSync(resolve(golden, 'battles.json'), JSON.stringify(battles));

// crawl rooms: the generated whole-tile scenario, then a halved battle on it
const crawlRooms: unknown[] = [];
const crawlBattles: unknown[] = [];
for (let seed = 1; seed <= 12; seed++) {
  const opts = seed === 12 ? { depth: 3, boss: true } : { depth: 1 + (seed % 3), theme: seed % 2 ? 'dungeon' : undefined };
  const built = gen.buildRoom(seed * 7919, opts);
  crawlRooms.push({ seed: seed * 7919, opts, tries: built.tries, room: built.room, group: gen.roomGroup(seed * 7919, opts).group });
  if (seed <= 4) {
    scen.SCENARIOS[built.room.id] = built.room;
    crawlBattles.push(play(half.halve(built.room), seed));
  }
}
writeFileSync(resolve(golden, 'crawl_rooms.json'), JSON.stringify(crawlRooms));
writeFileSync(resolve(golden, 'crawl_battles.json'), JSON.stringify(crawlBattles));

// expedition maps and their gold
const expeditions: unknown[] = [];
for (const seed of [1, 42, 99991, -5]) {
  const map = exp.expeditionMap(seed);
  expeditions.push({ seed, map, gold: map.map((n: unknown) => exp.nodeGold(n)), chest: map.map((n: { chest: boolean }) => (n.chest ? exp.chestItem(n) : null)) });
}
writeFileSync(resolve(golden, 'expeditions.json'), JSON.stringify(expeditions));

// the Agir screens for a battle state: the target list, the Agir list, each target's actions with the spot picked first,
// and each action's own target list on both sides
const actRead = (b: unknown) => {
  const targets = act.actTargets(b);
  const list = act.actList(b);
  const refs = list.filter((r: { k: string }) => r.k === 'ability' || r.k === 'item');
  for (const g of act.GROUPS) refs.push(...act.actGroup(b, g));
  return {
    targets,
    list,
    groups: act.GROUPS.map((g: string) => act.actGroup(b, g)),
    actions: targets.map((t: unknown) =>
      act.actActions(b, t).map((a: unknown) => ({ ...(a as object), best: act.bestSpot(a, b), aims: act.actAims(a) })),
    ),
    only: refs.map((r: { k: string; id: string }) => ({
      ref: { k: r.k, id: r.id },
      own: act.actTargets(b, { k: r.k, id: r.id }),
      other: act.actTargets(b, { k: r.k, id: r.id }, true),
    })),
  };
};

// the turn list projection and the Agir options at the start of some battles
const reads: unknown[] = [];
for (const sc of scen.MAPS.slice(0, 4)) {
  const h = half.halve(sc);
  const b = battleMod.Battle.start(h, 3);
  for (let i = 0; i < 3 && !b.over; i++) {
    reads.push({
      scenario: h.id,
      state: structuredClone(b.state),
      order: queue.previewOrder(b.state, 12),
      options: options.actionOptions(b.grid, b.state, b.actor.id),
      items: bag.itemOptions(b.grid, { ...b.state, bag: { life_potion: 2, ether: 1 } }, b.actor.id),
      reach: [...b.reach().values()],
      act: actRead(new battleMod.Battle(b.grid, structuredClone({ ...b.state, bag: { life_potion: 2, ether: 1 } }))),
    });
    ai.playAiTurn(b);
  }
}
writeFileSync(resolve(golden, 'reads.json'), JSON.stringify(reads));

// the AI's plan with one ability alone, for the abilities the AI battles above rarely or never pick (Nov 21: Shove, Throw
// sand, Focus and the stunning Shield bash): the unit's list is narrowed in memory only, so the score of each shows
const PROBED = ['shove', 'sand', 'focus', 'shield_bash'];
const unitsMod = await mod('src/shared/battle/units.ts');
const aiPlans: unknown[] = [];
const seen = new Map<string, number>();
for (const sc of scen.MAPS) {
  const h = half.halve(sc);
  const b = battleMod.Battle.start(h, 5);
  while (!b.over && b.state.turnsPlayed < 200) {
    const def = unitsMod.UNIT_DEFS[b.actor.def];
    const probed = def.abilities.filter((a: string) => PROBED.includes(a) && (seen.get(a) ?? 0) < 5);
    // only a unit in melee: a foe within 4 cells (2 whole tiles), so a range-1 ability can land after a short walk
    const me = b.actor;
    const engaged = b.state.units.some(
      (u: { team: string; pos: { x: number; y: number } }) =>
        u.team !== me.team && Math.max(Math.abs(u.pos.x - me.pos.x), Math.abs(u.pos.y - me.pos.y)) <= 4,
    );
    for (const id of engaged ? probed : []) {
      seen.set(id, (seen.get(id) ?? 0) + 1);
      const all = def.abilities;
      def.abilities = [id];
      aiPlans.push({ scenario: h.id, state: structuredClone(b.state), ability: id, plan: ai.chooseTurn(b.grid, b.state, b.actor.id) });
      def.abilities = all;
    }
    ai.playAiTurn(b);
  }
}
writeFileSync(resolve(golden, 'ai_abilities.json'), JSON.stringify(aiPlans));
console.log('content and golden files written');
