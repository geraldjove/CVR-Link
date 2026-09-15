# Release checks - 0.2.1

Last verified: **2026-09-15**. Sources: Lua checks, installer and native EXE
checks, saved editor/package reports, and recorded local play tests.

## Code and build checks

- 476 checks pass across all ten Lua suites: camera 51, controls 141,
  inventory 47, ammo 23, item actions 14, placement 21, settings 42, room 36,
  menu 82, HUD 19. These use fake game objects and do not replace play tests.
- 27 installer checks pass. They cover setup, repair, older app versions
  (0.1.0 and 0.2.0), runtime upgrades, backups, loader conflicts, changed
  files, removal, failed-save rollback, Steam paths, and game version checks.
- The native form check passes for three tabs, 24 controls, settings round
  trips, atomic saves, and Steam startup. Its saved INI passes 43 checks.
  The new 0.2.1 EXE passes its isolated startup check.
- The EXE contains 17 approved files. Embedded runtime files match source;
  pinned UE4SS files match their official hashes. Private-data and PowerShell
  syntax checks pass. All ten Lua files also match the preview tested in Nuketown.
- 79 editor checks passed for the Quest pointer patch. They cover all three
  armor holders, the stock UI ray, opening/closing the desktop popup, menus,
  HUD, button bindings, and crosshair anchors. The same PAKs are used here;
  no new asset edits or cooks were needed for the Windows fix.
- Windows, WindowsServer, and Android ASTC cooks passed. Each PAK contains
  25 files. Each ZIP has one exact forward-slash Content entry, and its
  decompressed PAK hash matches the cook report.

## Confirmed in play

- **This patch, Windows:** Experimental Start in Flatscreen, a CVRFlatscreen
  server, bots, and Nuketown. The player confirmed startup and controls work.
  Game logs show the expected loadout, XR off, gun swaps, recoil, and reload.
- **This patch, Quest:** the player confirmed the death-menu pointer fix works.
  That test does not establish coverage for every map, armor, or controller hand.
- Earlier checks confirmed mouse/WASD, VR return, menus, pickup, chest ammo,
  station refills, crouch, crosshair, close aim, wall pullback, and HUD settings.
- Earlier headset-free checks confirmed return to HQ after leaving a match
  and a clean exit from an unsupported online server.
- Earlier sprint checks confirmed gun motion, faster aim timing, Shift alone
  staying still, and releasing Shift to stop sprint.

The final removal of the after-sprint firing delay is code checked; a separate
live confirmation remains pending. The local Windows app used for the
Nuketown test was a 0.2.0 preview with the same Lua and settings code.
The published app uses version 0.2.1 and passed fresh build/setup checks.

## Release files

CVR Link 0.2.1 EXE SHA-256:
`0DA88B692DC6F971AE20FD5C039149015DCA788659FC6D0F27E36C774476E2D6`.

Mod.io mod 6383627 uses Windows file 8216494, server 8216495, and Android
8216497, all version 0.2.1. Windows is the default file. Their anonymous ZIP
downloads, exact entry names, and decompressed PAK hashes passed the Quest
patch publication checks. This app release keeps those same loadout files.

## Limits

Mixed PC/Quest multiplayer, dedicated servers, clean-PC setup, Windows
elevation on a protected Steam folder, more maps and guns, repeated travel
and rejoining, and long sessions still need tests. A fresh download still
needs Windows play without the local development copy. Gadget hands stay
hidden; loose-round pouch guns lack keyboard reload.

Quest mouse-and-keyboard work is deferred. Quest currently uses VR
controllers. Custom maps must support the player's platform.

The exact loadout, local mode choice, and live app checks run on the player's
PC. Experimental also allows the local HQ. These checks are not server
anti-cheat. The EXE is unsigned. The public source has no account tokens,
private history, or game files. UE4SS 3.0.1 is bundled under its MIT license.
