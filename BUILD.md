# Build CVR Link

Use Windows with Windows PowerShell 5.1 and .NET Framework 4.8. No paid tools
or extra package manager are needed. The build uses the C# compiler in Windows.

Run from this repo:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File release\Build.ps1
```

This downloads the official UE4SS 3.0.1 ZIP and checks its SHA-256 hash before
using its two loader files and default settings. It does not bundle sample
mods. It also downloads the authored `CVRScope.zip` from release 0.2.41,
checks its pinned SHA-256 and exact two entry names, and includes that UI
package. No third-party renderer is bundled. Output: `.deps/release/CVRLink.exe`.

The build embeds `release/CVRLink.ico`. The same icon appears on the app,
setup window, settings window, and shortcuts.

The EXE runs the packaged WinForms settings script inside a Windows PowerShell
runspace. No terminal or separate PowerShell process opens during normal use.
The game still needs UE4SS and one of the three supported CVRFlatscreen loadouts.

Run installer and native form checks:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File release\check-setup.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File Control.ps1 -Check
```

Run the ten main Lua suites from `runtime` with Lua 5.4: `check.lua`,
`check-controls.lua`, `check-inventory.lua`, `check-ammo.lua`, `check-items.lua`,
`check-placement.lua`, `check-settings.lua`, `check-room.lua`, `check-menu.lua`
and `check-hud.lua`. Also run `check-display.lua`, `check-flat-menu.lua`,
`check-scope.lua`, `check-menu-performance.lua` and `check-hud-extra.lua .`.
Give `check-settings.lua` and `check-display.lua` the corresponding
`../.deps/gui-settings.ini` and `../.deps/gui-display.ini` paths after the
form check. These use fake game objects; they do not replace play tests.

From the repo root, also run `release/check-display.ps1`,
`release/check-scope-package.ps1 -Stage .` and `release/Check-Release.ps1`.
The native `CVRLink.exe --check` uses an isolated temporary profile.

The public runtime must keep the exact loadout check in `runtime/Room.lua`,
the local mode choice, and the live app lease. Hot reload stays off.

Release files are built from an explicit file list. Do not add logs, settings,
game files, crash dumps, private notes, or downloaded examples to Git. Review
both the staged changes and the EXE's packaged files before each release.
