# argentum-godot
My first Argentum Online mini server.

## Web export preparation

The `Web` export preset packages the current Godot arena and its AO data files. The browser client has a connection panel; native editor builds keep the automatic development server and F2 client shortcut.

See [the first Web test guide](docs/WEB_TEST.md) for local testing, export instructions, and the runtime checks required before merging.

## AO20 combat interface

The AO20 frame includes inventory/spell panels, synchronized health/mana, arena minimap and a bounded combat console. The book imports all 213 original AO20 entries and enables 39 spells with implemented PvP rules: select → Launch → target click, or a numeric hotkey → target click. Drag spells onto the hotkey bar to reassign them. Escape/right click cancels aiming; WASD stays active and CTRL remains a physical attack without a mana cost.

Use the same branch for the dedicated server and restart it after updating. `tools/Start-PrivateWebTest.cmd` imports the project before launching WSS. The spell protocol checks server support with protocol 5; player updates now redact enemy mana and physical hits use participant-only feedback.

See [the interface scope and Windows test guide](docs/COMBAT_UI.md). AO20 artwork attribution, provenance and its separate license are in `assets/argentum/interface/ao20/`.

See [the PvP priorities and integration workflow](docs/ROADMAP.md). New task branches and PRs start directly from the updated `Alpha`.

See [spell data, rules and test scope](docs/SPELLS.md) and [movement timing](docs/MOVEMENT.md). This remains a small PvP prototype, not the complete AO20 combat server.


## Arena recovery and camera

M toggles meditation; Q/E drink health/mana potions (original +27 HP / +5% maximum MP). The default mage testing preset has 363 HP / 2487 MP (human, level 50); other classes use their own profiles, with unlimited arena potions and Respawn after death. The camera follows the local interpolated avatar, while the HUD fills the window from a 1280×800 design base. The book supports name/ID search and a full-catalog filter with reasons for entries that require unported systems. See [recovery rules](docs/RECOVERY.md), [the exact catalog](docs/SPELL_CATALOG.md) and [movement/camera validation](docs/MOVEMENT.md).

Both potions can be used during meditation without resetting its timing; filling mana ends it. The meditation FX is 30% smaller and grounded at the feet in front of the body. Spell impacts/results follow the target and words follow the caster. Drag inventory supplies into empty slots or onto each other to rearrange them; the server keeps this session layout and dragging never consumes a potion.

## Class presets

The **Clases** button opens nine AO20-based arena presets with visible armor, weapon, shield and helmet, server-enforced stats and spell permissions, and separate class hotkeys. Hunter uses CTRL/3 to aim, then clicks a rival for an eight-tile physical bow attack without magic. See [class rules, adaptations and test steps](docs/CLASSES.md). These are provisional arena presets; advanced class specialties remain pending.

Only free infrastructure is in scope. Accounts are optional; the private web client still connects to the local WSS dedicated. See [the zero-cost policy](docs/HOSTING_BUDGET.md).

Equipment now lives in the server inventory: drag to move/swap, click to equip/unequip, E marks equipped items. Presets can be switched or reset freely during practice. Initial macros follow control/remover/damage/healing categories. The Zoom 1×/2× control (default 1×) renders the world at integer source-pixel scale; see [CLASSES.md](docs/CLASSES.md).
