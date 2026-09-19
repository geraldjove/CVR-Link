# CVR Link 0.2.73 validation

Release checks for 19 September 2026. Code and native editor results are
separate from live play evidence.

The public runtime is generated from the existing gated source plus the
reviewed Standard/WW2/Ninja gameplay changes. It permits only the three
exact CVRFlatscreen plan paths and the existing Experimental HQ exception.
Player choice, helper expiry, respawn/travel cleanup and VR default remain.

The .73 save change supplies the inspected native mod tag only when
GetLoadoutTag returns None for an exact CVR plan. Loading and saving use the
same normal mod slots. Native tags, budget checks and allowed gear stay.
Gerald confirms Standard and WW2 changes survive respawn with Dev .72;
the recorded sessions are local bot matches on Lumber. The original .71
remote-client failure was traced, but .72 remote-client/rejoin/restart and
Ninja persistence still need separate live coverage.

The update checker uses the official public GitHub release API without
credentials. Startup/manual checks run asynchronously. Installation requires
Contractors closed, a newer stable version, the expected official asset,
matching size/SHA-256 and matching EXE version. The helper saves settings
and releases its mutex before opening the verified installer. The launcher
checks the game and hash again. Offline retry, duplicate requests and a game
starting during download have isolated checks. Public installation is enabled;
the private preview's public-install block is not active in this app.

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

Dev .68 play confirmations cover Ninja and WW2 server weapon menus and
equipped spawns, the revised resting arms, and an unnamed sight sample.
Dev .66 confirmed the clear Ninja sword view and showed Mosin scope/blur.
The asset audit covered eight stock snipers and 36 gun/sight pairs; it does
not establish every optic's live alignment or impact accuracy. New server
and Android package cooks retain separate device and network limits.

The prior .69 candidate passed 15 public Lua suites (1,775 checks), 90
Ninja/height/rest checks, 24 optics/quiver checks and 10 owned-holster checks.
Desktop form/settings, installer, native EXE and exact 24-entry payload
checks passed. Public source has 48 allowed files. The public scope material
and widget reopened and passed 18 native checks, including both saved
offset parameters. The public scope PAK contains five owned entries.

No assets changed for .73. It uses the same scope bytes and all nine existing
loadout packages. The .73 candidate passed all fifteen public Lua suites
(1,789 checks), including 98 flat-menu/save checks. The 90 Ninja/height/rest,
24 optics/quiver and 10 owned-holster checks pass. All 39 updater checks
exercise functions extracted from the generated app, including async retry,
verified download, game-start race and installer handoff.

The actual four-tab GUI completed startup and manual checks against GitHub.
GUI/INI, installer 49, scope package 8, display 14, native EXE, PowerShell
syntax and the exact 24-entry payload/source/privacy checks pass. The public
export still contains 48 approved files. A clean-PC/UAC/signing test remains
separate from these isolated installer and GUI checks. No live game install
was performed as part of publication.
