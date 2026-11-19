# BRAINROT BUNKER

A 3D Roblox brainrot tycoon in the genre *Steal a Brainrot* began, built for make.fun's
"Make the best AI Roblox brainrot game" bounty (roblox-brainrot-01). An original cast of
Indonesian-internet brainrots - Kakek Kentang, Tahu Bulat Dadakan, Kucing Oren Barbar,
Mas Rusdi, Dewa Warteg and more - walks a conveyor across a plaza island. Buy one, carry
it home on your head, place it on your base and watch it earn money every second. Climb
the rarity ladder (Common -> Rare -> Epic -> Legendary -> Mythic, with Gold x5 and
Rainbow x10 mutations), steal from unlocked enemy bases, lock your own, survive the
periodic TSUNAMI GELOMBANG OTAK, and rebirth for a permanent income multiplier.

## Layout

A Rojo project: Luau sources under `src/` build into `game.rbxl`.

- `src/shared/Config.luau` - every tunable number and the whole cast (ReplicatedStorage).
- `src/server/` - `init.server.luau` bootstrap plus one module per job:
  `GameState` (all state), `WorldBuilder` (the island, conveyor, 8 bases, shop),
  `CharacterFactory` (blocky brainrot models + labels), `ConveyorService`,
  `EconomyService` (income tick, buy/carry/place), `BaseService`, `StealService`
  (stealing + base locks), `WaveService` (the tsunami), `RebirthService`
  (rebirths + upgrades), `Remotes`.
- `src/client/` - `Game.client.luau` bootstrap and `Hud.luau` (money/income HUD,
  cast & price list, buttons, tsunami banner).

## Build and hand in

    rojo build default.project.json --output game.rbxl
    mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

`main.ts` (Node 22, standard library only) copies `game.rbxl`, `src/`, `screenshots/`
and `PLAY.json` to the output directory and writes `dossier.json` with
`vendor/makefun-roblox.ts`, the kit's copy, unchanged.
