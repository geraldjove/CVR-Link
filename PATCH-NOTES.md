# CVR Link / CVRFlatscreen 0.2.0

15 September 2026 · Early release · Quest crossplay preview

## How to update

Close Contractors and CVR Link, download the new **CVRLink.exe** from
[GitHub Releases](https://github.com/geraldjove/CVR-Link/releases/tag/v0.2.0),
and open it to update the Windows runtime. Your saved settings stay in place.
Update the **CVRFlatscreen** loadout through the game's mod browser as well.
The mod.io loadout update does not install the Windows app or Lua loader.

## New features

- **Experimental headset-free start:** CVR Link can launch Contractors on a
  monitor without a connected headset. Open the Experimental tab, turn on
  Start in Flatscreen, then choose Save and start Contractors.
- **Flatscreen in HQ:** Experimental mode works in your local HQ and in matches
  using the exact CVRFlatscreen loadout, including custom maps.
- **Sprint feedback:** The gun lowers smoothly while you sprint, then rises
  over 0.5 seconds when you stop. Aim and zoom can start after 0.3 seconds.
  Firing is blocked only while sprinting, with no delay afterward. Shots pressed
  during sprint are not queued; click again once sprint stops.
- **Quest crossplay preview:** Added an Android loadout package so
  Quest players can join in VR using their normal controllers. CVR Link and
  mouse-and-keyboard play are Windows features. Quest skips the desktop mode menu.

## Fixes

- Flatscreen choice stays active through death and respawn in the same match
  while CVR Link stays connected.
- Fixed the mode menu losing access to Play in Flatscreen after leaving and
  joining another CVRFlatscreen match.
- Fixed a UE crash during cleanup when leaving a headset-free match.
- Fixed unsupported matches returning players to HQ while leaving the old
  server membership active. The tested return now leaves a clean HQ.
- Shift alone no longer requests auto-run. Sprint needs Shift plus your forward
  key. Releasing forward stops sprint, even if Shift stays held. Rebound keys work too.
- Fixed sprint staying active after Shift was released when the game's own
  input started sprint first. Sprint now follows the held keys in flatscreen.
- Kept the mod.io ZIP path fix that resolved the Reinstall loop.

## How the mode rules work

- Keep CVR Link open and enabled for Windows flatscreen play.
- Matches need the exact CVRFlatscreen loadout. Other loadouts restore VR after
  a normal VR start. Headset-free players leave the session and return to HQ.
- A headset-free game needs a restart to use VR. Its Play in VR button explains this.
- Your keys, mouse speeds, HUD size, and transparency stay local to your PC.
- Quest players do not need the Windows app and do not get mouse-and-keyboard controls.

## Known issues and test limits

- Confirmed in play: headset-free startup, return to HQ after leaving a match,
  clean session removal after an unsupported-server join, and the initial sprint motion.
- Faster aim timing, Shift staying still without forward input, and releasing
  Shift to stop sprint are confirmed in play.
- The final after-sprint firing change passes code checks; a separate live
  confirmation is still pending.
- Windows, server, and Quest cooks pass. On-headset play and a mixed PC/Quest
  match still need testing before crossplay can be called verified.
- Broader maps, weapons, repeated rejoining, dedicated servers, and long sessions
  still need play tests. Gadget hands remain hidden. Loose-round pouch weapons
  still lack keyboard reload support.

## Future task

- Investigate standalone Quest mouse-and-keyboard play. This is deferred and
  is not included in 0.2.0. Quest users keep their normal VR controllers.

Author: **_mintyfishy** · [Discord](https://discord.gg/432n3NTq9f) ·
[CVR Link](https://github.com/geraldjove/CVR-Link)

The Windows EXE is unsigned. Download it from the project release page and
use the included SHA256SUMS file to check its hash.
