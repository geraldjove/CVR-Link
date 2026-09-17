# Release checks - CVR Link 0.2.32 / loadout 0.2.5

17 September 2026. Code checks and play tests are separate evidence.

- 758 Lua 5.4 checks: camera 56, controls 359, inventory 59, ammo 44,
  item actions 19, placement 22, settings 56, room 36, menu 85 and HUD 22.
- 46 isolated installer checks cover repair, upgrades, backups, conflicts,
  removal and failed-save rollback. No live game installation is changed.
- Native app/form, 57 GUI settings-file checks and PowerShell syntax checks.
- Exact 18-entry EXE payload, source/vendor hashes and private-data scans.
  Public source contains only the 35 approved files.
- 141 reopened asset checks. The Windows pause PAK matches the local preview.
  Matching server and Quest packages are cooked from the same saved assets.
  Each PAK has 27 entries; ZIP paths and decompressed hashes are checked.

Local previews confirmed shotgun reload firing, magnified scopes, the closer
rifle view and arms, pistol camera movement, idle jitter and the larger pause
page. The reported match-start crash also passed the user's tested route.
The release promotes these fixes while retaining the public exact-loadout
check, local mode choice and live app lease. Development-only access and
free camera are excluded. Quest keeps normal VR controllers.

Wall corners and impacts, more guns/maps, repeated travel, remote VR peers,
Quest pause-page use and dedicated servers still need play checks. Build
checks do not establish those results. The EXE remains unsigned.

EXE SHA-256: `7623629A0B2C8AC723676FFB3430F0BA2F805BDCF3BD2CB323536BE891949F3A`.
Anonymous GitHub EXE/checksum and all three mod.io ZIP downloads match.
Exact ZIP paths and decompressed PAK hashes pass. Windows 8222067 is the
default; server 8222068 and Android 8222069 are mapped in metadata.
Android-filtered discovery passes. Public tag commit: `9c53199`.

The downloaded EXE was also unpacked for fresh access checks: 36 room,
85 menu and 56 camera/lease/restoration checks pass. It requires the exact
CVRFlatscreen plan in matches. Only standalone stock HQ has the Experimental
exception. No private development override is present.
