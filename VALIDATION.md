# Release checks - CVR Link 0.2.18 / loadout 0.2.4

16 September 2026. Code checks and play tests are separate evidence.

## Code and build checks

- 612 checks across ten Lua 5.4 suites: camera 51, controls 244, inventory 59,
  ammo 23, item actions 19, placement 21, settings 56, room 36, menu 82, HUD 21.
- 44 installer checks cover setup, repair, upgrades from 0.1.0 and 0.2.0
  through 0.2.17, backups, conflicts, removal and failed-save rollback.
- Native form/EXE and 57 GUI settings-file checks pass. The actual settings
  form and embedded C$ Link icon were viewed.
- PowerShell syntax and the 18-file EXE source/vendor/private-data scan pass.
  Only the 35 approved source and document files enter the public export.
- Native AP85, MK18 and AWP tests pass for hip fire and ADS at -85/0/+85.
  They check gun direction and both hand positions after the stock receiver.
- 118 checks pass after reopening the loadout assets. Prior Windows, server
  and Quest cooks apply to these unchanged thumbnail packages. Each PAK has
  27 entries. Exact ZIP entry names and decompressed PAK hashes pass.

## Play checks and limits

The player confirmed preview 0.2.17 looks good after shortening the hip hold.
Earlier reports confirm that guns follow movement, swaps work, local jitter
is gone, rifles and pistols use full up/down aim, ADS looks correct, and the
green line is gone in the tested PC/Quest session.

Release 0.2.18 keeps that gameplay code. It removes only read-only pose
diagnostics and adds the app icon. The other nine runtime files match the
tested preview. The new loadout image is saved in the stock thumbnail field;
its live server-menu appearance has not been verified.

The pistol transition through vertical, recoil, utility pitch/flight, wider
guns/maps, long sessions and dedicated servers remain open checks. Earlier
Lumber ammo, F9/menu, FOV, bolts, Quest welcome and multiplayer access retain
their dated play results. Clean-PC/UAC setup and signing remain open.

The exact loadout gate and live helper lease stay in place. The public
export excludes private history, local logs, credentials and game assets.
UE4SS 3.0.1 is bundled with its MIT license. Quest keeps normal VR controllers.

## Files

CVR Link 0.2.18 EXE SHA-256:
`413B7E7F7CB9C469257893C42BA2E5516B30F2E0C27D11E81BE0EE222A7E2806`.

The player-confirmed 0.2.17 local install is kept during publication.
The weapon fixes need the Windows app update; loadout 0.2.4 carries the image.
Anonymous GitHub EXE/checksum and all three mod.io ZIP downloads match the
checked build, including exact ZIP paths and decompressed PAK hashes.
Windows 8219418 is the default; server 8219419 and Android 8219420 are mapped
in metadata. Android-filtered discovery passes. The page and all file notes
link to app 0.2.18. The tag points to commit `332f289`.
