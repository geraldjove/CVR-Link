# Release checks

Last verified: **2026-09-14**. Sources: the current test scripts, Windows EXE
checks, native Contractors editor checks, and the recorded local play tests.

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
- 45 native editor checks passed for the updated loadout. They cover holders,
  menus, the HUD, centered crosshair anchors, button bindings, and the compiled
  Discord/download browser actions. The test does not open external sites.
- Local play checks confirmed mouse/WASD, VR return, menus, E pickup, finite
  chest ammo, station refills, stable crouch, the fixed crosshair, close aim,
  wall pullback, icon shape, HUD size, and transparency.

The new popup links still need a live click check. Clean-PC setup, the Windows
permission prompt on a protected Steam folder, more guns and maps, respawns,
long sessions, and mixed VR/flatscreen multiplayer need more live checks.
Tests do not prove support for every machine, weapon, or game update.

The supplied runtime checks the exact loadout plan, local player choice, and
app lease. It restores VR when a check fails. This is not server-side enforcement.

The first EXE is unsigned. No signing certificate, game account data, telemetry,
or upload credentials are included. UE4SS 3.0.1 is bundled under its MIT license.
