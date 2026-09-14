-- Spend the real chest magazine's rounds while keeping the gun's magazine model attached.
local M={}
local function valid(o) return o and o:IsValid() end
local function same(a,b) return valid(a) and valid(b) and a:GetAddress()==b:GetAddress() end
local function rounds(clip)
    local value,capacity=clip:GetRemainingRounds(),clip:GetClipCapacity()
    assert(capacity>0 and capacity<=1000 and value>=0 and value<=capacity and value%1==0,'invalid magazine count')
    return value,capacity
end
local function chest(pawn)
    local result={}
    for _,holster in ipairs(FindAllOf('ZomboyInteractableHolster') or {}) do
        if valid(holster) and same(holster:GetOwner(),pawn)
            and holster:IsA('/Game/Core/Loadouts/BaseClasses/AmmoHolsterBase.AmmoHolsterBase_C') then
            local clip=holster:GetHolsterInteractable()
            if valid(clip) and clip:IsA('/Script/ZomboyVR.ZomboyGunClip')
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
    return current+chamber,reserve,magazines
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
            entry.clip:RefillAmmo()
            assert(rounds(entry.clip)==capacity,'chest magazine did not refill')
            count=count+1
        end
    end
    return count,count>0 and 'chest-refilled' or 'chest-full'
end
return M
