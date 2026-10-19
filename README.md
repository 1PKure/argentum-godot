# argentum-godot
My first Argentum Online mini server.

## Web export preparation

The `Web` export preset packages the current Godot arena and its AO data files. The browser client has a connection panel; native editor builds keep the automatic development server and F2 client shortcut.

See [the first Web test guide](docs/WEB_TEST.md) for local testing, export instructions, and the runtime checks required before merging.

## AO20 combat interface

The AO20 frame includes inventory/spell panels, synchronized health/mana, arena minimap and a bounded combat console. The book imports all 213 original AO20 entries and enables 39 spells with implemented PvP rules: select → Launch → target click, or a numeric hotkey → target click. Drag spells onto the hotkey bar to reassign them. Escape/right click cancels aiming; WASD stays active and CTRL remains a physical attack without a mana cost.

Use the same branch for the dedicated server and restart it after updating. `tools/Start-PrivateWebTest.cmd` imports the project before launching WSS. The spell protocol checks server support with protocol 16; player updates now redact enemy mana and physical hits use participant-only feedback.

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

## Practice bot

Use **Bot** in the combat HUD while alone: choose one of the nine classes and activate, restart or remove the server-driven opponent. It uses existing movement/combat/recovery rules. Starting or restarting prepares both presets; death stops the practice. A second human joining or the owner's disconnect removes the bot. No lobby isolation is added yet. See [BOTS.md](docs/BOTS.md) for controls, behavior, tests and limits. Class statistics keep the accepted baseline; Apocalypse and Discharge have an explicit 8% arena damage reduction. Hunters use a separate 1200 ms arrow interval. Nonmagical presets contain no blue potions. The bot uses the same 120 ms movement steps and slightly slower action decisions and varied continuous bursts while attacking or recovering; see [ACTION_INTERVALS.md](docs/ACTION_INTERVALS.md) for the slightly faster player cadence. Restart the dedicated server after updating; protocol 16 is required.

Numeric macros and clicked hotkeys preserve the chosen inventory/spell tab. Drinking red/blue potions by click or Q/E keeps the target cursor armed, so manual Launch and macros can be used independently.


Clicking a potion selects and drinks it; its golden marker follows inventory rearrangement. **Use / Space** drinks the selected potion, and holding repeats. Click plus Use deliberately combines two 280 ms lanes with a shared 200 ms floor; Q/E aliases Use. Spells/macros remain armed. Text entry, modals, death, focus loss and disconnect stop repeated use. See [RECOVERY.md](docs/RECOVERY.md).

The practice bot now moves at the same 120 ms cadence as the player, uses confirmed Apocalypse/Discharge combos with a legal cheaper follow-up, breaks repeated movement axes and shares a 1250–1350 ms clock for attack/Remove/healing. Inventory items move by right-button drag; left click remains Use/equip. Character names sit below resource bars, and confirmed arrows play the original AO20 impact audio.

### Skins and round preparation

**Bot** starts each practice with a server-enforced **3 → 2 → 1 → GO** countdown, tweens and generated tones. Confirmed victories unlock cosmetic outfits at **1, 3 and 5 wins per class**, with three distinct class-appropriate outfits for each of the nine classes. Open **Skins** to preview/equip; the original class outfit remains available. Cosmetics preserve stats and equipped items and are replicated to other players. Changing class/reappearing restarts both presets and the countdown. Bot balance is unchanged.

Progress is saved locally in the same browser/device, without accounts or paid services; clearing browser data removes it. See [BOTS.md](docs/BOTS.md). Arrow impact now uses the supplied **Arrow hit 2.wav**, with source/hash recorded under `assets/argentum/custom/audio/`.

Class-aware rewards retain the previous local wins and selected tier. Mage/Druid rewards remain robes; Hunter and every other class avoid their starter body and duplicate rewards. Confirmed arrow impacts add a brief target-following pixel blood burst while preserving the supplied sound. See docs/BOTS.md for the class reward table and migration details.

Outfits use the original animated body atlases, with 27 distinct rewards across classes and Mage variants close to the Legendary robe. The arrow blood burst now lasts 500 ms, holds its contrast before fading, and is checked through rendered pixel differences at real 1x scale. Gameplay loadouts/restrictions remain unchanged.

Skins now unlock at 1/3/5 victories **per class**, with independent equipped selections. All 27 reward animations differ across collections. Mage robes follow the Legendary silhouette; other classes have varied themed outfits. The first extra victory on a completed collection invites another incomplete class and opens its selector without applying automatically. Existing global saves migrate once to Mage (their old format stored no winning class); all other collections start independently. Client/server use protocol 16.

The compact HUD footer keeps health/mana, status and Menu. Meditation/potion/Use buttons are removed; M, Q/E, held Space and inventory clicks remain active. Respawn is available inside Menu only while dead. The Mage fifth-win reward is the original AO20 blue robe (body117 / OBJ238), preserving the first two robes and all per-class progression.

## Cuatro escenarios PvP

**Menú → Arenas** permite al anfitrión cambiar entre Bosque, Desierto, Lava y Sala de Duelos. El servidor sincroniza escenario y reinicio, conserva clase/skin y reinicia la cuenta del bot sin premiar rondas interrumpidas. Cliente y dedicado usan protocolo **16**. Sigue siendo una arena compartida por servidor: las salas aisladas y Listo corresponden al próximo PR.

Ver [escenarios y pasos de prueba](docs/ARENAS.md) y [orden de los siguientes PR](docs/ROADMAP.md).
