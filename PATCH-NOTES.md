# CVR Link / CVRFlatscreen 0.2.1

15 September 2026

This patch fixes two problems reported during play.

## What's fixed

- **Quest:** the laser now works on the death menu, so you can pick Respawn
  or Change Loadout. The fix is confirmed on Quest.
- **Windows:** fixed an error that could leave the game stuck in VR when
  entering a match. Flatscreen now waits for your player to finish loading,
  then starts on its own. Tested using CVR Link's Experimental start with
  CVRFlatscreen and bots in Nuketown.

## How to update

**Windows:** close Contractors and CVR Link. Download the new
[CVRLink.exe](https://github.com/geraldjove/CVR-Link/releases/tag/v0.2.1),
open it, and click **Install CVR Link**. Use the updated desktop shortcut
next time. Your saved keys and settings stay in place.

Update **CVRFlatscreen** in the game's mod browser too. The loadout update
does not update the Windows app.

**Quest:** update CVRFlatscreen in the game, then restart Contractors.
You do not need the Windows app. If you already have the 0.2.1 Quest patch,
you already have the latest loadout files.

## Still being tested

More maps, guns, armor choices, long matches, mixed PC/Quest play, and
dedicated servers still need tests. Quest uses normal VR controllers;
Quest mouse-and-keyboard play is planned for later. Gadget hands stay hidden
in flatscreen. Guns with loose-round pouches do not have keyboard reload yet.

Author: **_mintyfishy** | [Discord](https://discord.gg/432n3NTq9f) |
[CVR Link](https://github.com/geraldjove/CVR-Link) |
[CVRFlatscreen](https://mod.io/g/contractors/m/cvrflatscreen)
