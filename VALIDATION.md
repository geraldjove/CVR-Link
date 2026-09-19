# CVR Link 0.2.62 validation

Release checks for 19 September 2026. Code and native editor results are
separate from live play evidence.

The public runtime is generated from the existing gated source plus the
reviewed Standard/WW2/Ninja gameplay changes. It permits only the three
exact CVRFlatscreen plan paths and the existing Experimental HQ exception.
Player choice, helper expiry, respawn/travel cleanup and VR default remain.

The release checks cover all fifteen Lua suites, each loadout's exact gate
and pause page, mode choice, helper expiry, replacement holders and local
HUD loading without another loadout package. Desktop settings, exported INIs,
installer, native EXE, PowerShell syntax, pinned loader hashes, exact payload
paths and private-data scans are checked separately.

Generated loadouts are reopened in the Unreal editor. Checks exercise their
compiled Windows/Quest menus, hidden pointer collision, parent ticks, HUD,
stock gear, source holder classes and saved thumbnail references. Windows,
server and Android cooks are separate. Each ZIP must contain exactly one
PAK with forward-slash entry paths and a matching decompressed SHA-256.

Gerald accepted the source preview's iron-sight feel, bow aim, Ninja
equipment/smoke, melee reach/rotation, resting position and Shift attacks.
That does not establish every public app/package case. Further checks
should test each loadout in the shipping game, including joins,
respawns, saves, crouch and leaving unsupported rooms. Remote clients,
Quest, dedicated servers and mixed play keep their own test limits.

Final WW2/Ninja packages use their own mod.io IDs and namespace. Standard
keeps page 6383627 and its original asset paths under its new display name.
The public app permits only those three exact plans, plus the existing
Experimental local HQ exception. Renaming a room cannot enable it.
