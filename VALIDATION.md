# Release checks - CVR Link 0.2.4

16 September 2026. Code and build checks do not replace play tests.

## Code and build checks

- 526 checks across ten Lua suites: camera 51, controls 175, inventory 47,
  ammo 23, item actions 14, placement 21, settings 56, room 36, menu 82, HUD 21.
- 30 installer checks cover setup, repair, upgrades from 0.1.0 through 0.2.3,
  backups, conflicts, removal, and failed-save rollback.
- Native settings form: pointer action, capture button, key save, reset,
  and visual review. 57 GUI settings-file checks pass in the release.
- Native release EXE startup, PowerShell syntax, the 34-file public export,
  and the 17-file EXE source/vendor/private-data scans pass.
- Read-only editor probes confirm the stock stationary UI, forced UI, and
  menu input branches used by the fix. No asset changes were needed.
- The 0.2.3 loadout keeps its earlier 115 reopened Blueprint checks, three
  successful cooks, and 25 PAK entries on each platform. Exact ZIP paths and
  decompressed PAK hashes are checked when updating the mod.io notes.

## Play checks and limits

The player confirmed that the local pointer/menu preview works correctly.
The release runtime matches that preview. This confirmation does not cover
all maps or repeated join/death/respawn, mixed PC/Quest, or dedicated servers.
The original sky-facing join angle was already gone when captured. F9 lets
players look back toward an off-screen menu; its initial angle needs more checks.

FOV and automatic bolts were confirmed in the earlier preview. The Quest
welcome appeared after reinstalling 0.2.2. The earlier Quest death-menu and
Windows Nuketown startup fixes were confirmed in play.

The earlier multiplayer lock with Experimental start remains unresolved.
No online-access fix is claimed. Clean-PC setup, protected Steam folders,
and long sessions still need tests. The EXE is unsigned. Gadget hands stay
hidden; loose-round guns lack keyboard reload. Quest uses VR controllers.

The loadout gate runs on the player's PC. Public source has no account
tokens, private history, or game files. UE4SS 3.0.1 keeps its MIT license.

## Loadout files

Mod.io 6383627 keeps Windows **8218361** (default), server **8218362**, and
Android **8218363**, all 0.2.3. The 0.2.4 fixes are in the Windows app. The
mod.io page and package notes link to that app. Android discovery and the
existing platform mappings must pass the publication readback.

## Checked app

CVR Link 0.2.4 EXE SHA-256:
`2798A82BADB9E5797B224B3126F18F61C5CCEFE6E8BEF43F9FB1C2C087934E20`.

All ten runtime files and the settings form match the player-confirmed local
preview. Packaging changes only the app/setup version. The installed preview
was not replaced during publication.
