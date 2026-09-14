# Release checks

Last verified: **2026-09-14**. Sources: the current test scripts, Windows EXE
checks, native Contractors editor checks, mod.io upload/download records, and
the recorded local play tests.

- 324 Lua checks passed using fake game objects: camera 30, controls 107,
  inventory 47, ammo 23, item actions 14, placement 21, settings 31, room 14,
  menu 18, and HUD 19.
- 23 install checks passed in separate test folders. They cover clean setup,
  repair, original backups, loader conflicts, changed files, removal, rollback
  after a failed save, Steam library paths, and an untested game version.
- The compiled Windows EXE passed the native settings form check. The form has
  24 key choices, two tabs, range checks, duplicate/reserved key checks, and a
  save/read check. PowerShell syntax checks passed.
- The real EXE found the Steam game and completed setup from its Install button.
  It opened the settings form, made desktop/Start menu shortcuts, and registered
  Windows Apps removal. All ten installed Lua files matched. Saved settings and
  the pre-existing unrelated mod file kept their exact hashes. Both setup and
  settings windows were visually checked, including author and link labels.
- 47 native editor checks passed for the updated loadout. They cover holders,
  menus, the HUD, centered crosshair anchors, button bindings, and the compiled
  Discord/download browser actions. The test does not open external sites.
- Windows and WindowsServer cooks passed. Each PAK has 25 files under our
  loadout's namespace. Each upload ZIP has only that PAK in Content. The PAK
  integrity checks, extracted-file counts, and private-data pattern scans passed.
  The kit emitted stock asset warnings. A live server test is still pending.
- Local play checks confirmed mouse/WASD, VR return, menus, E pickup, finite
  chest ammo, station refills, stable crouch, the fixed crosshair, close aim,
  wall pullback, icon shape, HUD size, and transparency.

- The final Windows package was installed and play-tested. The author confirmed
  the popup credit, Discord link, GitHub download link, and both play modes work.
  Game status also showed flatscreen activation, a held rifle, and return to VR.
- Both mod.io uploads completed for mod 6383627. The Windows file is 8213876;
  the server file is 8213875. Both were downloaded without signing in, and their
  SHA-256 hashes match the tested release ZIPs exactly. The kit reported upload
  success. A fresh in-game install without the local test copy still needs a
  play check; these download checks do not prove multiplayer or server support.

Clean-PC setup, the Windows
permission prompt on a protected Steam folder, more guns and maps, respawns,
long sessions, and mixed VR/flatscreen multiplayer need more live checks.
Tests do not prove support for every machine, weapon, or game update.

The supplied runtime checks the exact loadout plan, local player choice, and
app lease. It restores VR when a check fails. This is not server-side enforcement.

The first EXE is unsigned. No signing certificate, game account data, telemetry,
or upload credentials are included. UE4SS 3.0.1 is bundled under its MIT license.
