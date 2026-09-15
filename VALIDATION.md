# Release checks - 0.2.0

Last verified: **2026-09-15**. Sources: Lua checks, installer and native EXE
checks, editor verification, package scans, and recorded local play tests.

## Code and build checks

- 462 checks across all ten Lua suites: camera 47, controls 131, inventory 47,
  ammo 23, item actions 14, placement 21, settings 42, room 36, menu 82, HUD 19.
  These use fake game objects and do not replace play tests.
- 26 installer checks pass for setup, repair, upgrades from 0.1.0, preserved rollback
  backups, loader conflicts, changed files, removal, failed-save rollback,
  Steam library paths, and unsupported game versions.
- Native settings checks cover the three tabs, 24 key choices, ranges,
  duplicate/reserved keys, Experimental startup settings, and saved-file reading.
  The 0.2.0 EXE check passes; its saved INI passes all 43 settings checks.
- The EXE contains 17 approved files. Embedded runtime files match source;
  pinned UE4SS files match their official hashes. Private-data scans pass.
- 51 editor checks passed after reopening the generated assets. They cover
  holders, menus, HUD, button bindings, crosshair anchors, and the Quest menu guard.
- Windows, WindowsServer, and Android ASTC cooks pass. Each PAK contains 25
  files. Each ZIP has one exact forward-slash Content entry; the decompressed
  PAK hash matches its cook report. Integrity checks and content scans pass.

## Confirmed in local play

- Mouse/WASD, VR return, menus, pickup, chest ammo, station refills, crouch,
  crosshair, close aim, wall pullback, HUD icon shape, size, and transparency.
- Headset-free launch with the headset disconnected and flatscreen remaining
  active across local pawn replacements in a CVRFlatscreen bot match.
- Leaving a headset-free match returns to HQ without the earlier UE crash.
- Rejection from an unsupported online server leaves a clean HQ with no old
  server membership or further player-join notices.
- Sprint gun motion, faster aim timing, Shift alone staying still, and
  releasing Shift to stop sprint.

The final removal of the after-sprint firing delay is code checked; separate
live confirmation remains pending. The new platform guard is editor checked;
the 0.2.0 loadout PAKs still need new live play checks.

## Published download checks

CVR Link 0.2.0 is published on GitHub. Its anonymous EXE download matches:
`200E2232FCC4EA161A6CBB38B4A91BD73F2796B99DA3F3C5F418188A82EC145A`.
The release tag points to source commit `9ce0c652eafa43848964f2934ff25fc028529433`.

Mod.io mod 6383627 uses Windows file 8216405, server 8216406, and Android
8216407. The Windows file is the default. Public platform metadata and all three
anonymous ZIP downloads match the checked release. Decompressed PAK hashes
also match. These downloads do not establish live multiplayer support.

## Limits

Quest device play, mixed PC/Quest multiplayer, dedicated servers, clean-PC
setup, Windows elevation on a protected Steam folder, more maps and guns,
repeated travel/rejoin, and long sessions remain unverified. A fresh download
still needs play without the local development copy. Gadget hands stay hidden;
loose-round pouch guns lack keyboard reload support.

Quest mouse-and-keyboard work is deferred. The current Quest loadout is a VR
controller preview. Custom maps must support the player's platform.

The exact loadout, local mode choice, and live app checks run on the player's
PC. Experimental also allows the local HQ. This is not server anti-cheat.
The EXE is unsigned. No account tokens, private history, or game files are in
the public source. UE4SS 3.0.1 is bundled under its MIT license.
