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
rifle_kind.GetCDO=function() return object({IsA=function() return false end}) end
pistol_kind.GetCDO=rifle_kind.GetCDO
local function magazine(owner,kind,left,size)
    return object({left=left,size=size or 30,GetOwner=function() return owner end,GetClass=function() return kind end,
        IsA=function(_,path) return path=='/Script/ZomboyVR.ZomboyGunClip' end,
        GetActorAttachingTo=function(self) return self.attached end,
        GetRemainingRounds=function(self) return self.left end,GetClipCapacity=function(self) return self.size end,
        MoveBulletToChamber=function(self) if self.left<=0 then return false end; self.left=self.left-1; return true end,
        RefillAmmo=function(self) self.left=self.size end})
end
local holsters={}
pawn.PlayerVest=object({HolsterManager=object({Holsters={ForEach=function(_,callback)
    for i,holster in ipairs(holsters) do callback(i,{get=function() return holster end}) end
end}})})
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
-- Loose rounds use their stock pouch or whole-speedloader state.
holsters={}
local shell_kind,loader_kind=object({}),object({})
local function reserve_item(kind,value)
    local item,holster=chest(pawn,kind,0,7)
    item.IsA=function(_,path) return kind==shell_kind and path=='/Script/ZomboyVR.ZomboyBulletPouchActor'
        or kind==loader_kind and path:find('/Magnum_Loader.',1,true)~=nil end
    item.BulletRemain=value; item.bBulletInstalled=value==0
    item.OnRep_bBulletInstalled=function(self) self.visual_used=self.bBulletInstalled end
    return item,holster
end
local pouch,pouch_holster=reserve_item(shell_kind,2)
local spare=reserve_item(shell_kind,3)
shell_kind.GetCDO=function() return object({BulletRemain=7,IsA=pouch.IsA}) end
loader_kind.GetCDO=function() return object({IsA=function(_,path) return path:find('/Magnum_Loader.',1,true)~=nil end}) end
loaded=magazine(nil,shell_kind,0,5)
gun.GetDefaultClipClass=function() return shell_kind end
gun.chamber=false; gun.spent=true
local bolt_closes=0
gun.GunBoltComponent=object({bolt=4,GetBoltState=function(self) return self.bolt end,
    BoltTravelToClose=function(self,dt) assert(dt==0);bolt_closes=bolt_closes+1;self.bolt=3 end})
gun.HaseUsedBulletInChamber=function(self) return self.spent end
gun.EjectChamberBullet=function(self) self.spent=false end
gun.AddBulletToChamber=function(self) if self.chamber or self.spent then return false end; self.chamber=true; return true end
gun.AddBulletToClip=function() if loaded.left>=loaded.size then return false end; loaded.left=loaded.left+1; return true end
ready,reserve,mags,status=ammo.counts(pawn,gun)
check(ready==0 and reserve==5 and mags==2 and status=='SHELL POUCHES','shotgun HUD counts actual pouch shells')
plan=ammo.plan(pawn,gun)
check(plan.kind=='shell' and plan.delay==.5 and spare.BulletRemain==3,'shell starts a half-second delay without spending')
local more
ok,message,more=ammo.complete(plan)
check(ok and more and gun.chamber and not gun.spent and spare.BulletRemain==2 and loaded.left==0,'first shell clears a spent case and chambers exactly one round')
check(bolt_closes==1 and gun.GunBoltComponent.bolt==3,'first live shell closes a held-open bolt without moving another round')
for i=1,4 do check(ammo.complete(ammo.plan(pawn,gun)),'remaining shell loads '..i) end
check(loaded.left==4 and gun.chamber and pouch.BulletRemain==0 and spare.BulletRemain==0,'reload changes pouches without creating ammo')
check(not ammo.plan(pawn,gun),'empty pouches stop the progressive reload')
check(bolt_closes==1,'later tube shells do not repeat bolt closure')
spare.BulletRemain=7
plan=ammo.plan(pawn,gun); ok,message,more=ammo.complete(plan)
check(ok and not more and loaded.left==5 and spare.BulletRemain==6,'last shell fills tube without overfilling or wasting a shell')
check(not ammo.plan(pawn,gun),'full tube and chamber do not start another reload')
loaded.left=0; plan=ammo.plan(pawn,gun); spare.attached=nil
check(not ammo.complete(plan) and spare.BulletRemain==6,'detaching a pouch during the delay spends no shell')
spare.attached=plan.holster
holsters={}
local loader=reserve_item(loader_kind,7)
gun.GetDefaultClipClass=function() return loader_kind end
loaded=magazine(nil,loader_kind,2,7); gun.chamber=false
plan=ammo.plan(pawn,gun)
check(plan.kind=='loader' and plan.delay==2.5 and not loader.bBulletInstalled,'five missing revolver rounds delay 2.5 seconds without spending the loader')
ok=ammo.complete(plan)
check(ok and loaded.left==7 and loader.bBulletInstalled and loader.visual_used,'revolver consumes one full loader only at completion')
check(not ammo.plan(pawn,gun),'full revolver cannot spend another loader')
loaded.left=0
check(not ammo.plan(pawn,gun),'spent loader cannot reload an empty revolver')
station.CurrentSupplyAmount=1
station.OnGrabEvent=function(self,kind) assert(kind==loader_kind); self.CurrentSupplyAmount=self.CurrentSupplyAmount-1 end
check(ammo.refill(pawn,station)==1 and not loader.bBulletInstalled and not loader.visual_used and station.CurrentSupplyAmount==0,
    'stock station charge restores a spent speedloader and its visual state')
plan=ammo.plan(pawn,gun)
check(plan.delay==3.5,'empty seven-round cylinder waits 3.5 seconds')
ammo.complete(plan)
ready,reserve,mags,status=ammo.counts(pawn,gun)
check(ready==7 and reserve==0 and mags==0 and status=='SPEEDLOADERS','revolver HUD counts spent loaders as empty')
do
    holsters={}
    local kind=object({})
    kind.GetCDO=function() return magazine(nil,kind,8,8) end
    local reserve,holster=chest(pawn,kind,8,8)
    local current,spawned,fail_spawn,fail_insert,detach_insert
    local mount=object({})
    local garand=object({chamber=false,GetCurrentClip=function() return current end,
        GetDefaultClipClass=function() return kind end,GetOwner=function() return pawn end,
        IsA=function(_,path) return path:find('/M1Garand/WW2_M1Garand.',1,true)~=nil end,
        HasBulletInChamber=function(self) return self.chamber end,GunClipTransform=mount,
        EjectChamberBullet=function(self) self.chamber=false end,EjectClip=function() current=nil end,
        K2_GetActorLocation=function() return {} end,K2_GetActorRotation=function() return {} end})
    FName=function(value) return value end
    garand.GetWorld=function() return {SpawnActor=function(_,cls)
        assert(cls==kind)
        if fail_spawn then return nil end
        spawned=magazine(pawn,kind,8,8)
        spawned.SetOwner=function(_,owner) assert(owner==pawn) end
        spawned.AuthoritySetAttachment=function(self,parent,socket,t)
            assert(parent==mount and socket=='None' and t.Scale3D.X==1)
            if fail_insert then return end
            current=self;self.attached=garand
            self:MoveBulletToChamber();garand.chamber=true
            if detach_insert then self.attached=nil end
        end
        spawned.K2_DestroyActor=function(self) self.invalid=true end
        return spawned
    end} end
    local plan=ammo.plan(pawn,garand)
    check(plan.enbloc and plan.delay==1.5 and reserve.left==8 and not spawned,'empty Garand starts the normal delay without spawning or spending')
    check(ammo.complete(plan) and current.left==7 and garand.chamber and reserve.left==0,'replacement clip chambers one of eight real rounds')
    check(reserve.attached==holster and current.attached==garand,'empty chest clip remains attached while replacement uses the gun mount')
    check(not ammo.complete(plan),'completed insertion cannot be repeated')
    current=nil;garand.chamber=false;reserve.left=3
    plan=ammo.plan(pawn,garand);reserve.attached=nil
    check(not ammo.complete(plan) and reserve.left==3 and not current,'detaching the reserve during delay cancels en-bloc insertion')
    reserve.attached=holster
    plan=ammo.plan(pawn,garand);fail_spawn=true
    check(not ammo.complete(plan) and reserve.left==3,'spawn failure spends no ammo')
    fail_spawn=false;fail_insert=true
    check(not ammo.complete(plan) and reserve.left==3 and spawned.invalid,'rejected attachment destroys replacement and keeps reserve')
    fail_insert=false
    detach_insert=true
    check(not ammo.complete(plan) and reserve.left==3 and not current and not garand.chamber and spawned.invalid,
        'partly accepted attachment rolls back its new chamber round before discarding the replacement')
    detach_insert=false
    check(ammo.complete(plan) and current.left==2 and garand.chamber and reserve.left==0,'partial reserve cannot create a full clip')
    current=nil;garand.chamber=false;reserve.left=1
    check(ammo.complete(ammo.plan(pawn,garand)) and current.left==0 and garand.chamber and reserve.left==0,'last reserve round goes into the chamber once')
    current=nil;garand.chamber=false
    check(not ammo.plan(pawn,garand),'empty chest clips cannot create replacement ammo')
    reserve.left=8;garand.IsA=function() return false end
    local missing,reason=ammo.plan(pawn,garand)
    check(not missing and reason=='no-gun-magazine','missing magazines on other guns retain the existing rejection')
end
do
    holsters={}
    local kind=object({})
    kind.GetCDO=function() return magazine(nil,kind,71,71) end
    local reserve,holster=chest(pawn,kind,71,71)
    local drum=magazine(nil,kind,24,71)
    local calls=0
    local function f32(value) return (string.unpack('f',string.pack('f',value))) end
    local function remove(self)
        calls=calls+1
        if self.left<=0 then return false end
        -- Native GetRemainingRounds floors capacity * the stored float fraction.
        self.left=math.floor(f32(f32((self.left-1)/self.size)*self.size))
        return true
    end
    reserve.MoveBulletToChamber=remove;drum.MoveBulletToChamber=remove
    local ppsh=object({chamber=true,GetCurrentClip=function() return drum end,
        GetDefaultClipClass=function() return kind end,HasBulletInChamber=function(self) return self.chamber end,
        ReloadWeapon=function(self) drum.left=71;self.chamber=true end})
    local plan=ammo.plan(pawn,ppsh)
    check(plan.delay==1.5 and reserve.left==71,'drum keeps normal magazine delay and reserves until completion')
    check(ammo.complete(plan) and calls==66 and reserve.left==0 and drum.left==71,
        '71-round source drains in 66 native-style calls without requesting a round from an empty drum')
    check(reserve.attached==holster and ammo.counts(pawn,ppsh)==72,'drum reload retains the old chamber once and leaves the empty chest drum attached')
    reserve.left=71;drum.left=0;ppsh.chamber=false;calls=0
    check(ammo.complete(ammo.plan(pawn,ppsh)) and drum.left==70 and ppsh.chamber and reserve.left==0,
        'empty drum reload spends exactly 71 rounds including its new chamber round')
    reserve.left=14;drum.left=0;ppsh.chamber=false;calls=0
    check(ammo.complete(ammo.plan(pawn,ppsh)) and reserve.left==0 and drum.left==12 and ppsh.chamber,
        'partial drum trim accepts native one-round rounding loss without exceeding the spent budget or throwing')
    check(not ammo.plan(pawn,ppsh),'empty drum reserves do not produce another reload')
    reserve.left=71;drum.left=20
    local old_remove=reserve.MoveBulletToChamber
    reserve.MoveBulletToChamber=function() return true end
    check(not pcall(ammo.complete,ammo.plan(pawn,ppsh)) and drum.left==20,'a non-progressing native count fails immediately instead of looping forever')
    reserve.MoveBulletToChamber=old_remove
end

print(count..' ammo and station checks passed')
