# Future work

## Quest welcome and flatscreen player list

- [ ] Test the 0.2.2 welcome, Continue in VR, and bottom-center menu
  button on Quest. Check all links and Respawn/Change Loadout.
- [ ] Check that respawn and armor changes do not repeat the welcome, and a
  new match shows it again.
- [ ] Test the shared flatscreen list in a mixed Windows/Quest match with the
  new app and loadouts. Check VR/off, a lost link, timeout, death, leave/rejoin,
  late join, and a dedicated server. Older apps do not report their mode.

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
