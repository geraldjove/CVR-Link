# CVR Link

Mouse, key, and HUD settings for the **CVRFlatscreen** loadout in Contractors VR.

**[Download CVRLink.exe](https://github.com/geraldjove/CVR-Link/releases/latest)**
| **[Join Discord](https://discord.gg/432n3NTq9f)**

Author: **_mintyfishy** on Discord.

## Install with one click

1. Download and open **CVRLink.exe**. Close Contractors before setup.
2. Click **Install CVR Link**. Setup finds the Steam game and adds the needed files.
3. Use the **CVR Link** shortcut on your desktop next time.

There are no terminal commands, ZIP files to unpack, or extra loader downloads.
Windows may ask for permission to write to the game folder. If Steam cannot find
the game, use **Find game**. Setup stops if the game version or an existing mod
loader does not match the tested version.

This first EXE is not code-signed. Windows may show an unknown-publisher notice.
Get it from this repo's Releases page. The SHA256SUMS file lists its file hash.

## Start playing

You need the **Windows Steam version** of Contractors VR, a connected headset,
SteamVR, and Virtual Desktop. This version was tested with that setup. It does
not start the game without a headset and does not run on standalone Quest.

Keep CVR Link open. Start Contractors in VR and enter a room with the
**CVRFlatscreen** loadout. Choose **Play in Flatscreen** in its popup. Switch
Virtual Desktop to **Desktop view**, then click the game on the flat screen.
You should see the screen's edges. Use **Play in VR** to return to headset play.

Open the mode popup at any time with **F8**, or the **CVRFlatscreen** button in
the game menu. VR players can find the app download and Discord links there.

**Loadout release status:** Windows and server files are uploaded to
[CVRFlatscreen on mod.io](https://mod.io/g/contractors/m/cvrflatscreen).
Both downloads match the tested release. Subscribe to CVRFlatscreen in the game.
The app needs that loadout to enable flatscreen. Installing the app alone does
not add it to the game's loadout list. This is the first early app release.

## Change your settings

- **Keybinds:** click an action, then press its new key or mouse button.
- **Mouse sensitivity:** change normal mouse speed.
- **Aim sensitivity:** change mouse speed while aiming.
- **UI Settings:** set HUD size from 50% to 150% and transparency from 0% to 90%.
- **Save settings:** apply your changes in the running game.

The app shows **Settings applied in game** when the game reads your changes.
Two actions cannot share a key. F7, F8, Escape, mouse look, and menu scrolling
stay fixed. See **[all default controls](KEYBINDS.md)**.

## What flatscreen adds

Mouse look keeps the view level. Guns follow your aim and keep normal recoil.
The crosshair stays in the center. Close walls push the gun back. Aiming eases
into the sights; F6 lets you use camera zoom instead.

Reloads lower the gun for 1.5 seconds and use one matching chest magazine. When
your spare rounds run out, use an ammo station. Gear moves down and up when you
swap. Main gun and sidearm swaps wait one second in both directions.

The HUD shows loaded rounds, spare chest rounds, your pose, and the held item's
icon and name. It hides in VR and menus. Aiming hides the crosshair.

## Stop or remove it

Press **F7**, or close CVR Link. Flatscreen stops within about two seconds.
Turning the link back on needs a new Flatscreen choice in the game popup.

To remove the game mod, close Contractors and CVR Link. Open Windows **Settings
> Apps**, find **CVR Link**, and choose **Uninstall**. Setup restores its backups
when the installed files have not changed. It keeps files used or changed by
other mods. It keeps your settings, app cache, and backups on this PC.

Key and HUD settings are in `%LOCALAPPDATA%\ContractorsFlatscreen`.
The app and install backups are in `%LOCALAPPDATA%\CVRLink`.

## First release limits

More guns, maps, respawns, long sessions, and mixed VR/flatscreen matches still
need play tests. Gadget hands are hidden for now. Guns with loose-round pouches
do not yet have keyboard reload support. There is no Quest package. A Windows
server package is uploaded, but it still needs a live server test. A fresh
in-game download also needs a play check without the local development copy.

The supplied code enables flatscreen only in the CVRFlatscreen loadout. It
returns to VR outside that loadout. These checks run on the player's PC; they
are not a server anti-cheat system.

This is a free community mod, not an official Contractors VR product. Settings
stay on the PC. The app has no sign-in, ads, telemetry, or automatic uploads.
Only clicking a community link opens the browser.

## Help and source

[Join Discord for news and help](https://discord.gg/432n3NTq9f), or
[report a bug](https://github.com/geraldjove/CVR-Link/issues).
Contact **_mintyfishy** on Discord. Include the gun, map, and steps that caused
the problem. Do not post account tokens or full game dumps.

The EXE uses the Windows .NET Framework and Windows PowerShell. It bundles the
tested UE4SS 3.0.1 loader from its [official release](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/v3.0.1).
Its MIT notice is in [UE4SS-LICENSE.txt](release/UE4SS-LICENSE.txt).
No game files are included in this repo.

For source checks and building the EXE, see [BUILD.md](BUILD.md).
Last verified: **2026-09-14**. Sources: source checks, native desktop and editor
checks, mod.io download checks, and the recorded local play tests. See [VALIDATION.md](VALIDATION.md)
for what was checked and what still needs a live test.
