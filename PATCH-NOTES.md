# CVR Link 0.2.4 - Pointer and menu fix

16 September 2026

## What's new

- **F9 switches pointer and mouse look.** If a menu is outside your view,
  press F9, look toward it, then press F9 again to click it.
- **Tab keeps menus from overlapping.** It no longer opens the pause menu
  over the loadout or respawn screen. Those screens keep their pointer.
- **Pointer key setting:** change F9 under **Pointer / mouse look** in CVR
  Link. Existing custom keys stay in place. If F9 is already used, the new
  action takes the first free key starting with F10.

Looking around an open menu keeps weapon and movement actions paused.
Opening or closing a screen resets the pointer choice.

## How to update

**Windows:** close Contractors and CVR Link. Download
[CVRLink.exe](https://github.com/geraldjove/CVR-Link/releases/tag/v0.2.4),
open it, and click **Install CVR Link**. Use the updated desktop shortcut.
Your saved settings stay in place. Updating the loadout alone does not update
CVR Link.

The Windows, Quest, and server **loadout files remain at 0.2.3**. They already
have the current game assets. Quest players keep using VR controllers and do
not need the Windows app.

## Test status

The player confirmed the pointer/menu preview works correctly in game.
All 526 Lua checks pass, along with installer, settings, and app checks.
The release uses the same runtime as that preview. Wider maps, repeated
join/death/respawn, mixed PC/Quest play, and dedicated servers still need tests.
The original sky-facing join angle was not captured; F9 offers a way to look
back toward an off-screen menu.

FOV 80 to 120, automatic bolt cycling, and the simpler menu from 0.2.3 remain.
The earlier multiplayer lock with Experimental start is still unresolved;
this release does not include an online sign-in fix.

Author: **_mintyfishy** | [Discord](https://discord.gg/432n3NTq9f) |
[CVR Link](https://github.com/geraldjove/CVR-Link) |
[CVRFlatscreen](https://mod.io/g/contractors/m/cvrflatscreen)
