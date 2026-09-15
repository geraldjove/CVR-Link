# Release checks - 0.2.2 test update

16 September 2026. Code and build checks do not replace play tests.

## Code and build checks

- 485 checks pass across all ten Lua suites: camera 53, controls 141,
  inventory 47, ammo 23, item actions 14, placement 21, settings 42, room 36,
  menu 89, HUD 19. These use fake game objects.
- 28 installer checks pass. They cover setup, repair, upgrades from 0.1.0, 0.2.0 and 0.2.1,
  backups, conflicts, removal, and failed-save rollback.
- The native 0.2.2 EXE startup check passes.
- The EXE contains 17 approved files. Source files and pinned UE4SS files
  match their checked hashes. Private-data and PowerShell syntax scans pass.
- 129 checks pass after reopening the saved Blueprints. They cover all three
  armor holders, Quest and Windows popup behavior, pointer collision, death
  cleanup, links, the player list, and server announcement start/stop/expiry.
- Windows, WindowsServer, and Android ASTC cooks pass. Each PAK has 27 files.
  Each ZIP has one exact forward-slash Content entry. Its decompressed PAK
  hash matches the checked build.
- Native popup and menu images were reviewed. The image helper hit a Slate
  assertion during editor shutdown after saving them. The separate reopened
  Blueprint checks and platform cooks completed successfully.

## Play checks

No Quest device or mixed multiplayer test has run for these new features.
Test the welcome, Continue in VR, bottom-center button, links, death, Respawn,
Change Loadout, leaving/rejoining, and the player list on both platforms.
Test a dedicated server too. PC players need CVR Link 0.2.2 to announce their
mode. Older apps will not appear, so this is not a complete platform list.

The prior 0.2.1 Quest death-menu fix and Windows Nuketown startup fix were
confirmed by the player. Those reports do not establish that 0.2.2 works on
every map, armor choice, or controller hand.

## Limits

Clean-PC setup, protected Steam folders, more guns/maps, and long sessions
still need tests. The EXE is unsigned. Gadget hands stay hidden in flatscreen;
loose-round guns lack keyboard reload. Quest mouse-and-keyboard work remains
deferred; Quest uses VR controllers.

The loadout gate runs on the player's PC. The player list uses reports from
the app. Neither is server anti-cheat. The public source has no account tokens,
private history, or game files. UE4SS 3.0.1 is bundled under its MIT license.

## Checked app

CVR Link 0.2.2 EXE SHA-256:
`F9C9320D1E2ED0532ADEE40C1C976CEFEF4316DA5135C24369A1B1C0CB7EC44A`.

## Published downloads

The anonymous EXE and SHA256SUMS downloads match. Tag `v0.2.2` points to
`a1befff8c3edd256b02271a9bce0bd7e20d94d8d`.
Mod.io 6383627 uses Windows 8217880 (default), server 8217881, and Android
8217882, all 0.2.2. Anonymous ZIP downloads, exact entry names, and decompressed
PAK hashes match. Platform tags are preserved, and an Android-filtered search
finds the mod. The new Quest and multiplayer behavior still needs play tests.
