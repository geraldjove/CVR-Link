# Release checks - CVR Link 0.2.42 / loadout 0.2.5

18 September 2026. Code/package checks and play results are separate.

- All ten Lua 5.4 suites pass: camera 61, controls 362, inventory 59, ammo 44,
  items 19, placement 22, settings 56, room 36, menu 85 and HUD 22 (766 total).
- Flat menu 55, display 33, scope/FOV/lifecycle 30, HUD creation/spread 18
  and menu discovery 14 pass. All 15 exported Lua suites pass.
- New cases cover inherited click-only capture on activation, travel and
  pawn replacement; stationary menus, spawn, missing/replaced menu trees,
  F9, Tab/Escape and forced UI. The old code fails the new regressions.
- Native form and EXE checks pass. Saved GUI settings 57 and display 34
  checks pass. Display app backup, launch and layout checks pass (14).
- 49 installer checks include upgrades from 0.2.41. Eight scope-package
  ownership/repair/removal checks pass. Scope assets are unchanged.
- The exact 24-entry public EXE payload matches reviewed source and pinned
  vendor hashes. Private-data scans and PowerShell syntax pass. The pinned
  upstream UE4SS DLL is allowed to contain its own build paths only after
  its exact hash matches; it is still scanned for secret patterns.
- The clean 48-file public source export builds and passes the same payload
  checks. It excludes private access/freecam and archived DLSS controls.

Public EXE SHA-256:
`0E48D30F17B3E182C91DA3250930ECEC4E5CF554DFB838AF22E0C6CAF81BB586`.
Scope PAK SHA-256, unchanged from 0.2.41:
`E56D5E4F5514783F847F1ACBFB126A6DE01E2B7BEF116D7E6E781FD80FBC2E70`.

The maintainer confirmed that the flat join/loadout screen is clickable and
mouse look works after spawning without holding a button or toggling Tab
in Dev 0.2.42. Public uses the same fix with its existing access checks.
That preview result is not a new public shipping-game play test. Repeated
death/respawn, more maps and custom menu layouts remain open. Some custom
menus crowd their panels into one row.

The 0.2.40 Dev scope/blur and ADS play results, and 0.2.41 asset checks,
retain their original limits. This update changes no assets. Other optics,
FPS gains, ballistic marks, VR peers and Quest menu use still need checks.

Public matches retain the exact CVRFlatscreen plan, local mode choice and
live-app checks. Experimental permits only the standalone stock HQ exception.
The loadout stays 0.2.5: Windows 8222067, server 8222068 and Android 8222069.
The EXE remains unsigned. Prior release 0.2.41 is retained for rollback.
