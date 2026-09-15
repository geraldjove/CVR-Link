# Future work

## Standalone Quest mouse and keyboard

Deferred on 15 September 2026. This is outside the 0.2.0 release; Quest support
in this release is a VR controller preview. No delivery date is set.

- [ ] Test a Bluetooth keyboard and mouse paired directly to a Quest. Check
  whether a local CVRFlatscreen loadout receives key presses/releases, mouse
  buttons, and continuous relative mouse movement in the shipped game.
- [ ] Check whether the game's Android input settings can be enabled through
  supported mod tools. If app-level changes are needed, seek developer support.
- [ ] If inputs work, prototype movement, aiming, weapons, and menus in the
  Quest loadout while keeping the exact CVRFlatscreen gate and local opt-in.
- [ ] Test respawn, exit, rejoin, and mixed PC/Quest play before claiming support.

Quest can pair Bluetooth peripherals, but that alone does not establish
gameplay input in Contractors. The Windows CVR Link runtime cannot run
unchanged on standalone Quest.
