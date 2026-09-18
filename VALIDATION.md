# Release checks — CVR Link 0.2.41 / loadout 0.2.5

18 September 2026. Source/package checks and play results are separate.

- All ten Lua 5.4 suites pass: camera 56, controls 362, inventory 59, ammo 44,
  items 19, placement 22, settings 56, room 36, menu 85 and HUD 22 (761 total).
- Display 33, flat pause 45, scope/FOV/lifecycle 30 and HUD creation/spread 18
  checks pass. Display app backup, launch and flicker checks pass (14).
- Fourteen public menu-discovery checks verify bounded searches with immediate
  helper-loss and unsupported-loadout rejection. All 15 exported Lua suites pass.
- 48 installer checks and eight scope-package ownership/repair/removal checks.
- Native form and EXE checks; saved GUI settings and display round trips.
  The real form was rendered on all tabs, with no DLSS controls.
- Exact 24-entry EXE payload, reviewed source/vendor hashes and private-data
  scans pass. Public source excludes private access/freecam and archived DLSS.
  The clean 48-file public source export also builds and passes payload checks.
- 141 common asset and 13 public scope asset checks pass in the native editor.
  The public scope Windows cook has five exact PAK entries. The diagnostic
  readback material is absent from this package.

Public EXE SHA-256: `9BED2F720AD9B7D30799A2FF2AD4F6BABE27DFE710A449A498CFEBFE593F8F14`.
Scope PAK SHA-256: `E56D5E4F5514783F847F1ACBFB126A6DE01E2B7BEF116D7E6E781FD80FBC2E70`.

The .40 Dev preview supplied the live AWM 1024 target, 100/80/70 background
comparison, blur/ADS cleanup and AP85 90/81/90 FOV evidence. The .41 public
build has a separate scope package name and passed native load/asset checks;
it is not a fresh shipping-game play test. Other optics, FPS gains, ballistic
holdovers, wider maps, death/travel, VR peers and Quest menu use remain open.

Public matches retain the exact CVRFlatscreen plan, local choice and live-app
checks. Experimental permits only the standalone stock HQ exception.
The in-game loadout stays 0.2.5: Windows 8222067, server 8222068 and Android
8222069. Its published files are unchanged. Download verification is recorded
after publication. The EXE remains unsigned.
