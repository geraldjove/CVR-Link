# Release checks - 0.2.3

16 September 2026. Code and build checks do not replace play tests.

## Code and build checks

- 502 checks across ten Lua suites: camera 51, controls 157, inventory 47,
  ammo 23, item actions 14, placement 21, settings 52, room 36, menu 82, HUD 19.
- 29 installer checks cover setup, repair, upgrades from 0.1.0 through 0.2.2,
  backups, conflicts, removal, and failed-save rollback.
- Native EXE startup, settings form, and 53 GUI settings-file checks.
- The EXE has 17 approved files. Source and pinned UE4SS hashes match.
  Private-data and PowerShell syntax scans pass.
- 115 checks after reopening the Blueprints cover three armor holders,
  Windows/Quest popup behavior, pointer collision, death cleanup, links,
  the retained menu button, and removal of player reporting.
- Windows, WindowsServer, and Android ASTC cooks pass. Each PAK has 25 entries.
  Each ZIP has one exact forward-slash Content entry. Its decompressed PAK
  hash matches the checked build.
- Native editor chambering checks pass on AWP, Sako 85, Kar98, Lee-Enfield,
  Mosin, and De Lisle through the last round without creating ammo.

## Play checks and limits

The player confirms FOV and automatic bolt cycling work in the local preview.
The released runtime matches that preview. This does not establish every gun,
map, or scope view. The preview without the player list still needs live menu,
death/rejoin, mixed PC/Quest, and dedicated-server checks.

The earlier Quest death-menu and Windows Nuketown startup fixes were confirmed
in play. The Quest welcome and menu appeared after reinstalling 0.2.2.

Multiplayer has been reported as locked with Experimental start. Steam sign-in
succeeded, but the game's login state and root cause are still unverified.
No online-access fix is claimed in 0.2.3.

Clean-PC setup, protected Steam folders, and long sessions still need tests.
The EXE is unsigned. Gadget hands stay hidden; loose-round guns lack keyboard
reload. Quest mouse-and-keyboard work is deferred; Quest uses VR controllers.

The loadout gate runs on the player's PC. It is not server anti-cheat.
Public source has no account tokens, private history, or game files.
UE4SS 3.0.1 is bundled under its MIT license.

## Checked app

CVR Link 0.2.3 EXE SHA-256:
`3F5A1166845F7BAF97C51B21434FBE75DC845AA83E6B2C57B1F74294EBE1045E`.

## Published downloads

The anonymous EXE and SHA256SUMS downloads match. Tag `v0.2.3` points to
`9e61555bdb74d450dd64887d113f4e0a845c9d45`.
Mod.io 6383627 uses Windows **8218361** (default), server **8218362**, and
Android **8218363**, all 0.2.3. Anonymous ZIP downloads, exact entry names,
and decompressed PAK hashes match. Platform tags and asset paths are kept,
and Android-filtered discovery finds the mod. No new device play test ran
as part of publication.
