# Default controls

Change keys in CVR Link, then click Save settings. These controls apply only in Flatscreen mode.

| Key or mouse action | What it does |
| --- | --- |
| **F7** | Turn CVR Link off or on. This cannot unlock other loadouts. |
| **F8** | Open or close the CVR Link pause tab. |
| **F9** | Switch between mouse look and the menu pointer. Use it to look toward an off-screen menu, then press again to click. |
| **Escape while choosing a key in CVR Link** | Cancel that key change. |
| **Move mouse** | Look around. Flat pause, join/loadout and respawn pages use a normal cursor. |
| **W / A / S / D** | Move forward / left / backward / right. |
| **Tab** | Open or close the flat pause menu. It cannot close a required join/loadout or respawn screen or open pause over it. |
| **Escape in a flat pause page** | Close the pause menu. |
| **Left click on a menu** | Select the button under the cursor or stock pointer. |
| **Mouse wheel over a menu** | Scroll the menu. |
| **E** | Within two metres, use an ammo station or pick up an aimed item with an empty hand. Over a menu button, select it. |
| **G** | Drop the item in your hand. |
| **1** | Equip your main gun. Press again to cycle if you have two main guns. CVR Link also selects Ninja's bow slot. |
| **2** | Equip your sidearm. |
| **3** | Equip the gadget in slot 1. |
| **4** | Equip the gadget in slot 2. |
| **5** | Equip the gadget in slot 3. |
| **V** | Equip your melee weapon, such as a knife. |
| **Left click with a gun** | Fire. Bolt-action guns cycle automatically after a short pause; release and click for the next shot. Hold for full-auto fire when that mode is selected. Shots are blocked while sprinting; click again once sprint stops. There is no firing delay after sprint. |
| **Hold left click with the stock bow** | Draw the string. Full draw takes 0.6 seconds. Release to fire; a shorter draw gives a weaker shot. |
| **Right mouse with the stock bow** | Hold to aim with hands hidden for a clear view. Release to lower it and show the hands again. |
| **Right mouse button, held** | Aim. Stops sprint, waits 0.3 seconds, then eases into aim over 0.2 seconds. Release to return to the normal view. |
| **F6** | No CVR Link scope/zoom action. Other software may still use this key. |
| **B** | Change the gun's fire mode, if it has more than one. |
| **R** | Reload: magazines take 1.5 seconds; shotguns add a shell every 0.5 seconds; revolvers wait 0.5 seconds per missing round. Needs matching chest ammo. Once a shotgun shell is ready, press and hold fire to stop reloading and shoot after a 0.25-second raise. |
| **Left Shift + forward, held** | Sprint and lower the gun. Shift alone does not move you. Release Shift or forward to stop. The gun rises over 0.5 seconds; aim starts after 0.3 seconds and firing is available at once. CVR Link lets melee attack during sprint. |
| **Left Ctrl or C, held** | Crouch. Starts must be half a second apart. Release starts standing up at once. A blocked tap is ignored; release both keys before trying again. |
| **Left Ctrl or C while sprinting** | Start a slide when you are on the ground and moving fast enough. |
| **Left click with a melee weapon** | Swing it; release and click again after recovery. CVR Link turns the blade forward through the wider slash. It keeps the lower-right rest and attacks while Shift is held or you are sprinting. |
| **Hold left click with a grenade** | Pull the pin. |
| **Release left click with a grenade** | Throw it after the pin is pulled. |
| **Hold/release left click with Ninja smoke** | Hold it, then throw on release. It has no pin step. |
| **Left click with an empty hand** | No item action. It cannot grab ammo from your vest. Use the normal equip keys or E to pick up gear. |
| **Middle mouse + left/right drag with a Claymore** | Rotate it from side to side. The camera stays still. |
| **Alt + middle mouse + up/down drag with a Claymore** | Tilt it up or down. Either Alt key works. |
| **Release middle mouse** | Keep the Claymore's angle and return to mouse look. |
| **Left click with a Claymore** | Place it when the game's preview shows a valid spot. |

You can press or release Alt during a Claymore drag to change which way it turns.
Its chosen angle lasts until you put it away, open the menu, or turn the mod off.
Aim at a wall or floor within about two metres to show the place preview.

CVR Link also calibrates standing height once after each new player
spawn is ready and the join screen closes. This targets crouch failing after
a join. Saved VR height stays unchanged. Repeated joins still need testing.
See [validation and test limits](VALIDATION.md).

F9 is listed as **Pointer / mouse look** in CVR Link. Loadout and respawn
screens get pointer control on their own. If a screen is outside your view,
press F9, look toward it, then press F9 again to click. This does not close
the screen or allow weapon actions. Screen changes reset this choice.
If an older custom key setup already uses F9, the new action takes the first
free key starting with F10. Check its key in CVR Link.

Walls block E pickups. E keeps a held item; G drops it.
At an ammo station, E refills chest magazines even while you hold a gun. Each
magazine uses one station charge. An empty station needs time to restock.

Empty gear slots do nothing. Switching between a main gun and sidearm waits at
least one second before picking up the next gun. This works both ways. The gun
then rises into view. Other gear swaps happen after the held item lowers.

You cannot fire while reloading or switching. Pressing R again during a reload
does not speed it up. A switch, drop, open menu, or turning the mod off cancels
the reload.

R uses the matching chest magazine with the most rounds. It empties that
magazine and replaces the rounds in the gun; any rounds left in the gun's old
magazine are lost. A round already in the chamber stays. Empty chest magazines
stay on the vest for the ammo station to refill. R does nothing when the gun
is full or no matching chest magazine has rounds. Cancelling before completion
keeps the magazine.

Shotguns use matching shell pouches. R adds one shell every 0.5 seconds until
the gun is full or the pouches run out. Cancelling keeps shells already loaded
and stops the next shell. The stock Magnum uses a whole speedloader. It fills
at the end of a delay of 0.5 seconds per missing round: five rounds take 2.5
seconds. Cancelling before then keeps the loader. Reloading a partly full
revolver spends the whole loader, as the stock item has no partial-round count.
The HUD now shows **SHELL POUCHES** or **SPEEDLOADERS** for these guns. Ammo
stations refill these items using their normal charges.

Automatic bolt cycling waits 0.8 seconds after a fired case is found,
then uses the game's bolt and chamber actions. It takes the next round from the
gun, without spending a chest magazine. It stops pending work for a menu,
reload, drop, switch, or flatscreen exit. R has no long-press action.

The HUD's ammo display means **loaded rounds / spare chest rounds**. Loaded
rounds include one in the chamber, so a full rifle may show 31. **CHEST MAGS**
counts matching magazines with rounds left. The icon and name follow the item
in your right hand, including gadgets. Items without an icon show their name.
The pose icon uses your actual stance and also labels a slide.
The crosshair stays at screen center. In hip fire, the gun keeps a stable aim relative to the camera. Near a wall, the gun pulls back to keep its muzzle in front
of the surface. Recoil moves the gun and shots away from the crosshair. The marker
does not predict spread or bullet drop. Scope ADS keeps its normal sight alignment.
