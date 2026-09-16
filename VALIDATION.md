# Release checks - CVR Link 0.2.9

16 September 2026. Code checks and play tests are separate evidence.

## Code and build checks

- 534 checks across ten Lua suites: camera 51, controls 175, inventory 55,
  ammo 23, item actions 14, placement 21, settings 56, room 36, menu 82, HUD 21.
- 35 installer checks cover setup, repair, upgrades from 0.1.0 and 0.2.0
  through 0.2.8, backups, conflicts, removal, and failed-save rollback.
- Native form and 57 GUI settings-file checks pass. The form source is unchanged;
  its earlier key capture, save/reset, and visual review still apply.
- Native release EXE, PowerShell syntax, and the 17-file EXE source/vendor/
  private-data scan pass. Only the 34 approved files enter the public export.
- A native editor test confirms the stock ammo can is skipped with ignore-self,
  while a real wall still blocks the retry. The Lua regression test models
  the pinned loader's dropped array inputs and failed before the fix.
- No assets changed. The 0.2.3 loadout retains 115 reopened Blueprint checks,
  three successful cooks, and 25 PAK entries per platform.

## Play checks and limits

The player confirmed stock ammo refills on Lumber in local preview 0.2.8.
The log shows two one-magazine refills spending a supply charge each.
Repeated E presses with full chest ammo spent no extra charges.

The release removes local logging from Inventory.lua; its decision logic was
compared with the tested preview. The other nine Lua files and settings form
are identical. Wider stock/custom maps, empty supplies, cooldown, live range
and wall rejection, mixed PC/Quest, and dedicated servers still need tests.

Earlier F9/menu, FOV, automatic bolts, Quest welcome, and multiplayer access
were confirmed in their respective builds. The original sky-facing join
angle was not captured. Wider joins, respawns, and long sessions remain open.
Clean-PC/UAC setup and signing remain open. Gadget hands stay hidden;
loose-round guns lack keyboard reload. Quest uses VR controllers.

The exact loadout gate and live helper lease stay in place. Public source
contains no private history, local logs, credentials, or game assets.
UE4SS 3.0.1 is bundled with its MIT license.

## Files and downloads

CVR Link 0.2.9 EXE SHA-256:
`174D200526D70D504D6B12B30DB8914B789E1D01CC121EA83D7BC0DCA4CA7A22`.

The installed, player-confirmed 0.2.8 preview is kept in place during publication.
Mod.io 6383627 keeps Windows 8218361 (default), server 8218362, and Android
8218363, all loadout 0.2.3. The ammo fix needs the Windows app update.

The anonymous EXE and SHA256SUMS downloads match the checked build. Tag
`v0.2.9` points to `321f28daa80d1833f94f6a59be72902e29c95d66`.
The public export's 534 Lua and 35 installer checks pass. All three mod.io
ZIP downloads match, including exact entry names and unpacked PAK hashes.
Windows remains the default. The page and all three package notes link to
CVR Link 0.2.9; metadata, tags, and Android-filtered discovery pass readback.
