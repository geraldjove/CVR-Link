# CVR Link 0.2.69 — Loadout and sight fixes

19 September 2026

Update **CVR Link to 0.2.69** and your chosen loadout in Contractors:

- CVRFlatscreen Standard **0.2.7**
- CVRFlatscreen WW2 **0.1.1**
- CVRFlatscreen Ninja **0.1.1**

## Fixes

- Fixed empty WW2 and Ninja loadout menus after joining a server. Both now
  show weapons and allow equipped spawns in the tested private build. All
  three loadout packages include the same loading fix.
- Added the large magnified scope view and blurred surroundings to the
  inspected Standard and WW2 sniper scope types. This includes the scoped
  options on AWM, M1A, SKS, SVD, Sako85, Kar98, Mosin Nagant and Lee-Enfield.
  The AWM keeps its existing scope setup. Other unsupported optics keep
  their normal lens view.
- Corrected Kobra, Aimpoint T1, Aimpoint Micro T1 and Reflex aiming alignment
  using the sight's lens position on the weapon.
- Fixed arrows and the quiver crossing the view while using the Ninja sword.
- Empty hands now rest at the body's sides. The free left hand also rests
  down while holding a melee weapon in the right hand.

Normal gun recoil stays in place. Pistols keep the earlier reduced camera
shake while aiming. Bow controls and the accepted melee reach, rotation and
sprint attacks remain the same. No keybind changes in this update.

## Update steps

1. Update your chosen CVRFlatscreen loadout in Contractors' mod browser.
   Server hosts should update the matching server content too.
2. Close Contractors and CVR Link. Download **CVRLink.exe 0.2.69**, open it,
   and click **Install CVR Link**.
3. Keep CVR Link open and start Contractors. Host or join a room using
   CVRFlatscreen Standard, WW2 or Ninja.

Flatscreen match controls remain locked to these three exact loadouts and
need your choice to use Flatscreen plus a running CVR Link app. The existing
Experimental local HQ option remains available. VR players keep their
normal controllers. Quest mouse and keyboard play is not included.

## Testing and known limits

In Dev .68, Gerald confirmed that Ninja and WW2 server menus and equipped
spawns work, the resting arms look natural, and the sights he tried show no
problem. He also confirmed the Ninja sword view was clear in Dev .66.
The asset audit covered all eight stock snipers and 36 gun/sight pairs;
this is not a live test of every gun or scope. Further impact, Quest, mixed
client, respawn and travel checks remain. The brief freeze at the start of
some explosions is still being investigated.

[Download CVR Link](https://github.com/geraldjove/CVR-Link/releases/tag/v0.2.69)
 · [Standard](https://mod.io/g/contractors/m/cvrflatscreen)
 · [WW2](https://mod.io/g/contractors/m/cvrflatscreen-ww2)
 · [Ninja](https://mod.io/g/contractors/m/cvrflatscreen-ninja)

Author: **_mintyfishy** · [Discord](https://discord.gg/432n3NTq9f)
