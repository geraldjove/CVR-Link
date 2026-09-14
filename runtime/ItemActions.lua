local M={}
local inventory=require('Inventory')
local function valid(o) return o and o:IsValid() end
local function same(a,b) return valid(a) and valid(b) and a:GetAddress()==b:GetAddress() end
local function is_a(item,name) return valid(item) and item:IsA(StaticFindObject(name)) end
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
    if item.bSafetyPinPull then
        if action.pin then pc:RequestEndInteraction(left,action.pin); action.pin=nil end
        action.message='grenade-ready'
        if not down then
            -- Native drop starts the grenade's existing projectile/fuse behavior.
            local _,grip=inventory.held(right)
            if pc:RequestEndInteraction(right,grip) then
                local f=camera:GetForwardVector()
                local velocity={X=f.X*1400,Y=f.Y*1400,Z=f.Z*1400+180}
                item.ProjectileMovement.Velocity=velocity
                action.message='grenade-thrown'
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
return M
