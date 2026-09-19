local M={}
local throw_velocity
local inventory=require('Inventory')
local function valid(o) return o and o:IsValid() end
local function same(a,b) return valid(a) and valid(b) and a:GetAddress()==b:GetAddress() end
local function is_a(item,name) return valid(item) and item:IsA(StaticFindObject(name)) end
function M.apply_throw_velocity(controller,output)
    if not throw_velocity or not same(controller,throw_velocity.controller) then return end
    -- The stock grenade multiplies controller swing by 1.6 in GetDropVelocity.
    -- Supply it during native release so the stock drop request carries it online.
    local v=throw_velocity.value
    output.X,output.Y,output.Z=v.X/1.6,v.Y/1.6,v.Z/1.6
    throw_velocity.used=true
end
function M.new() return {message='ready'} end
function M.stop(action,pc,left,right)
    if action.pin and valid(action.pin) then pc:RequestEndInteraction(left,action.pin) end
    action.pin,action.item,action.swing=nil,nil,nil
end
function M.press(action,item,pc,left,right)
    if action.item then return true end
    if is_a(item,'/Game/Core/VRInteractables/MeleeWeapons/CS_MeleeWeapon.CS_MeleeWeapon_C') then
        action.item,action.swing,action.message=item,os.clock(),'swing'
        return true
    elseif is_a(item,'/Game/Core/VRInteractables/Throwables/Grenades/ZomboyGrenadeBP.ZomboyGrenadeBP_C') then
        action.item,action.started,action.message=item,os.clock(),'pulling-pin'
        if not item.bSafetyPinPull then
            local pin=item.HandInteraction1
            if not valid(pin) then action.item=nil; action.message='no-pin-grip'; return true end
            local p=pin:K2_GetComponentLocation()
            left:K2_SetWorldLocationAndRotation({X=p.X,Y=p.Y,Z=p.Z},pin:K2_GetComponentRotation(),false,{},true)
            if not left:TryBeginInteractWith(pin.DefaultInteractionButton,pin) then
                action.item=nil; action.message='pin-grip-rejected'; return true
            end
            action.pin=pin
        end
        return true
    elseif is_a(item,'/Game/Core/VRInteractables/Throwables/Grenades/Claymore/ZomboyClaymoreBP.ZomboyClaymoreBP_C') then
        local preview=item.DeployPreviewActorRef
        if item.bCanBePlanted and item.bIsAbleToPlace and valid(preview) and preview.bIsValidPlacement then
            local _,grip=inventory.held(right)
            action.message=pc:RequestEndInteraction(right,grip) and 'claymore-placement-requested' or 'placement-rejected'
        else action.message='invalid-placement' end
        return true
    end
    return false
end
function M.offset(action)
    if not action.swing then return 0 end
    local t=(os.clock()-action.swing)/.32
    return t<1 and math.sin(math.pi*t)*45 or 0
end
function M.tick(action,down,allowed,pc,left,right,camera)
    if not action.item then return end
    if not allowed or not same(action.item,inventory.held(right)) then M.stop(action,pc,left,right); return end
    if action.swing then
        if os.clock()-action.swing>=.32 then action.swing,action.item=nil,nil; action.message='swing-finished' end
        return
    end
    local item=action.item
    if item.bSafetyPinPull or M.is_ninja_smoke(item) then
        if action.pin then pc:RequestEndInteraction(left,action.pin); action.pin=nil end
        action.message='grenade-ready'
        if not down then
            local _,grip=inventory.held(right)
            local f=camera:GetForwardVector()
            local request={controller=right,value={X=f.X*1400,Y=f.Y*1400,Z=f.Z*1400+180}}
            throw_velocity=request
            local ok,released=pcall(function() return pc:RequestEndInteraction(right,grip) end)
            throw_velocity=nil
            if not ok then error(released) end
            if released then
                action.message=request.used and 'grenade-thrown' or 'throw-velocity-not-applied'
            else action.message='throw-rejected' end
            action.item=nil
        end
    elseif os.clock()-action.started>1 then
        M.stop(action,pc,left,right); action.message='pin-pull-timeout'
    elseif action.pin then
        local arrow=item.SafetyPinArrow
        local p,f=arrow:K2_GetComponentLocation(),arrow:GetForwardVector()
        local distance=item.SafetyPullDistance*6+5
        left:K2_SetWorldLocationAndRotation({X=p.X+f.X*distance,Y=p.Y+f.Y*distance,Z=p.Z+f.Z*distance},
            arrow:K2_GetComponentRotation(),false,{},true)
    end
end
-- Private stock Ninja controls, appended to ItemActions before return M.
local bow_class='/Game/Core/VRInteractables/Ninja/Bow.Bow_C'
local melee_class='/Game/Core/VRInteractables/MeleeWeapons/CS_MeleeWeapon.CS_MeleeWeapon_C'
function M.is_bow(item) return is_a(item,bow_class) end
function M.is_melee(item) return is_a(item,melee_class) end
function M.is_ninja_smoke(item) return is_a(item,'/Game/Core/VRInteractables/Ninja/Loadout/NinjaSmokeGrenade.NinjaSmokeGrenade_C') end
local old_new,old_press,old_tick,old_stop=M.new,M.press,M.tick,M.stop
function M.new(pawn,left,right)
    local action=old_new()
    action.pawn,action.right,action.drivers=pawn,right,{}
    if not pawn then return action end
    for _,hand in ipairs({left,right}) do
        local p=hand.RelativeLocation
        action.drivers[#action.drivers+1]={hand=hand,parent=hand:GetAttachParent(),
            origin={X=p.X,Y=p.Y,Z=p.Z}}
    end
    return action
end
function M.prepare(action)
    for _,driver in ipairs(action.drivers) do
        local p=driver.hand.RelativeLocation
        driver.origin={X=p.X,Y=p.Y,Z=p.Z}
    end
end
local function end_bow(action,pc,left,cancel)
    local bow,grip=action.item,action.string
    if valid(bow) and cancel then
        -- Stock release checks this latch before creating either arrow projectile.
        bow.bAlreadyReleased=true
        bow.PullDistance=0
        local p=bow.PullTransformRelativeLocation
        bow.PullTransform:K2_SetRelativeLocation({X=p.X,Y=p.Y,Z=p.Z},false,{},true)
        bow.StaticMesh:SetHiddenInGame(true,false)
    end
    if valid(grip) then pc:RequestEndInteraction(left,grip) end
    action.string,action.draw_started,action.bow_origin=nil,nil,nil
    action.item=nil
    action.message=cancel and 'bow-cancelled' or 'bow-released'
end
function M.stop(action,pc,left,right)
    if action.string then end_bow(action,pc,left,true) end
    if valid(action.blade) then action.blade:SetComponentTickEnabled(false) end
    old_stop(action,pc,left,right)
end
function M.press(action,item,pc,left,right)
    if action.item then return true end
    if M.is_ninja_smoke(item) then
        -- This stock impact smoke deliberately rejects its inherited pin grip.
        action.item,action.message=item,'grenade-ready'
        return true
    end
    if not M.is_bow(item) then return old_press(action,item,pc,left,right) end
    local grip=item.BowStringInteraction
    if not valid(grip) or valid(inventory.held(left)) then action.message='bow-hand-unavailable';return true end
    local p=grip:K2_GetComponentLocation()
    left:K2_SetWorldLocationAndRotation({X=p.X,Y=p.Y,Z=p.Z},grip:K2_GetComponentRotation(),false,{},true)
    if not left:TryBeginInteractWith(grip.DefaultInteractionButton,grip) then action.message='bow-grip-rejected';return true end
    action.item,action.string,action.started,action.message=item,grip,os.clock(),'bow-gripping'
    return true
end
function M.slash(action)
    if not action.swing then return 0,20,-24,false,30,30 end
    local t=os.clock()-action.swing
    -- 50 ms wind-up, 100 ms diagonal cut, 150 ms recovery.
    -- Gerald requested a wider cut: 100 cm across, retaining the 60 cm drop.
    -- Rest lower/right; join the accepted cutting path only during wind-up.
    -- Turn the blade through the target. A fixed raised wrist leaves the long
    -- blade above the target even when the hand crosses their body.
    if t<.05 then local a=t/.05;return 0,20+22*a,-24+48*a,false,30+20*a,30-50*a end
    if t<.15 then local a=(t-.05)/.10;return 10*a,42-100*a,24-60*a,true,50+80*a,-20+40*a end
    local a=math.max(0,1-(t-.15)/.15)
    return 10*a,20-78*a,-24-12*a,false,30+100*a,30-10*a
end
function M.offset() return 0 end
function M.tick(action,down,allowed,pc,left,right,camera)
    if action.swing then
        if not allowed or not same(action.item,inventory.held(right)) then M.stop(action,pc,left,right)
        elseif os.clock()-action.swing>=.30 then action.swing,action.item=nil,nil;action.message='swing-finished' end
        return
    end
    if not action.string then return old_tick(action,down,allowed,pc,left,right,camera) end
    if not allowed or not same(action.item,inventory.held(right)) then end_bow(action,pc,left,true);return end
    local bow=action.item
    local _,held_grip=inventory.held(left)
    if not same(held_grip,action.string) then
        if not down or os.clock()-action.started>.75 then end_bow(action,pc,left,true) end
        return
    end
    if not action.draw_started then
        action.draw_started=os.clock()
        local p,o=action.string:K2_GetComponentLocation(),bow:K2_GetActorLocation()
        local function local_axis(v) return (p.X-o.X)*v.X+(p.Y-o.Y)*v.Y+(p.Z-o.Z)*v.Z end
        action.bow_origin={X=bow.cachedRelativeLocation.X,Y=local_axis(bow:GetActorRightVector()),Z=local_axis(bow:GetActorUpVector())}
    end
    if not down then end_bow(action,pc,left,bow.PullDistance<1);return end
    local draw=36*math.min(1,(os.clock()-action.draw_started)/.6)
    local p,f,r,u=bow:K2_GetActorLocation(),bow:GetActorForwardVector(),bow:GetActorRightVector(),bow:GetActorUpVector()
    local o=action.bow_origin
    left:K2_SetWorldLocationAndRotation({X=p.X+f.X*(o.X-draw)+r.X*o.Y+u.X*o.Z,
        Y=p.Y+f.Y*(o.X-draw)+r.Y*o.Y+u.Y*o.Z,Z=p.Z+f.Z*(o.X-draw)+r.Z*o.Y+u.Z*o.Z},
        bow:K2_GetActorRotation(),false,{},true)
    action.message=draw>=36 and 'bow-ready' or 'bow-drawing'
end

-- The native untracked tick restores its cached relative hand position before
-- sampling speed. Move a parent instead, so the normal velocity history sees
-- our final hand movement. No synthetic damage or private memory writes.
function M.follow(action,item,allowed)
    local active=allowed and (M.is_bow(item) or M.is_melee(item))
    local blade=M.is_melee(item) and item.ZomboyBlade or nil
    if not same(blade,action.blade) then
        -- Release/drop already ran the stock blade cleanup. Do not re-enable it.
        action.blade=valid(blade) and blade or nil
        action.blade_tick=valid(blade) and blade:IsComponentTickEnabled() or false
    end
    if valid(action.blade) then
        local _,_,_,cut=M.slash(action)
        action.blade:SetComponentTickEnabled(action.blade_tick and allowed and cut)
    end
    for _,driver in ipairs(action.drivers) do
        local hand=driver.hand
        if active and not valid(driver.actor) then
            local zero={X=0,Y=0,Z=0}
            driver.actor=action.pawn:GetWorld():SpawnActor(StaticFindObject('/Script/Engine.CameraActor'),zero,{Pitch=0,Yaw=0,Roll=0})
            assert(valid(driver.actor),'Ninja hand driver could not spawn')
            driver.actor:SetActorHiddenInGame(true);driver.actor:SetActorEnableCollision(false)
            driver.root=driver.actor.RootComponent
            driver.root:K2_AttachToComponent(driver.parent,FName('None'),0,0,0,false)
            driver.root:K2_SetRelativeLocationAndRotation(zero,{Pitch=0,Yaw=0,Roll=0},false,{},true)
            hand:K2_AttachToComponent(driver.root,FName('None'),0,0,0,false)
        end
        if valid(driver.actor) then
            if active then
                local target=hand:K2_GetComponentLocation()
                hand:K2_SetRelativeLocation(driver.origin,false,{},true)
                local at,p=hand:K2_GetComponentLocation(),driver.root:K2_GetComponentLocation()
                driver.root:K2_SetWorldLocation({X=p.X+target.X-at.X,Y=p.Y+target.Y-at.Y,Z=p.Z+target.Z-at.Z},false,{},true)
            else
                local target=hand:K2_GetComponentLocation()
                driver.root:K2_SetRelativeLocation({X=0,Y=0,Z=0},false,{},true)
                hand:K2_SetWorldLocation(target,false,{},true)
            end
        end
    end
end
function M.shutdown(action)
    if valid(action.blade) and action.right and same(action.blade:GetOwner(),inventory.held(action.right)) then
        action.blade:SetComponentTickEnabled(action.blade_tick)
    end
    for _,driver in ipairs(action.drivers) do
        if valid(driver.actor) then
            if valid(driver.hand) and valid(driver.parent) then driver.hand:K2_AttachToComponent(driver.parent,FName('None'),1,1,1,false) end
            driver.actor:K2_DestroyActor()
        end
    end
end

return M
