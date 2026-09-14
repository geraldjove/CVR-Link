local count,id=0,0
local function check(value,name) assert(value,name); count=count+1 end
local function object(t)
    id=id+1; local address=id
    t.IsValid=function(self) return not self.invalid end
    t.GetAddress=function() return address end
    t.GetFName=function() return {ToString=function() return 'Magazine' end} end
    return t
end
local pawn,other,rifle_kind,pistol_kind=object({}),object({}),object({}),object({})
local function magazine(owner,kind,left,size)
    return object({left=left,size=size or 30,GetOwner=function() return owner end,GetClass=function() return kind end,
        IsA=function(_,path) return path=='/Script/ZomboyVR.ZomboyGunClip' end,
        GetActorAttachingTo=function(self) return self.attached end,
        GetRemainingRounds=function(self) return self.left end,GetClipCapacity=function(self) return self.size end,
        MoveBulletToChamber=function(self) if self.left<=0 then return false end; self.left=self.left-1; return true end,
        RefillAmmo=function(self) self.left=self.size end})
end
local holsters={}
local function chest(owner,kind,left,size)
    local clip=magazine(owner,kind,left,size)
    local holster=object({GetOwner=function() return owner end,IsA=function() return true end,
        GetHolsterInteractable=function() return clip end})
    clip.attached=holster; holsters[#holsters+1]=holster
    return clip,holster
end
local first,first_holster=chest(pawn,rifle_kind,30)
local second=chest(pawn,rifle_kind,7)
local pistol=chest(pawn,pistol_kind,12,12)
local foreign=chest(other,rifle_kind,30)
local loaded=magazine(nil,rifle_kind,0)
local gun=object({chamber=false,GetCurrentClip=function() return loaded end,
    GetDefaultClipClass=function() return rifle_kind end,HasBulletInChamber=function(self) return self.chamber end,
    ReloadWeapon=function(self) loaded.left=loaded.size; self.chamber=true end})
FindAllOf=function(name) assert(name=='ZomboyInteractableHolster'); return holsters end
local ammo=dofile('Ammo.lua')
local ready,reserve,mags=ammo.counts(pawn,gun)
check(ready==0 and reserve==37 and mags==2,'HUD totals include only matching local chest rounds and nonempty magazines')
local plan=ammo.plan(pawn,gun)
check(plan and plan.clip==first,'reload selects a matching chest magazine with the most rounds')
check(first.left==30 and loaded.left==0,'starting or cancelling a reload spends no ammo')
local ok=ammo.complete(plan)
check(ok and first.left==0 and loaded.left==29 and gun.chamber,'empty gun reload spends thirty rounds including the chamber')
ready,reserve,mags=ammo.counts(pawn,gun)
check(ready==30 and reserve==7 and mags==1,'HUD counts the chamber once and drops spent magazines from reserves')
check(loaded==plan.gun_clip and first.attached==first_holster,'gun and chest magazine attachments stay intact')
loaded.left=2
plan=ammo.plan(pawn,gun); check(plan.clip==second,'next reload selects the remaining partial magazine')
ammo.complete(plan)
check(second.left==0 and loaded.left==7 and gun.chamber,'partial magazine supplies seven rounds and retains the old chamber round')
ready,reserve,mags=ammo.counts(pawn,gun)
check(ready==8 and reserve==0 and mags==0,'HUD reports no spare ammo after the last matching chest magazine')
local missing,message=ammo.plan(pawn,gun)
check(not missing and message=='no-chest-magazine','used chest magazines stop further reloads')
check(pistol.left==12 and foreign.left==30,'reload does not use wrong-calibre or another player magazines')
first.left=30; loaded.left=30
missing,message=ammo.plan(pawn,gun)
check(not missing and message=='gun-full' and first.left==30,'full gun does not waste a chest magazine')
loaded.left=0; plan=ammo.plan(pawn,gun); first.attached=nil
ok,message=ammo.complete(plan)
check(not ok and first.left==30 and loaded.left==0,'removed chest magazine cancels completion without spending ammo')
first.attached=first_holster; plan=ammo.plan(pawn,gun); first.left=0
ok=ammo.complete(plan); check(not ok and loaded.left==0,'magazine emptied during the delay cannot reload')
first.left=30; plan=ammo.plan(pawn,gun); loaded=magazine(nil,rifle_kind,0)
ok=ammo.complete(plan); check(not ok and first.left==30,'changed gun magazine cancels completion')
first.left=0; second.left=0; pistol.left=4
local calls=0
local station=object({CurrentSupplyAmount=2,IsA=function(_,path) return path:find('/AmmoSupply.',1,true)~=nil end,
    OnGrabEvent=function(self,kind)
        assert(kind==rifle_kind or kind==pistol_kind); calls=calls+1
        self.CurrentSupplyAmount=self.CurrentSupplyAmount-1; self.timer=true
    end})
local amount,status=ammo.refill(pawn,station)
check(amount==2 and status=='chest-refilled' and calls==2 and station.CurrentSupplyAmount==0 and station.timer,
    'station refill spends one stock charge per magazine and uses the normal cooldown event')
check(first.left==30 and second.left==30 and pistol.left==4,'limited station stock cannot refill extra magazines')
amount,status=ammo.refill(pawn,station)
check(amount==0 and status=='station-empty' and pistol.left==4,'empty station cannot grant ammo')
station.CurrentSupplyAmount=1; amount=ammo.refill(pawn,station)
check(amount==1 and pistol.left==12,'restocked station refills a partial sidearm magazine')
station.CurrentSupplyAmount=5; amount,status=ammo.refill(pawn,station)
check(amount==0 and status=='chest-full' and station.CurrentSupplyAmount==5,'full chest does not spend station stock')
foreign.left=0; ammo.refill(pawn,station)
check(foreign.left==0,'station refill cannot alter another player magazines')
amount,status=ammo.refill(pawn,object({IsA=function() return false end}))
check(amount==0 and status=='not-ammo-station','other actors cannot refill ammo')
first.left=0; first.attached=nil; ammo.refill(pawn,station)
check(first.left==0,'station does not refill a magazine dropped from the chest')
print(count..' chest magazine and ammo station checks passed')
