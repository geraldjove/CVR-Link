-- Stock local holsters and grip interactions; no item spawning or loadout edits.
local M={}
local ammo=require('Ammo')
local groups={One={'Primary','Alt-Primary'},Two={'Sidearm'},Three={'Gadget1'},Four={'Gadget2'},Five={'Gadget3'},V={'Melee'}}
local function valid(o) return o and o:IsValid() end
local function same(a,b) return valid(a) and valid(b) and a:GetAddress()==b:GetAddress() end
function M.held(controller)
    local grip=controller:GetCurrentInteraction().InteractionComponent:Get()
    return valid(grip) and grip:GetOwner() or nil,grip
end
local function usable(item,pawn)
    return valid(item) and same(item:GetOwner(),pawn)
        and not item:GetFName():ToString():match('^NoneInteractableActor')
end
function M.new(pawn) return {pawn=pawn,slots={},message='ready'} end
local function refresh(inventory,held)
    local slots={}
    for _,holster in ipairs(FindAllOf('ZomboyInteractableHolster') or {}) do
        if same(holster:GetOwner(),inventory.pawn) then
            local tag=holster.HolsterTag:ToString()
            local wanted=false
            for _,tags in pairs(groups) do for _,name in ipairs(tags) do if name==tag then wanted=true end end end
            if wanted then
                local item=holster:GetHolsterInteractable()
                local old=inventory.slots[tag]
                if usable(item,inventory.pawn) and same(item:GetActorAttachingTo(),holster) then
                    local root=item.RootComponent
                    slots[tag]={holster=holster,item=item,socket=root.AttachSocketName,
                        attachment=root:GetRelativeTransform()}
                elseif old and same(old.holster,holster) and same(old.item,held) then slots[tag]=old end
            end
        end
    end
    inventory.slots=slots
end
local function grip_for(item)
    for _,grip in ipairs(FindAllOf('ZomboyInteractionComponent') or {}) do
        if same(grip:GetOwner(),item) and grip.DefaultGripType==1 and not grip.bAssistGrip
            and grip.DefaultInteractionButton==0 then return grip end
    end
end
function M.interact(inventory,right,camera)
    if inventory.pending then return end
    local held=M.held(right)
    local origin,forward=camera:K2_GetComponentLocation(),camera:GetForwardVector()
    local start={X=origin.X,Y=origin.Y,Z=origin.Z}
    local candidates={}
    for _,grip in ipairs(FindAllOf('ZomboyInteractionComponent') or {}) do
        if valid(grip) and not grip.bAssistGrip and not grip:IsInteracting() then
            local item=grip:GetInteractable()
            local station=ammo.is_station(item)
            if valid(item) and not item:GetFName():ToString():match('^Default__')
                and (station or (not valid(held) and grip.DefaultInteractionButton==0))
                and not valid(item:GetActorAttachingTo()) then
                local point=grip:K2_GetComponentLocation()
                local x,y,z=point.X-start.X,point.Y-start.Y,point.Z-start.Z
                local distance=x*x+y*y+z*z
                local along=x*forward.X+y*forward.Y+z*forward.Z
                local side=math.max(0,distance-along*along)
                if along>0 and distance<=200*200 and side<=20*20 and (station or grip:CanBeginInteraction(right)) then
                    candidates[#candidates+1]={grip=grip,item=item,point={X=point.X,Y=point.Y,Z=point.Z},
                        station=station,score=side+distance*.0025}
                end
            end
        end
    end
    table.sort(candidates,function(a,b) return a.score<b.score end)
    inventory.interaction=valid(held) and 'hand-full' or 'no-target'
    local system=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
    local color={R=0,G=0,B=0,A=0}
    for _,candidate in ipairs(candidates) do
        local hit={}
        local ignore={inventory.pawn,candidate.item}
        if valid(held) then ignore[#ignore+1]=held end
        -- Only the local pawn and target are ignored; walls still block the reach.
        local blocked=system:LineTraceSingle(inventory.pawn,start,candidate.point,0,false,
            ignore,0,hit,true,color,color,0)
        if not blocked then
            if candidate.station then
                local count,message=ammo.refill(inventory.pawn,candidate.item)
                inventory.interaction=message..'-'..count
                return true
            end
            local accepted=right:TryBeginInteractWith(0,candidate.grip)
            inventory.interaction=(accepted and 'accepted-' or 'rejected-')..candidate.item:GetFName():ToString()
            return true
        end
        inventory.interaction='blocked'
    end
end
function M.select(inventory,key,pc,right,before_switch)
    if inventory.pending then return end
    local tags=groups[key]
    if not tags then return end
    local held,held_grip=M.held(right)
    refresh(inventory,held)
    local start=0
    for index,tag in ipairs(tags) do
        local slot=inventory.slots[tag]
        if slot and same(slot.item,held) then start=index end
    end
    local target
    for step=1,#tags do
        local slot=inventory.slots[tags[(start+step-1)%#tags+1]]
        if slot and usable(slot.item,inventory.pawn) then target=slot; break end
    end
    if not target then inventory.message='empty'; return end
    if same(target.item,held) then inventory.message='already-held'; return end
    local grip=grip_for(target.item)
    if not valid(grip) then inventory.message='no-grip'; return end
    local home
    if valid(held) then
        for _,slot in pairs(inventory.slots) do if same(slot.item,held) then home=slot; break end end
        if not home or not held:CanAttachTo(home.holster.RootComp) then
            inventory.message='cannot-holster'; return
        end
    end
    before_switch()
    local from=home and home.holster.HolsterTag:ToString()
    local to=target.holster.HolsterTag:ToString()
    local from_primary=from=='Primary' or from=='Alt-Primary'
    local to_primary=to=='Primary' or to=='Alt-Primary'
    local delay=((from_primary and to=='Sidearm') or (from=='Sidearm' and to_primary)) and 1 or (home and .25 or 0)
    local equip_after=os.clock()+delay
    inventory.pending={target=target,grip=grip,old=held,old_grip=held_grip,home=home,
        pc=pc,started=os.clock(),phase=home and 'lower' or 'equip',
        equip_after=equip_after,deadline=equip_after+1}
    print('[FlatscreenInventory] request '..target.holster.HolsterTag:ToString()..' target='..target.item:GetFName():ToString()..'\n')
    inventory.message='switching'
end
function M.tick(inventory,right)
    local pending=inventory.pending
    if not pending then return end
    local held=M.held(right)
    if same(held,pending.target.item) then
        if not pending.raise_started then pending.raise_started=os.clock(); pending.phase='raise' end
        if os.clock()-pending.raise_started>=.25 then
            inventory.message='equipped-'..pending.target.holster.HolsterTag:ToString()
            inventory.pending=nil
        end
        return
    end
    if pending.phase=='raise' then inventory.pending=nil; inventory.message='switch-cancelled'; return end
    if os.clock()>pending.deadline or not usable(pending.target.item,inventory.pawn) then
        inventory.message='switch-timeout'
        local function name(o) return valid(o) and o:GetFName():ToString() or 'none' end
        print('[FlatscreenInventory] timeout held='..name(held)..' old='..name(pending.old)
            ..' attached='..name(valid(pending.old) and pending.old:GetActorAttachingTo())
            ..' target='..name(pending.target.item)..' attempted='..tostring(pending.attempted)..'\n')
        if not valid(held) and usable(pending.old,inventory.pawn) and not valid(pending.old:GetActorAttachingTo())
            and valid(pending.old_grip) then right:TryBeginInteractWith(0,pending.old_grip) end
        inventory.pending=nil; return
    end
    if pending.phase=='lower' then
        if not same(held,pending.old) then inventory.pending=nil; inventory.message='switch-cancelled'; return end
        if os.clock()-pending.started<.25 then return end
        -- Keep the old weapon held through its lowering motion, then release before attaching.
        if not pending.pc:RequestEndInteraction(right,pending.old_grip) then
            inventory.pending=nil; inventory.message='release-rejected'; return
        end
        if not pending.pc:RequestSetInteractableAttachment(pending.old,pending.home.holster.RootComp,
            pending.home.socket,pending.home.attachment) then
            right:TryBeginInteractWith(0,pending.old_grip)
            inventory.pending=nil; inventory.message='holster-rejected'; return
        end
        pending.phase='equip'
        held=M.held(right)
    end
    local put_away=not pending.home or (valid(pending.old) and same(pending.old:GetActorAttachingTo(),pending.home.holster))
    if put_away and not valid(held) and not pending.attempted and os.clock()>=pending.equip_after then
        local result=right:TryBeginInteractWith(0,pending.grip)
        print('[FlatscreenInventory] grip result='..tostring(result)..'\n')
        pending.attempted=true
    end
end
function M.lowering(inventory,item)
    local pending=inventory.pending
    if not pending then return 0 end
    local amount=0
    if pending.phase=='lower' and same(item,pending.old) then
        amount=math.min(1,math.max(0,(os.clock()-pending.started)/.25))
    elseif same(item,pending.target.item) then
        amount=pending.raise_started and math.min(1,math.max(0,1-(os.clock()-pending.raise_started)/.25)) or 1
    end
    return amount*amount*(3-2*amount)
end
return M
