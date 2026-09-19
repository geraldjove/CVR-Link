# CVR Link

Mouse, keyboard and HUD controls for Contractors VR on Windows.

**CVR Link 0.2.73 — 19 September 2026.**

Author: **_mintyfishy**. [Discord](https://discord.gg/432n3NTq9f) ·
[Downloads](https://github.com/geraldjove/CVR-Link/releases/latest).

## Three loadouts, one app

CVR Link works with [CVRFlatscreen Standard](https://mod.io/g/contractors/m/cvrflatscreen),
[CVRFlatscreen WW2](https://mod.io/g/contractors/m/cvrflatscreen-ww2) and
[CVRFlatscreen Ninja](https://mod.io/g/contractors/m/cvrflatscreen-ninja).
Each is its own loadout. Choose one when hosting, or join a room using it.
Update the Windows app to 0.2.73 and the chosen loadout to Standard 0.2.7
or WW2/Ninja 0.1.1. Standard keeps its
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

- Fixed the save-tag issue that could bring back old weapons after respawning.
  Choose your gear and press **Save** once after updating.
- CVR Link checks for new releases when it opens.
- The new **Updates** tab lets you check again and install a newer version.
  Close Contractors first. The download is checked and your settings are
  saved before the new installer opens.

Download 0.2.73 once to get the updater. Older versions cannot update
themselves. Later updates can be installed from inside the app. Checks run
in the background, and you choose when to install. Loadout mods still
update through Contractors. Standard 0.2.7 and WW2/Ninja 0.1.1 stay current.

Normal recoil, reduced pistol camera shake, bow controls and melee reach
stay, along with the earlier scope, sight and resting-hand fixes. No keybind changes.

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

Standard and WW2 saves survived respawn in the private .72 preview's local
bot matches. Remote-client, rejoin/restart and Ninja save tests remain.
The source gameplay was tested in the private preview. Gerald accepted
bare iron-sight feel, bow aim, Ninja equipment/smoke, melee reach/rotation,
lower-right rest and Shift attacks. This is not proof that every weapon,
map or network case works. Gerald also confirmed Ninja and WW2 server menus and equipped spawns on Dev .68, natural resting arms, a clear sword view, and no issue in his unnamed sight sample. The new gated public app and updated loadout
packages still need broader combined shipping-game tests.

Windows, server and Android packages are built separately. Quest remains
VR/controller-only; CVR Link runs on Windows. New WW2/Ninja Quest and mixed
PC/Quest play need device tests. Repeated join/crouch, remote-client saves,
bow flight, other melee weapons and low-frame-rate contacts need more checks.
The brief freeze at the start of some explosions is still unresolved.

Found a bug? Include the app version, loadout, item, map, whether you hosted
or joined, and what happened. See [validation](VALIDATION.md),
[patch notes](PATCH-NOTES.md) and [open tasks](TODO.md).
