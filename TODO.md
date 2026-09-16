# Future work

## Windows pointer and menus

- [x] Keep the pointer for loadout/respawn and stop Tab stacking the pause menu.
- [x] Add F9 to switch pointer control and mouse look, with a CVR Link key setting.
  Gerald confirmed the local preview works correctly on 16 September 2026.
- [ ] Check wider maps, repeated join/death/respawn, and mixed PC/Quest sessions.
  The initial sky-facing angle was not captured before respawn; keep checking
  first-join camera placement even though the recovery/menu fix is confirmed.

## Quest welcome

- [x] Confirm the 0.2.2 welcome and new game-menu UI appear on Quest.
  Gerald confirmed this after reinstalling the mod on 16 September 2026.
- [ ] Test Continue in VR, reopening with the menu button, all links, and
  Respawn/Change Loadout on the 0.2.2 Quest build.
- [ ] Check that respawn and armor changes do not repeat the welcome, and a
  new match shows it again.
- The flatscreen player list was removed at Gerald's request on 16 September
  2026. Check that only the CVRFlatscreen button remains after updating to 0.2.3.
- [x] Resolve the single-player-only report. Gerald confirmed on 16 September
  2026 that multiplayer access works again with the new build. The exact
  original login cause was not established; the play result is confirmed.

## Standalone Quest mouse and keyboard

Implementation remains deferred on 15 September 2026. Quest support in 0.2.2
is VR controller play. Gerald wants full VR on Quest 3 with both devices paired
by Bluetooth. Local research records the engine
input gates and the remaining unknown in the released game. No delivery date
is set.

**Stop rule:** if this needs permission or help from the Contractors VR
developers, stop Quest 3 mouse/keyboard work. Do not seek developer approval
or pursue a base-game change.

- [ ] Test a Bluetooth keyboard and mouse paired directly to a Quest. Check
  whether a local CVRFlatscreen loadout receives key presses/releases, mouse
  buttons, and continuous relative mouse movement in the shipped game.
- [x] Research the kit and official input docs. Normal Blueprint console writes
  cannot enable the kit's read-only input settings. Retail settings and a
  supported mod-only way to enable input remain unverified.
- [ ] If inputs work, prototype movement, aiming, weapons, and menus in the
  Quest loadout while keeping head tracking, the exact CVRFlatscreen gate, and
  local opt-in. Apply the stop rule before taking this further.
- [ ] Test respawn, exit, rejoin, and mixed PC/Quest play before claiming support.

Quest can pair Bluetooth peripherals, but that alone does not establish
gameplay input in Contractors. The Windows CVR Link runtime cannot run
unchanged on standalone Quest.
