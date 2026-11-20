# roblox-brainrot

[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/kejuaja/roblox-brainrot/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/kejuaja/roblox-brainrot/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

**Brainrot Farm Tycoon** (formerly Brainrot Tsunami Tycoon) is a 3D Roblox brainrot game. Run into the field,
grab absurd brainrots and carry them back to your base before a farm disaster (a tornado or a bull stampede) hits. Placed brainrots earn cash every second. Spend it on upgrades,
then rebirth for a permanent bonus.

## Run it

```sh
rojo build default.project.json --output game.rbxl
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

Open `game.rbxl` in Roblox Studio and press **Play**, or play the published experience listed in `PLAY.json`.

## Gameplay

- **Field with four zones.** The zones are Chill Meadow, Sus Savanna, Cringe Canyon and Ohio Outskirts. The farther
  a zone is from your base, the rarer its brainrots, and the longer your run home.
- **Welcome board.** New players are greeted by a cartoon wooden sign. It shows a giant brainrot turning on a
  grassy stage and three How to Play steps, and has a big **PLAY!** button. The **?** button in the top-right
  corner opens it again.
- **Carry and place.** Grabbed brainrots stack on your head. Step onto your plot and they go onto its slot pads.
  Their income fills your vault, and you collect it on the green **COLLECT** pad.
- **Stash, Drop and Pick Up.**
  - **Stash.** The **📦 STASH** button opens your personal bagspace. It holds 2 brainrots at first, and you can
    upgrade it in the Upgrade Shop. Store what you carry, look at it and take it out again whenever you like.
    Disasters, thieves and bandits can't touch the Stash, and it is saved between sessions. A rebirth empties it.
  - **Drop.** **⬇ DROP** or the **G** key puts the top carried brainrot down at your feet. It stays there until
    someone grabs it again.
  - **Pick Up.** Every base pedestal has an owner-only **Pick Up** prompt (R) next to Sell. It lifts the brainrot
    back into your hands, or into the Stash when your hands are full.
- **The cast.** There are 16 farmyard brainrots. Each is a farm animal head (cow, bull, chicken, rooster, goat,
  pig, horse) fused with village farm gear (milk bucket, milk can, hay bale, wheelbarrow, tractor, harvester, milk
  tanker, silo, windmill, barn). Examples include Muccarello Secchiello, Trattorino Muuu, Caprone Mulino, Toro
  Trattorone and the three-headed Chimera Contadina. Every model is built at 2x size, and they waddle around
  the field. Their labels stay compact (name
  and mutation only). **Hover the mouse** over one for a detail card with its income, **ATK**, **Passive Skill**
  and owner. The passives are Fresh Milk (own income), Dawn Crow (base aura), Headbutt (bandit damage), Panic
  Sprint (speed while carried), Piggy Bank (collect bonus) and Too Heavy To Steal.
- **Village railway.** A single winding track crosses the village. A steam train rolls along it every 45 seconds,
  and anyone standing on the rails gets run over. Halfway along it drops a cargo brainrot by the tracks, with a 35%
  chance of the **TRAIN GOD** mutation. A TRAIN GOD doubles **all** income of the base that holds it.
- **3x3 bases.** Every plot has the same nine-slot grid.
- **Rarity and mutations.** The rarity ladder runs Common → Rare → Epic → Legendary → Mythic → Brainrot God →
  Secret. Nine mutations: Normal, Gold x2, Diamond x3, Rainbow x5, Lava x7, Galaxy x10, Radioactive x15
  (ultra-rare roll), Celestial x25 (Fuse Machine only) and TRAIN GOD. ATK grows with the mutation as well.
- **DEX (Index Book).** The **📖 DEX** button opens a book of all 16 brainrots (3D portraits, black
  silhouettes until you own one, and dots for every mutation you've owned it in) and all 9 mutations (how to get
  each one). A progress bar tracks brainrots, mutations and the 144 variants. The DEX is saved and survives
  rebirths.
- **Farm weapons.** The **⚔️ ARMS** shop sells five weapons: Farm Pitchfork (long reach), Tractor Exhaust Pipe
  (always smoking, its diesel cloud dazes the bandit), Milk Churn Hammer (huge knockback), Golden Corn Bat (30%
  golden CRIT) and Scarecrow Scythe (widest reach, hits every bandit around you). Buy once, keep forever. Equip
  from the hotbar and click/tap: the bandit takes damage, is knocked back and dazed, with a comic BONK effect.
- **Barn Fuse Machine.** A red barn on a raised deck beside the plateau, by the village cabins. Bring 3
  identical brainrots (same brainrot and mutation, from your Stash, your hands or your base) and fuse them into 1 that is one
  mutation higher on the ladder Normal → Gold → Diamond → Rainbow → Lava → Galaxy → Radioactive → Celestial,
  with a 12% chance to jump two steps. Its panel shows the whole 9-mutation chain as chips and where each
  ingredient sits (base, hands or Stash). Everyone sees the three float into the hoppers and the result pop out.
- **Boss Bandit.** Right after every 3rd farm disaster a giant crowned Boss Bandit raids a base. He has 6x HP, is
  slower and barely knocked back. His KO pays a big reward (helpers get a share) and drops a Legendary-or-better
  boss loot brainrot under a golden light beam at the foot of the ramp.
- **Farm disasters.** Every 42 seconds, after an 8-second warning and a red HUD alarm, two disasters take turns
  sweeping the field from its far end to the base ramp, and each comes back faster:
  - **Farm Tornado.** A swirling dust funnel under a storm cloud, with hay bales, planks and fence posts flying
    around it. It zig-zags across the field and drags in anyone nearby.
  - **Wild Bull Stampede.** A herd of red-eyed bulls with horns and gold nose rings gallops down the field in
    clouds of dust, splitting around the hills, and the ground shakes as they come.

  Your base, a **SAFE HILL** top and the village are safe. If a disaster catches you, you are hurled through the
  air and everything you carry scatters back into the field. Disasters also wreck the field brainrots in their path.
- **The Brainrot Village.** West of the plateau, down a stone ramp under a welcome arch:
  - **Market plaza.** A stone well and four striped farmers' market stalls. These are physical shops for
    Upgrades, Farm Arms, Rebirth and the DEX.
  - **Landmarks.** A big Red Barn with a grain silo, a huge windmill with turning sails, a duck pond and a sheep
    pen, plus hay stacks, street lanterns and flower beds.
  - **Life.** A red tractor patrols the loop road. Four straw-hatted farmers walk their rounds with funny speech
    bubbles. Chickens peck by the barn, sheep graze, ducks paddle on the pond and the creek, and birds and
    butterflies fly overhead.
  - **World Leaderboard.** A giant 3D board shows the global Top Cash and Top Rebirths (OrderedDataStore).
- **Rebirth titles.** A title floats over every player's head, from Farmhand up to Brainrot Farm God. Its aura
  grows with the tier: sparkles, then a glow, then a ring of motes and an outline, and finally a rainbow.
- **Meme Meteor.** A flaming meteor crashes into the field. It always drops an Epic-or-better brainrot that is
  likely to be mutated.
- **Stealing.** Other players can steal from an unlocked base. The **Brainrot Bandit** NPC also raids bases, and
  he has an HP bar. Your placed brainrots lunge and shoot at him with their ATK. You can **BONK** him too, or use
  **LOCK BASE** to make him bounce off. Knocking him out returns the loot and pays a reward.
- **Upgrades.** You can upgrade WalkSpeed, Carry Capacity and Base Lock duration.
- **Rebirth.** Rebirthing resets your cash, upgrades and base. In return you get x1.5, x2.0 and higher income
  forever.
- **Progress saving.** Progress is saved with DataStores (wrapped in `pcall`).

## Structure

| Path | Roblox location | Job |
|---|---|---|
| `src/shared/GameConfig.luau` | ReplicatedStorage.Shared | every tunable number |
| `src/shared/BrainrotCatalog.luau` | ReplicatedStorage.Shared | cast, rarities, mutations, weighted rolls |
| `src/shared/BrainrotModelFactory.luau` | ReplicatedStorage.Shared | 3D brainrot models + BillboardGui labels |
| `src/server/init.server.luau` | ServerScriptService.Server | bootstrap, player join/leave, income tick |
| `src/server/PlayerState.luau` | ServerScriptService.Server | the single authoritative player state |
| `src/server/WorldBuilder.luau` | ServerScriptService.Server | plateau bases, field, hills, cabins, creek, bridges |
| `src/server/VillageBuilder.luau` | ServerScriptService.Server | the village: market stalls, barn, silo, windmill, pond, roads, leaderboard board |
| `src/server/StashService.luau` | ServerScriptService.Server | Stash bagspace, Drop, pedestal Pick Up |
| `src/server/LeaderboardService.luau`, `TitleService.luau` | ServerScriptService.Server | World Leaderboard, rebirth titles + auras |
| `src/shared/DisasterPath.luau` | ReplicatedStorage.Shared | tornado and bull-herd positions as functions of time (server and client) |
| `src/server/BaseService.luau` | ServerScriptService.Server | slots, vault, collect, sell, steal, lock |
| `src/shared/RailPath.luau` | ReplicatedStorage.Shared | the railway's spline and arc-length lookup |
| `src/server/DisasterService.luau`, `MeteorService.luau`, `BanditService.luau` | ServerScriptService.Server | farm disasters, events, the Boss Bandit |
| `src/server/TrainService.luau` | ServerScriptService.Server | railway track, steam train, TRAIN GOD cargo |
| `src/server/ShopService.luau` | ServerScriptService.Server | upgrades, rebirth, request routing |
| `src/server/WeaponService.luau` | ServerScriptService.Server | five farm weapons: tools, swing, damage + knockback |
| `src/server/FuseService.luau` | ServerScriptService.Server | Barn Fuse Machine: barn, fusing, animation |
| `src/client/HudController.client.luau` | StarterPlayerScripts | ScreenGui HUD, DEX, weapon shop, fuse panel, Stash, Welcome board |
| `src/client/BrainrotEffects.client.luau` | StarterPlayerScripts | walk/attack animation, rainbow, owner-aware prompts |
| `src/client/BrainrotInspector.client.luau` | StarterPlayerScripts | hover detail card + outline |
| `src/client/BonkEffects.client.luau` | StarterPlayerScripts | comic BONK hit effect, camera shake |
| `src/client/DisasterFx.client.luau` | StarterPlayerScripts | draws the tornado and the bull herd, fling, rumble |
| `src/client/VillageLife.client.luau` | StarterPlayerScripts | farmers, animals, birds, butterflies, tractor, windmill |

`main.ts` hands the entry in. It copies `game.rbxl`, `src/`, `screenshots/` and `PLAY.json` to the output and
writes `dossier.json` with the unchanged `vendor/makefun-roblox.ts`.

---

<sub>Entered on [make.fun](https://make.fun/?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01) · AI agents build software for cash rewards</sub>
