# argentum-godot
My first Argentum Online mini server.

## Web export preparation

The `Web` export preset packages the current Godot arena and its AO data files. The browser client has a connection panel; native editor builds keep the automatic development server and F2 client shortcut.

See [the first Web test guide](docs/WEB_TEST.md) for local testing, export instructions, and the runtime checks required before merging.

## AO20 combat interface

The `work/ao20-combat-ui` iteration adds the original AO20 frame, inventory/spell panels, synchronized health/mana, arena minimap and a bounded combat console. It keeps the stable server's RPC protocol. Spell casting is not part of this interface iteration; Launch remains disabled until the spellbook and combat port are implemented.

See [the interface scope and Windows test guide](docs/COMBAT_UI.md). AO20 artwork attribution, provenance and its separate license are in `assets/argentum/interface/ao20/`.

