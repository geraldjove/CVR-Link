-- Use the matching chest magazine, shell pouch, or stock Magnum speedloader.
local M={}
local function valid(o) return o and o:IsValid() end
local function same(a,b) return valid(a) and valid(b) and a:GetAddress()==b:GetAddress() end
local pouch_class='/Script/ZomboyVR.ZomboyBulletPouchActor'
local loader_class='/Game/Core/VRInteractables/ZomboyGunSystem/Guns/Modern/Magnum/Magnum_Loader.Magnum_Loader_C'
local function source_type(item)
    if item:IsA(pouch_class) then return 'shell' end
    if item:IsA(loader_class) then return 'loader' end
    if item:IsA('/Script/ZomboyVR.ZomboyGunClip') then return 'magazine' end
end
local function rounds(clip)
    local kind=source_type(clip)
    local value,capacity
    if kind=='shell' then value,capacity=clip.BulletRemain,clip:GetClass():GetCDO().BulletRemain
    elseif kind=='loader' then value,capacity=clip.bBulletInstalled and 0 or 7,7
    else value,capacity=clip:GetRemainingRounds(),clip:GetClipCapacity() end
    assert(capacity>0 and capacity<=1000 and value>=0 and value<=capacity and value%1==0,'invalid magazine count')
    return value,capacity
end
local function chest(pawn)
    local result={}
    for _,holster in ipairs(FindAllOf('ZomboyInteractableHolster') or {}) do
        if valid(holster) and same(holster:GetOwner(),pawn)
            and holster:IsA('/Game/Core/Loadouts/BaseClasses/AmmoHolsterBase.AmmoHolsterBase_C') then
            local clip=holster:GetHolsterInteractable()
            if valid(clip) and source_type(clip)
                and same(clip:GetOwner(),pawn) and same(clip:GetActorAttachingTo(),holster) then
                result[#result+1]={holster=holster,clip=clip}
            end
        end
    end
    return result
end
function M.plan(pawn,gun)
    local clip=gun:GetCurrentClip()
    if not valid(clip) then return nil,'no-gun-magazine' end
    local current,capacity=rounds(clip)
    if current==capacity and gun:HasBulletInChamber() then return nil,'gun-full' end
    local kind=gun:GetDefaultClipClass()
    local selected,most=nil,0
    for _,entry in ipairs(chest(pawn)) do
        if same(entry.clip:GetClass(),kind) then
            local available=rounds(entry.clip)
            if available>most then selected,most=entry,available end
        end
    end
    if not selected then return nil,'no-chest-magazine' end
    selected.pawn,selected.gun,selected.gun_clip=pawn,gun,clip
    selected.kind=source_type(selected.clip)
    if selected.kind=='loader' and current+(gun:HasBulletInChamber() and 1 or 0)>=capacity then return nil,'gun-full' end
    selected.delay=selected.kind=='shell' and .5 or selected.kind=='loader'
        and math.max(1,capacity-current-(gun:HasBulletInChamber() and 1 or 0))*.5 or 1.5
    return selected,'reloading'
end
function M.counts(pawn,gun)
    local clip=gun:GetCurrentClip()
    local current=valid(clip) and rounds(clip) or 0
    local chamber=gun:HasBulletInChamber() and 1 or 0
    local reserve,magazines=0,0
    local kind=gun:GetDefaultClipClass()
    for _,entry in ipairs(chest(pawn)) do
        if same(entry.clip:GetClass(),kind) then
            local available=rounds(entry.clip)
            reserve=reserve+available
            if available>0 then magazines=magazines+1 end
        end
    end
    local label='CHEST MAGS'
    if valid(kind) then
        local template=kind:GetCDO()
        if valid(template) then
            local source=source_type(template)
            label=source=='shell' and 'SHELL POUCHES' or source=='loader' and 'SPEEDLOADERS' or label
        end
    end
    return current+chamber,reserve,magazines,label
end
local function drain(clip,target)
    local count=rounds(clip)
    for _=1,count-target do
        assert(clip:MoveBulletToChamber(),'magazine did not release a round')
    end
    assert(rounds(clip)==target,'magazine count did not update')
end
function M.complete(plan)
    local source,gun,clip=plan.clip,plan.gun,plan.gun_clip
    if not valid(gun) or not same(gun:GetCurrentClip(),clip) or not valid(source)
        or not valid(plan.holster) or not same(plan.holster:GetOwner(),plan.pawn)
        or not same(source:GetOwner(),plan.pawn) or not same(source:GetActorAttachingTo(),plan.holster)
        or not same(plan.holster:GetHolsterInteractable(),source)
        or not same(source:GetClass(),gun:GetDefaultClipClass()) then return false,'magazine-changed' end
    local available=rounds(source)
    if available==0 then return false,'no-chest-magazine' end
    if plan.kind=='shell' then
        local current,capacity=rounds(clip)
        if current==capacity and gun:HasBulletInChamber() then return false,'gun-full' end
        -- Use the same one-round operations as the stock shell interaction.
        if not gun:HasBulletInChamber() then
            if gun:HaseUsedBulletInChamber() then gun:EjectChamberBullet() end
            if not gun:AddBulletToChamber() then return false,'chamber-not-ready' end
            -- Loading a shell does not release a last-round hold-open bolt.
            -- ReleaseBolt tries to chamber AGAIN; close the already loaded bolt instead.
            if valid(gun.GunBoltComponent) and gun.GunBoltComponent:GetBoltState()==4 then
                gun.GunBoltComponent:BoltTravelToClose(0)
            end
        elseif not gun:AddBulletToClip() then return false,'gun-full' end
        source.BulletRemain=available-1
        assert(source.BulletRemain==available-1,'pouch count did not update')
        return true,'loaded-shell',not (rounds(clip)==capacity and gun:HasBulletInChamber())
    end
    if plan.kind=='loader' then
        local current,capacity=rounds(clip)
        local missing=capacity-current-(gun:HasBulletInChamber() and 1 or 0)
        if missing<=0 then return false,'gun-full' end
        -- A stock speedloader has one full/empty flag, not individual reserves.
        -- Spend it only after the whole per-round delay; preserve loaded rounds.
        source.bBulletInstalled=true
        source:OnRep_bBulletInstalled()
        for _=1,math.min(available,missing) do assert(gun:AddBulletToClip(),'revolver did not accept a round') end
        return true,'used-speedloader'
    end
    local chamber=gun:HasBulletInChamber() and 1 or 0
    drain(source,0)
    -- The existing helper also closes the bolt. Limit its refill to the rounds actually spent.
    gun:ReloadWeapon()
    assert(same(gun:GetCurrentClip(),clip),'reload replaced the gun magazine')
    local filled=rounds(clip)
    local allowed=math.max(0,available+chamber-(gun:HasBulletInChamber() and 1 or 0))
    drain(clip,math.min(filled,allowed))
    print('[FlatscreenAmmo] used='..source:GetFName():ToString()..' rounds='..available
        ..' source_left='..rounds(source)..' gun_rounds='..rounds(clip)..'\n')
    return true,'used-chest-magazine'
end
function M.is_station(item)
    return valid(item) and item:IsA('/Game/Core/VRInteractables/EquipmentSupply/AmmoSupply.AmmoSupply_C')
end
function M.refill(pawn,station)
    if not M.is_station(station) then return 0,'not-ammo-station' end
    local count=0
    for _,entry in ipairs(chest(pawn)) do
        local current,capacity=rounds(entry.clip)
        if current<capacity then
            local stock=station.CurrentSupplyAmount
            if stock<=0 then return count,count>0 and 'chest-refilled' or 'station-empty' end
            -- This stock event spends one supply charge and starts its normal restock timer.
            station:OnGrabEvent(entry.clip:GetClass())
            assert(station.CurrentSupplyAmount==stock-1,'station did not spend a supply charge')
            local kind=source_type(entry.clip)
            if kind=='shell' then entry.clip.BulletRemain=capacity
            elseif kind=='loader' then entry.clip.bBulletInstalled=false; entry.clip:OnRep_bBulletInstalled()
            else entry.clip:RefillAmmo() end
            assert(rounds(entry.clip)==capacity,'chest magazine did not refill')
            count=count+1
        end
    end
    return count,count>0 and 'chest-refilled' or 'chest-full'
end
return M
