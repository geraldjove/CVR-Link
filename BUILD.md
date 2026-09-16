# Build CVR Link

Use Windows with Windows PowerShell 5.1 and .NET Framework 4.8. No paid tools
or extra package manager are needed. The build uses the C# compiler in Windows.

Run from this repo:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File release\Build.ps1
```

This downloads the official UE4SS 3.0.1 ZIP and checks its SHA-256 hash before
using its two loader files and default settings. It does not bundle sample
mods. Output: `.deps/release/CVRLink.exe`.

The build embeds `release/CVRLink.ico`. The same icon appears on the app,
setup window, settings window, and shortcuts.

The EXE runs the packaged WinForms settings script inside a Windows PowerShell
runspace. No terminal or separate PowerShell process opens during normal use.
The game still needs UE4SS and the CVRFlatscreen loadout.

Run installer and native form checks:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File release\check-setup.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File Control.ps1 -Check
```

Run all `check*.lua` files from the `runtime` folder using Lua 5.4. These checks
use fake game objects. They do not replace play tests.

The public runtime must keep the exact loadout check in `runtime/Room.lua`,
the local mode choice, and the live app lease. Hot reload stays off.

Release files are built from an explicit file list. Do not add logs, settings,
game files, crash dumps, private notes, or downloaded examples to Git. Review
both the staged changes and the EXE's packaged files before each release.
