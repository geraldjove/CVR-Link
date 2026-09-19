# CVR Link

Mouse, keyboard and HUD controls for Contractors VR on Windows.

**CVR Link 0.2.62 — 19 September 2026.**

Author: **_mintyfishy**. [Discord](https://discord.gg/432n3NTq9f) ·
[Downloads](https://github.com/geraldjove/CVR-Link/releases/latest).

## Three loadouts, one app

CVR Link works with [CVRFlatscreen Standard](https://mod.io/g/contractors/m/cvrflatscreen),
[CVRFlatscreen WW2](https://mod.io/g/contractors/m/cvrflatscreen-ww2) and
[CVRFlatscreen Ninja](https://mod.io/g/contractors/m/cvrflatscreen-ninja).
Each is its own loadout. Choose one when hosting, or join a room using it.
Update the Windows app to 0.2.62 for WW2 and Ninja. Standard keeps its
existing mod.io page and subscriptions.

The app needs an exact supported loadout, your own choice to play in
Flatscreen, and a running CVR Link helper. A room name cannot enable it.
Other stock or custom loadouts remain locked. Experimental start also
allows the stock local HQ.

## Install and play

1. Subscribe to your chosen CVRFlatscreen loadout in Contractors.
2. Close Contractors. Open **CVRLink.exe**, then click **Install CVR Link**.
3. Keep CVR Link open. Start Contractors and join a supported room.
4. Open the **CVR Link** pause page with **F8**, then choose **Play in Flatscreen**.

For a normal VR start, connect your headset and start SteamVR. In Virtual
Desktop, use **Desktop view** with the screen edges visible, then click the
game window. VR players can keep their normal controllers.

For headset-free play, close Contractors first. In CVR Link's
**Experimental** tab, enable **Start in Flatscreen** and click
**Save and start Contractors**. Restart with your headset to return to VR.
Joining an unsupported match returns a headset-free player to HQ.

The app finds the Steam game, checks its files, and backs up what it changes.
It preserves other installed mods. Use Windows Apps to remove CVR Link.
The EXE is not code-signed. Match its SHA-256 to the release's checksum file.
Keep earlier downloads for rollback, and close the game before switching.

## What's new

- Improved bare iron sights for Standard and WW2 guns, including BREN Mk2.
- Bow: **1** equips it. Hold **left mouse** to draw, release to fire.
  Hold **right mouse** to aim with the hands hidden from view.
- Melee: **V** equips it. Left click makes a fast diagonal slash with blade
  rotation. It rests lower-right and can attack while sprinting.
- Ninja smoke: select its gadget slot, hold left mouse, then release to throw.
- Pistols keep their normal recoil, with much less camera movement during ADS.
- Automatic standing-height calibration after a ready spawn.
- A fix for the in-match loadout Save file mismatch.
- Ammo and menu checks use the current player's vest instead of global scans.
- Each loadout has its own server-selection image and pause page.

Existing controls stay: **WASD** to move, **Shift + forward** to sprint,
**Ctrl/C** to crouch, **R** to reload, **E** to interact, **G** to drop,
**1/2** for main gun/sidearm, and **3/4/5** for gadgets.
See the [full key table](KEYBINDS.md).

Save keybinds, mouse speed, FOV and HUD settings in CVR Link. Display options
include V-Sync, an FPS limit, resolution and borderless mode. Display changes
have Keep/Revert; some external renderers need a restart for resolution changes.
The flat menus, scope view and recoil-spread crosshair remain. F6 scope zoom
is retired; right mouse aims. Existing graphics add-ons are left alone.

## Test limits

The source gameplay was tested in the private preview. Gerald accepted
bare iron-sight feel, bow aim, Ninja equipment/smoke, melee reach/rotation,
lower-right rest and Shift attacks. This is not proof that every weapon,
map or network case works. The new gated public app and separate loadout
packages still need broader combined shipping-game tests.

Windows, server and Android packages are built separately. Quest remains
VR/controller-only; CVR Link runs on Windows. New WW2/Ninja Quest and mixed
PC/Quest play need device tests. Repeated join/crouch, remote-client saves,
bow flight, other melee weapons and low-frame-rate contacts need more checks.
The brief freeze at the start of some explosions is still unresolved.

Found a bug? Include the app version, loadout, item, map, whether you hosted
or joined, and what happened. See [validation](VALIDATION.md),
[patch notes](PATCH-NOTES.md) and [open tasks](TODO.md).
