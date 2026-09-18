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

The EXE is not code-signed. Windows may show an unknown-publisher notice.
Get it from this repo's Releases page. The SHA256SUMS file lists its file hash.

## Start playing

You need the **Windows Steam version** of Contractors VR for CVR Link.
Normal VR start uses a connected headset, SteamVR, and Virtual Desktop.
For a monitor without a headset, use **Experimental start** below.

Keep CVR Link open. Start Contractors in VR and enter a room with the
**CVRFlatscreen** loadout. Open **CVR Link** from the game menu or press **F8**, then choose **Play in Flatscreen**. Switch
Virtual Desktop to **Desktop view**, then click the game on the flat screen.
You should see the screen's edges. Use **Play in VR** to return to headset play.

Open the CVR Link pause page with **F8** or its game-menu button.
It stays closed when you join. VR players can find downloads and Discord there.

**Loadout release:** 0.2.5 test update for Windows, server, and Quest on
[CVRFlatscreen on mod.io](https://mod.io/g/contractors/m/cvrflatscreen).
Subscribe to CVRFlatscreen in the game. Matches need that exact loadout on any
map. Installing the app alone does not add it to the game's loadout list.
Your flatscreen choice stays through death and respawn while CVR Link stays on.

### What's new in CVR Link 0.2.41

The AWM has a larger, clearer scope with a softly blurred background.
Iron and holographic sights get a short ADS zoom. Pause pages lie flat
on your monitor, and the centered crosshair spreads with recoil.
UI Settings adds V-Sync, an FPS limit, window size and borderless mode.
FOV/display flicker and repeated menu searches are fixed.

DLSS 5 is archived and its controls are removed. Existing add-on files and
settings are left alone. The old F6 scope/zoom action is removed too.
Right mouse still aims. See the [patch notes](PATCH-NOTES.md).

Update the Windows app. Keep loadout 0.2.5 installed; its Windows, server
and Quest files are unchanged. The EXE includes the scope UI package.
The large scope currently supports the tested AWM reticle; other sights,
maps and mixed VR play need more tests.

### Experimental start without a headset

1. Close Contractors normally and open CVR Link's **Experimental** tab.
2. Turn on **Start in Flatscreen (experimental)**.
3. Click **Save and start Contractors**. Steam must be signed in.
4. Play from your local HQ, then join a **CVRFlatscreen** match on any map.

Joining another loadout stops flatscreen and returns a headset-free player to
HQ, leaving the old session. To play in VR again, close the game, turn off the
option, and restart with your headset. Saving the option alone does not change
how a running game was started.

### Quest crossplay preview

Update the loadout in Contractors and restart the game. Quest players keep
their normal VR controllers and do not need CVR Link. The CVR Link game-menu button opens
an information page with Continue in VR and help links. It does not open on join. Flatscreen play needs the
Windows PCVR game and CVR Link on a PC. More maps, armor choices, and mixed
PC/Quest matches still need tests. Custom maps must support Quest too.

## Change your settings

- **Keybinds:** click an action, then press its new key or mouse button.
- **Mouse sensitivity:** change normal mouse speed.
- **Aim sensitivity:** change mouse speed while aiming.
- **UI Settings:** set FOV from 80 to 120, HUD size from 50% to 150%, and transparency from 0% to 90%. PC display has V-Sync, FPS and resolution controls for headset-free play.
- **Save settings:** apply your changes in the running game.

Click **Apply display settings** for PC display changes. Keep a new mode within
15 seconds or it reverts. FPS 0 means Unlimited. Borderless uses the desktop
resolution. Confirmed choices are saved separately; original game display
preferences return after exit while the app stays open.

The app shows **Settings applied in game** when the game reads your changes.
Two actions cannot share a key. F7, F8, Escape, mouse look, and menu scrolling
stay fixed. See **[all default controls](KEYBINDS.md)**.

## What flatscreen adds

Mouse look keeps the view level. Guns follow your aim and keep normal recoil.
The crosshair stays in the center and spreads with recoil. Hip aim stays steady across near and far
objects. Close walls push the gun back and down; blocked shots need a fresh
click after you move clear. Aiming eases
into the sights with a short iron/hologram zoom. Tab opens/closes flat pause pages; Escape closes them. F9 still switches pointer and mouse look.

Hold **Shift + forward** to sprint and lower the gun. Release either key to
stop. Shift alone leaves you still. The gun rises over 0.5 seconds; aim and zoom
can start after 0.3 seconds. Firing is available as soon as sprint stops. Shots
pressed during sprint are not queued; click again afterward.

Bolt-action guns cycle after a short pause. They use real magazine rounds.

Magazine reloads take 1.5 seconds and use a matching chest magazine. Shotguns
load one shell every 0.5 seconds. The stock Magnum spends a speedloader after
0.5 seconds per missing round. When spare rounds run out, use an ammo station. Gear moves down and up when you
swap. Main gun and sidearm swaps wait one second in both directions.

The HUD shows loaded rounds, spare chest rounds, your pose, and the held item's
icon and name. It hides in VR and menus. Aiming hides the crosshair.

## Stop or remove it

Press **F7**, or close CVR Link. Flatscreen stops within about two seconds.
Turning the link back on needs a new Flatscreen choice in the CVR Link pause page for
normal mode. Experimental resumes only in the local HQ or an allowed match.

To remove the game mod, close Contractors and CVR Link. Open Windows **Settings
> Apps**, find **CVR Link**, and choose **Uninstall**. Setup restores its backups
when the installed files have not changed. It keeps files used or changed by
other mods. It keeps your settings, app cache, and backups on this PC.

Key and HUD settings are in `%LOCALAPPDATA%\ContractorsFlatscreen`.
The app and install backups are in `%LOCALAPPDATA%\CVRLink`.

## Early release limits

More guns, maps, respawns, long sessions, and mixed VR/flatscreen matches still
need play tests. Gadget hands are hidden for now. Quest and Windows server packages
still need live multiplayer tests. A fresh
in-game download also needs a play check without the local development copy.

Matches allow flatscreen only with the exact CVRFlatscreen loadout. Experimental
also permits the local HQ. Other loadouts restore VR after a normal VR start;
headset-free starts leave that session and return to HQ. These checks run on the player's PC; they
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
Read [0.2.41 patch notes](PATCH-NOTES.md) and [future tasks](TODO.md).

Last verified: **2026-09-18**. Sources: source checks, native desktop and editor
checks, mod.io download checks, and the recorded local play tests. See [VALIDATION.md](VALIDATION.md)
for what was checked and what still needs a live test.
