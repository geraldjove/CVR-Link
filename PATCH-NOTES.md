# CVR Link 0.2.9 - Stock ammo box fix

16 September 2026

## What's fixed

- **E now works at stock ammo boxes.** Aim at the box and press E to refill
  your chest ammo while keeping your gun in hand.
- Refills use the box's normal supply charges. Full chest ammo uses no charge.
- The two-metre reach and wall checks stay in place.

The fix is confirmed on Lumber. More stock and custom maps still need tests.

## How to update

Close Contractors and CVR Link. Download
[CVR Link 0.2.9](https://github.com/geraldjove/CVR-Link/releases/tag/v0.2.9),
open it, and click **Install CVR Link**. Use the updated desktop shortcut
next time. Your keys and settings stay saved. Opening an older EXE can put
older mod files back, so use the new copy after setup.

The fix needs the Windows app update. The Windows, Quest, and server loadout
files stay at **0.2.3**. Quest players keep using their normal VR controllers.

## Still included

F9 pointer control, the Tab menu fix, FOV from 80 to 120, automatic bolt
cycling, and the Quest welcome remain. The flatscreen player list stays
removed. Multiplayer access is working again, as confirmed in the earlier build.

## Checks

The Lumber play test shows ammo refilling and supply charges being spent.
Repeated E presses with full chest ammo spent no extra charges. All 534 Lua
checks pass. Installer, app, and native collision checks also pass.
Wider maps, empty boxes, cooldown, mixed PC/Quest play, and dedicated servers
still need tests.

Author: **_mintyfishy** | [Discord](https://discord.gg/432n3NTq9f) |
[CVR Link](https://github.com/geraldjove/CVR-Link) |
[CVRFlatscreen](https://mod.io/g/contractors/m/cvrflatscreen)
