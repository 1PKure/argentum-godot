# argentum-godot
My first Argentum Online mini server.

## Web export preparation

The `Web` export preset packages the current Godot arena and its AO data files. The browser client has a connection panel; native editor builds keep the automatic development server and F2 client shortcut.

See [the first Web test guide](docs/WEB_TEST.md) for local testing, export instructions, and the runtime checks required before merging.

## AO20 combat interface

The AO20 frame includes inventory/spell panels, synchronized health/mana, arena minimap and a bounded combat console. The `work/ao20-spells` iteration imports all 213 original AO20 entries and enables 39 spells with implemented PvP rules: select → Launch → target click, or a numeric hotkey → target click. Drag spells onto the hotkey bar to reassign them. Escape/right click cancels aiming; WASD stays active and CTRL remains a physical attack without a mana cost.

Use the same branch for the dedicated server and restart it after updating. `tools/Start-PrivateWebTest.cmd` imports the project before launching WSS. The spell protocol checks server support separately from the unchanged movement/physical-attack RPCs.

See [the interface scope and Windows test guide](docs/COMBAT_UI.md). AO20 artwork attribution, provenance and its separate license are in `assets/argentum/interface/ao20/`.

See [spell data, rules and test scope](docs/SPELLS.md) and [movement timing](docs/MOVEMENT.md). This remains a small PvP prototype, not the complete AO20 combat server.


## Arena recovery and camera

M toggles meditation; Q/E drink health/mana potions (original +27 HP / +5% maximum MP). The explicit testing profile is 500 HP /3000 MP, with unlimited arena potions and Respawn after death. The camera follows the local interpolated avatar, while the HUD fills the window from a1280×800 design base. The book supports name/ID search and a full-catalog filter with reasons for entries that require unported systems. See [recovery rules](docs/RECOVERY.md), [the exact catalog](docs/SPELL_CATALOG.md) and [movement/camera validation](docs/MOVEMENT.md).
