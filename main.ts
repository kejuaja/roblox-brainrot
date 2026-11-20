// A working roblox-brainrot-01 entry (Node 22, standard library only): the game is this directory's Rojo
// project, built into game.rbxl with `rojo build default.project.json --output game.rbxl`, and the program
// hands it in. It copies game.rbxl, src/, screenshots/ and PLAY.json from beside this file to /output and
// writes /output/dossier.json, the summary the judge reads, with the vendored make.fun library. A starting
// point, not a winner: it is a grey square that moves with the arrow keys. Build your game, rebuild
// game.rbxl, put your PNG or JPEG screenshots in screenshots/ (the first by name is the cover, and one of
// them is the thumbnail you upload for your game on Roblox) and fill in PLAY.json with your published place.
//
// Every name under /output starts with a letter, a digit or _ and holds only letters, digits, . _ and -: the
// grader fails an entry whose output holds any other, so a file such as .gitkeep or .DS_Store copied in fails it.
// So src/ and screenshots/ are copied without any name that starts with a dot, at any depth.
//
// Outside the grader's container, MAKEFUN_OUTPUT_DIR stands in for /output:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
//
// ---------------------------------------------------------------------------------------------------------
// This entry: BRAINROT FARM TYCOON, a 3D Roblox brainrot game (Rojo project, `default.project.json`).
//   src/shared  -> ReplicatedStorage.Shared   GameConfig (all tuning), BrainrotCatalog (16 farmyard brainrots
//                                             with ATK + Passive Skill, 7 rarities, 7 mutations incl. TRAIN GOD),
//                                             BrainrotModelFactory (3D animal-head + farm-gear models, compact
//                                             name/mutation BillboardGuis), RailPath (railway spline), Format
//   src/server  -> ServerScriptService.Server init.server.luau bootstraps the services: WorldBuilder (plateau
//                                             bases with 3x3 slot grids, 4-zone field, hills, village scenery),
//                                             PlayerState (the single source of truth), BaseService (slots,
//                                             vault, collect, sell, steal, lock), BrainrotSpawner, CarryService,
//                                             DisasterService (farm tornado / bull stampede), VillageBuilder
//                                             (village, market stalls, windmill, barn), LeaderboardService,
//                                             TitleService (rebirth titles + auras), MeteorService,
//                                             BanditService (HP bar, defenders, knockback, Boss Bandit every 3rd
//                                             disaster), TrainService (steam train),
//                                             ShopService (upgrades + rebirth), WeaponService (5 farm weapons),
//                                             FuseService (Barn Fuse Machine), StashService (Stash / Drop / Pick Up), DataService
//   src/client  -> StarterPlayerScripts       HudController (ScreenGui HUD, DEX, weapon shop, fuse panel),
//                                             BrainrotEffects (walk/attack animation, rainbow, owner-aware
//                                             prompts), BrainrotInspector (mouse-hover detail card: $/s, ATK,
//                                             Passive Skill), BonkEffects (comic weapon hit effect), DisasterFx
//                                             (tornado + bull herd), VillageLife (farmers, animals, tractor)
// Loop: run into the field -> grab brainrots (rarer deeper in) -> carry them home before the disaster ->
// they earn $/sec into the vault -> buy WalkSpeed / Carry / Lock upgrades -> rebirth for a permanent bonus.
// Build: rojo build default.project.json --output game.rbxl   (binary .rbxl, never .rbxlx)
// ---------------------------------------------------------------------------------------------------------

import { copyFileSync, cpSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

const here = fileURLToPath(new URL('.', import.meta.url));
const out = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

/** cpSync's filter: leave out every file and directory whose name starts with a dot (.gitkeep, .DS_Store, .git). */
const notDotted = (path: string): boolean => !basename(path).startsWith('.');

// Fail loudly instead of handing in an entry the gate would refuse: PLAY.json must name a real published place
// (the starter's zeros are rejected), and game.rbxl must be Roblox's binary format, not XML.
const play = JSON.parse(readFileSync(join(here, 'PLAY.json'), 'utf8'));
for (const key of ['place_id', 'universe_id'] as const) {
  if (!Number.isSafeInteger(play[key]) || play[key] <= 0) throw new Error(`PLAY.json: ${key} must be a positive integer`);
}
if (!readFileSync(join(here, 'game.rbxl')).subarray(0, 14).equals(Buffer.from('<roblox!\x89\xff\r\n\x1a\n', 'latin1'))) {
  throw new Error('game.rbxl is not a binary Roblox place; rebuild it with rojo build default.project.json --output game.rbxl');
}

copyFileSync(join(here, 'game.rbxl'), join(out, 'game.rbxl'));
copyFileSync(join(here, 'PLAY.json'), join(out, 'PLAY.json'));
cpSync(join(here, 'src'), join(out, 'src'), { recursive: true, filter: notDotted });
mkdirSync(join(out, 'screenshots'), { recursive: true });
if (existsSync(join(here, 'screenshots'))) cpSync(join(here, 'screenshots'), join(out, 'screenshots'), { recursive: true, filter: notDotted });

// The scorer's own caps (reference/gate.json): only text_max_bytes shapes the bytes; the others refuse an entry the
// scorer would refuse (more than 4 screenshots or one over 256 KiB; a place of more than 500000 instances, whose
// scripts' sources come to over 8 MiB or whose scripts' paths come to over 1048576 characters, in all).
writeFileSync(
  join(out, 'dossier.json'),
  buildDossier(out, { text_max_bytes: 65536, screenshots: { max: 4, max_bytes: 262144 }, max_instances: 500000, scripts_max_source_bytes: 8388608, scripts_max_path_chars: 1048576 }),
);
