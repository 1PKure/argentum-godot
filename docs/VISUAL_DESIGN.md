# Arena presentation design

The presentation identity uses gold and ivory over dark blue charcoal. This first
pass applies to the connection screen only. Gameplay colors remain semantic:
health, mana, hostile effects and cooldowns must stay distinguishable.

| Role | Color |
| --- | --- |
| Background | `#111722` |
| Panel | `#1C2533` |
| Primary action / accent | `#D6B66A` |
| Main text | `#F3F0E8` |
| Supporting text | `#AAB3C2` |
| Connection error | `#FFAB9E` |

`client/ui/arena_presentation_theme.gd` owns the reusable presentation styles.
Apply this theme explicitly to future presentation screens instead of changing
project-wide defaults. Favor thin borders, clear typography and restrained gold
accents. The connection screen uses a centered card and vertical scrolling on
short windows; the address remains editable and keyboard submission is preserved.

## Scope and integration

This branch starts at Alpha `70d7eba`. PR #8 (`work/arena-class-presets`) was
checked for overlap: it does not change the connection panel or this theme.
No gameplay, protocol, class selection, inventory or automatic native connection
behavior changes are included. Future lobby work should reuse these styles after
its interaction flow is implemented. World graphics need a separate representative
arena art pass before replacing assets throughout the game.

## Validation

- Godot 4.7.2 editor import completed.
- Existing `tests/web_connection_smoke.gd`: 18 checks passed, including an actual
  loopback WebSocket connection and canceled retry behavior.
- Temporary runtime layout probe: 1280x800, 800x600, 360x640 and 320x568; no horizontal
  card overflow, usable address field, cancel signal and busy state restored.
- Native visual inspection and Windows/browser playtest remain pending. The
  current environment did not provide a graphical display for screenshot review.

## Manual review

Open the client and disconnect from the arena to inspect the presentation screen
(native development still connects automatically). Check keyboard focus, Enter to
connect, invalid URLs, connecting/cancel and reconnect. Resize the window and verify
that short layouts scroll to the action buttons. In the Web build, also verify the
prefilled WSS address and local-launch instructions.
