-- Game-thread keyboard bridge using the stock controller and widget interactions.
local M, state = {}, nil
local inventory=require('Inventory')
local actions=require('ItemActions')
local placement=require('Placement')
local ammo=require('Ammo')
local bindings,field_of_view={},80
function M.configure(values,fov) bindings=values or {}; field_of_view=fov or 80 end
local function down_key(pc,name) return pc:IsInputKeyDown({KeyName=FName(bindings[name] or name)}) end
local function valid(o) return o and o:IsValid() end
local function copy(v, fields)
    local result = {}
    for _,name in ipairs(fields) do result[name]=v[name] end
    return result
end
local function pose(component)
    return {component=component, position=copy(component.RelativeLocation,{'X','Y','Z'}),
        rotation=copy(component.RelativeRotation,{'Pitch','Yaw','Roll'})}
end
local function transform(value)
    return {Rotation=copy(value.Rotation,{'X','Y','Z','W'}),
        Translation=copy(value.Translation,{'X','Y','Z'}),Scale3D=copy(value.Scale3D,{'X','Y','Z'})}
end
local function multiply(a,b)
    return {X=a.W*b.X+a.X*b.W+a.Y*b.Z-a.Z*b.Y,
        Y=a.W*b.Y-a.X*b.Z+a.Y*b.W+a.Z*b.X,
        Z=a.W*b.Z+a.X*b.Y-a.Y*b.X+a.Z*b.W,
        W=a.W*b.W-a.X*b.X-a.Y*b.Y-a.Z*b.Z}
end
local function rotate(q,v)
    local t={X=2*(q.Y*v.Z-q.Z*v.Y),Y=2*(q.Z*v.X-q.X*v.Z),Z=2*(q.X*v.Y-q.Y*v.X)}
    return {X=v.X+q.W*t.X+q.Y*t.Z-q.Z*t.Y,
        Y=v.Y+q.W*t.Y+q.Z*t.X-q.X*t.Z,Z=v.Z+q.W*t.Z+q.X*t.Y-q.Y*t.X}
end
local function rotator(q)
    -- Unreal's FQuat::Rotator convention, including the vertical singularities.
    local s=q.Z*q.X-q.W*q.Y
    local yaw=math.deg(math.atan(2*(q.W*q.Z+q.X*q.Y),1-2*(q.Y*q.Y+q.Z*q.Z)))
    if math.abs(s)>.4999995 then
        local sign=s<0 and -1 or 1
        return {Pitch=sign*90,Yaw=yaw,Roll=(sign*yaw-2*math.deg(math.atan(q.X,q.W))+180)%360-180}
    end
    return {Pitch=math.deg(math.asin(2*s)),Yaw=yaw,
        Roll=math.deg(math.atan(-2*(q.W*q.X+q.Y*q.Z),1-2*(q.X*q.X+q.Y*q.Y)))}
end
local function relative(world,body)
    local q=body.Rotation
    local inverse={X=-q.X,Y=-q.Y,Z=-q.Z,W=q.W}
    return {Rotation=multiply(inverse,world.Rotation),Scale3D={X=1,Y=1,Z=1},
        Translation=rotate(inverse,{X=world.Translation.X-body.Translation.X,
            Y=world.Translation.Y-body.Translation.Y,Z=world.Translation.Z-body.Translation.Z})}
end
local function blend_reference(a,b,t)
    local q,position={},{}
    local dot=a.Rotation.X*b.Rotation.X+a.Rotation.Y*b.Rotation.Y+a.Rotation.Z*b.Rotation.Z+a.Rotation.W*b.Rotation.W
    local sign=dot<0 and -1 or 1
    local length=0
    for _,axis in ipairs({'X','Y','Z','W'}) do
        q[axis]=a.Rotation[axis]*(1-t)+b.Rotation[axis]*sign*t
        length=length+q[axis]*q[axis]
    end
    for axis,value in pairs(q) do q[axis]=value/math.sqrt(length) end
    for _,axis in ipairs({'X','Y','Z'}) do position[axis]=a.Translation[axis]*(1-t)+b.Translation[axis]*t end
    return {Rotation=q,Translation=position}
end
local function key(name) return {KeyName=FName(name)} end
local function same(a,b) return valid(a) and valid(b) and a:GetAddress()==b:GetAddress() end
local function holding() return state.pawn:GetHandHoldingGun(true) end
local function release_fire()
    if state.firing and valid(state.right) then state.right:OnTriggerAxisChanged(0) end
    state.firing=false
end
local function release_support()
    if state.support_owned and valid(state.left) then state.left:OnGripButtonReleased() end
    state.support_owned,state.support_gun,state.support_attempt=false,nil,nil
end
local function cancel_reload()
    state.reload_deadline,state.reload_gun,state.reload_plan=nil,nil,nil
end
local function cycle_bolt(gun,blocked)
    if blocked or not same(state.bolt_gun,gun) then state.bolt_deadline=nil end
    state.bolt_gun=gun
    if blocked or not valid(gun) or not gun.GunData.bBoltAction
        or not valid(gun.GunBoltComponent) or gun:HasBulletInChamber() or not gun:HaseUsedBulletInChamber() then
        state.bolt_deadline=nil
        return
    end
    -- The stock bolt-action handle ejects the spent case and chambers one round.
    -- Keep a short manual-action pause, then use those same ammo/bolt APIs.
    release_fire()
    state.bolt_deadline=state.bolt_deadline or os.clock()+.8
    if os.clock()>=state.bolt_deadline and gun.GunBoltComponent:GetBoltState()==0 then
        gun:EjectChamberBullet()
        gun:MoveBulletToChamber()
        gun.GunBoltComponent:BoltTravelFullRound(0)
        state.bolt_deadline=nil
        state.bolts_cycled=(state.bolts_cycled or 0)+1
    end
end
local function complete_reload(gun)
    local completed,message=ammo.complete(state.reload_plan)
    state.reload_result=message
    if completed then
        state.reload_last_seconds=os.clock()-state.reload_deadline+1.5
        state.reloads_completed=(state.reloads_completed or 0)+1
    end
    cancel_reload()
end
function M.stop()
    if not state then return end
    cancel_reload()
    placement.stop()
    if state.pc then actions.stop(state.action,state.pc,state.left,state.right) end
    release_fire()
    release_support()
    if valid(state.camera) then state.camera:SetFieldOfView(state.fov) end
    if valid(state.pawn) then
        if state.keyboard_movement then state.pawn:SetMovementInput_X(0); state.pawn:SetMovementInput_Y(0) end
        if state.crouched then state.pawn.CrouchCurve:Reverse() end
        if state.sprint_owned then state.pawn:SetSprint(false,false) end
    end
    if valid(state.ads_gun) then state.ads_gun:SetPancakeAimingDownSight(false) end
    if valid(state.pointer) then
        if state.click then state.pointer:ReleasePointerKey(key('LeftMouseButton')) end
        if state.pointer_enabled then state.pointer:Enable() else state.pointer:Disable() end
    end
    for _,ring in ipairs(state.rings or {}) do
        if valid(ring.component) then ring.component:SetVisibility(ring.visible,false) end
    end
    if state.hand_mesh and valid(state.hand_mesh.component) then state.hand_mesh.component:SetVisibility(state.hand_mesh.visible,false) end
    if state.opened_menu and valid(state.pawn) and state.pawn.InputMode==1 then state.pawn:HideMenuUI() end
    for i=#state.poses,1,-1 do
        local saved=state.poses[i]
        if valid(saved.component) then
            saved.component:K2_SetRelativeLocationAndRotation(saved.position,saved.rotation,false,{},true)
            if saved.tick~=nil then
                saved.component.bUseWithoutTracking=saved.untracked
                saved.component.bDisableLowLatencyUpdate=saved.low_latency
                saved.component:SetTrackingMode(saved.tracking)
                saved.component:SetComponentTickEnabled(saved.tick)
            end
        end
    end
    state=nil
end
function M.start(pawn)
    -- LocalPlayerSetup creates the menu pointer after the pawn can begin ticking.
    -- Wait before taking control so a loading/respawning pawn can retry safely.
    local pointer=pawn.RightUIInteractionActor
    if not valid(pawn.RightMotionController) or not valid(pawn.LeftMotionController)
        or not valid(pointer) or not valid(pointer.RootComponent) or not valid(pointer.WidgetInteraction) then return false end
    state={pawn=pawn,keys={},poses={},first=true}
    state.camera,state.fov=pawn.PlayerCamera,pawn.PlayerCamera.FieldOfView
    if valid(pawn.Mesh) then state.hand_mesh={component=pawn.Mesh,visible=pawn.Mesh.bVisible} end
    state.right=pawn.RightMotionController
    state.left=pawn.LeftMotionController
    assert(valid(state.right), 'right controller unavailable')
    for _,controller in ipairs({state.right,pawn.LeftMotionController}) do
        assert(valid(controller), 'motion controller unavailable')
        local saved=pose(controller)
        saved.tick=controller:IsComponentTickEnabled()
        saved.untracked=controller.bUseWithoutTracking
        saved.low_latency=controller.bDisableLowLatencyUpdate
        saved.tracking=controller.PendingTrackingMode
        state.poses[#state.poses+1]=saved
        controller.bUseWithoutTracking=true
        controller.bDisableLowLatencyUpdate=true
        controller:SetTrackingMode(1) -- ANIMATION: keep the interaction tick without tracked hand poses.
        controller:SetComponentTickEnabled(true)
    end
    state.pointer=pointer
    assert(valid(state.pointer), 'right menu pointer unavailable')
    state.pointer_enabled=state.pointer.bIsEnabled
    state.poses[#state.poses+1]=pose(state.pointer.RootComponent)
    state.pointer:Enable()
    state.rings={}
    for _,pointer in ipairs({state.pointer,pawn.LeftUIInteractionActor}) do
        if valid(pointer) and valid(pointer.StaticMesh) then
            state.rings[#state.rings+1]={component=pointer.StaticMesh,visible=pointer.StaticMesh.bVisible}
            pointer.StaticMesh:SetVisibility(false,false)
        end
    end
    state.inventory=inventory.new(pawn)
    state.action=actions.new()
    return true
end
local function place(component, camera, forward, sideways, height, rotation)
    local p=camera:K2_GetComponentLocation()
    local f,r,u=camera:GetForwardVector(),camera:GetRightVector(),camera:GetUpVector()
    component:K2_SetWorldLocationAndRotation({
        X=p.X+f.X*forward+r.X*sideways+u.X*height,
        Y=p.Y+f.Y*forward+r.Y*sideways+u.Y*height,
        Z=p.Z+f.Z*forward+r.Z*sideways+u.Z*height},rotation,false,{},true)
end
local function sight_reference(gun)
    for _,sight in ipairs(FindAllOf('ZomboyGunSightAttachmentActor') or {}) do
        if same(sight:GetOwner(),gun) then
            return relative(transform(sight:GetSightTransform()),transform(gun:GetTransform()))
        end
    end
    return transform(gun.DefaultSightRelativeTransform)
end
function M.hud_state()
    return state and (state.ads_amount or 0)>0, state and state.reload_deadline~=nil
end
function M.wants_look(pawn)
    return pawn.InputMode==0 and not (state and valid(state.pc)
        and down_key(state.pc,'MiddleMouseButton') and placement.can_rotate(pawn,inventory.held(state.right)))
end
function M.tick(pawn,pc,camera,rotation,dx,dy)
    if not state then return end
    state.pc=pc
    state.view=copy(rotation,{'Pitch','Yaw','Roll'})
    local pressed,down={},{}
    for _,name in ipairs({'Tab','E','G','B','One','Two','Three','Four','Five','V','R','F6','LeftMouseButton','RightMouseButton','MiddleMouseButton','LeftAlt','RightAlt','LeftShift','LeftControl','C'}) do
        down[name]=down_key(pc,name)
        pressed[name]=down[name] and not state.keys[name] and not state.first
    end
    state.keys,state.first=down,false
    local gun=holding()
    if state.reload_deadline then
        if pawn.InputMode~=0 or not same(state.reload_gun,gun) then
            cancel_reload()
        elseif os.clock()>=state.reload_deadline then
            complete_reload(gun)
        end
    end
    if state.support_gun and not same(state.support_gun,gun) then release_support() end
    if pressed.F6 then
        state.zoom_mode=not state.zoom_mode
        state.ads_amount,state.ads_goal=0,nil
        if valid(state.ads_gun) then state.ads_gun:SetPancakeAimingDownSight(false); state.ads_gun=nil end
    end
    local menu=pawn.InputMode~=0
    if bindings.W then
        -- Use the stock movement setters with the chosen PC keys. VR keys are untouched.
        pawn:SetMovementInput_X(not menu and ((down_key(pc,'D') and 1 or 0)-(down_key(pc,'A') and 1 or 0)) or 0)
        pawn:SetMovementInput_Y(not menu and ((down_key(pc,'W') and 1 or 0)-(down_key(pc,'S') and 1 or 0)) or 0)
        state.keyboard_movement=true
    end
    local aiming=down.RightMouseButton and valid(gun) and not menu
    local hand_item=inventory.held(state.right)
    local vertical_rotation=down.LeftAlt or down.RightAlt
    placement.follow(pawn,hand_item,camera,rotation,down.MiddleMouseButton,
        vertical_rotation and 0 or dx,vertical_rotation and dy or 0)
    local utility=valid(hand_item) and not valid(gun)
    place(state.right,camera,(utility and 45 or 35)+actions.offset(state.action),
        utility and 12 or (aiming and 0 or 16),utility and -10 or (aiming and -6 or -20),rotation)
    place(pawn.LeftMotionController,camera,40,-16,-24,rotation)
    local pointer_rotation=rotation
    if menu then
        state.pointer_yaw=math.max(-70,math.min(70,(state.pointer_yaw or 0)+(dx or 0)))
        state.pointer_pitch=math.max(-65,math.min(65,(state.pointer_pitch or 0)+(dy or 0)))
        pointer_rotation={Pitch=math.max(-85,math.min(85,rotation.Pitch+state.pointer_pitch)),
            Yaw=rotation.Yaw+state.pointer_yaw,Roll=0}
    else state.pointer_yaw,state.pointer_pitch=0,0 end
    place(state.pointer.RootComponent,camera,5,0,0,pointer_rotation)
    if pressed.Tab then
        release_fire()
        if pawn.InputMode==1 then pawn:HideMenuUI()
        else pawn:ShowMenuUI(true,FName('None')); state.opened_menu=true end
    end
    if not state.pointer.bIsEnabled then state.pointer:Enable() end
    local over_ui=state.pointer.WidgetInteraction:IsOverHitTestVisibleWidget()
    menu=pawn.InputMode~=0
    aiming=down.RightMouseButton and valid(gun) and not menu and not over_ui and not state.inventory.pending and not state.reload_deadline
    state.aiming=aiming and not state.zoom_mode and not state.reload_deadline
    local crouch_down=down.LeftControl or down.C
    local crouch=state.crouched and crouch_down and not menu or false
    if crouch_down and not state.crouch_down and not menu and os.clock()>=(state.next_crouch or 0) then crouch=true end
    state.crouch_down=crouch_down
    local movement=pawn.CharacterMovement
    if crouch~=(state.crouched or false) then
        if crouch then
            local v=movement.Velocity
            local running=v.X*v.X+v.Y*v.Y>=(movement.MaxWalkSpeed*.9)^2
            state.slide_deadline=pawn:IsSprinting() and movement:IsMovingOnGround() and running and os.clock()+.6 or nil
            -- The stock events restart two different curves at full height/depth.
            -- Reverse one timeline at its current position so a quick release cannot snap down.
            pawn.UncrouchCurve:Stop()
            pawn.CrouchCurve:Play()
            state.next_crouch=os.clock()+.5
        else pawn.CrouchCurve:Reverse(); state.slide_deadline=nil end
        state.crouched=crouch
    end
    if state.slide_deadline then
        if os.clock()>state.slide_deadline or not movement:IsMovingOnGround() then state.slide_deadline=nil
        elseif pawn:IsCrouching() then
            local v=movement.Velocity
            if v.X*v.X+v.Y*v.Y>=(movement.MaxWalkSpeed*.45)^2 then
                -- Stock PhysSliding / GetIsSliding use MOVE_Custom with custom mode 3.
                movement:SetMovementMode(6,3)
                assert(pawn:GetIsSliding(),'native slide mode readback failed')
                state.slides_started=(state.slides_started or 0)+1
            end
            state.slide_deadline=nil
        end
    end
    -- SetSprint can auto-run in the stock game. Only request it with forward input.
    local sprint=down.LeftShift and down_key(pc,'W') and not down_key(pc,'S') and not menu and not aiming
    if sprint and not crouch and not pawn:GetIsSliding() then
        if not pawn:IsSprinting() then pawn:SetSprint(true,false) end
        state.sprint_owned=true
    elseif not sprint and (state.sprint_owned or pawn:IsSprinting()) then
        pawn:SetSprint(false,false); state.sprint_owned=false
    end
    local velocity=movement.Velocity
    local running=pawn:IsSprinting() and not menu and not crouch and not pawn:GetIsSliding()
        and velocity.X*velocity.X+velocity.Y*velocity.Y>1
    local now=os.clock()
    if running~=(state.sprinting or false) then
        state.sprint_from,state.sprint_started=state.sprint_amount or 0,now
        if not running then state.sprint_aim_ready_at=now+.3 end
        state.sprinting=running
    end
    local progress=math.min(1,math.max(0,(now-(state.sprint_started or now))/(running and .2 or .5)))
    local goal=running and 1 or 0
    state.sprint_amount=(state.sprint_from or 0)+(goal-(state.sprint_from or 0))*progress*progress*(3-2*progress)
    state.sprint_blocked=running
    state.sprint_aim_blocked=running or now<(state.sprint_aim_ready_at or 0)
    if (menu or over_ui or state.sprint_blocked) and state.firing then release_fire() end
    if pressed.LeftMouseButton then
        if over_ui then state.pointer:PressPointerKey(key('LeftMouseButton')); state.click=true
        elseif not menu and not state.inventory.pending and not state.reload_deadline and not state.sprint_blocked then
            if not actions.press(state.action,inventory.held(state.right),pc,state.left,state.right) then
                state.right:OnTriggerAxisChanged(1); state.firing=true
            end
        end
    end
    if not down.LeftMouseButton then
        release_fire()
        if state.click and not down.E then state.pointer:ReleasePointerKey(key('LeftMouseButton')); state.click=false end
    end
    local wheel=pc:GetInputAnalogKeyState(key('MouseWheelAxis'))
    if wheel~=0 and over_ui then state.pointer:ScrollWheel(wheel) end
    if pressed.G and not menu then
        placement.stop()
        cancel_reload()
        actions.stop(state.action,pc,state.left,state.right)
        release_fire()
        state.inventory.pending=nil
        if valid(inventory.held(state.right)) then release_support(); state.right:OnGripButtonReleased(); gun=nil; state.aiming=false
        end
    end
    if pressed.E then
        local handled=false
        if not menu and not state.inventory.pending and not state.reload_deadline then
            handled=inventory.interact(state.inventory,state.right,camera)
        end
        if not handled and over_ui and not state.click then
            state.pointer:PressPointerKey(key('LeftMouseButton')); state.click=true
        end
    end
    if pressed.B and not menu and valid(gun) then gun:ChangeFiringMode() end
    if not menu then
        for _,name in ipairs({'One','Two','Three','Four','Five','V'}) do
            if pressed[name] then inventory.select(state.inventory,name,pc,state.right,function()
                placement.stop()
                cancel_reload()
                actions.stop(state.action,pc,state.left,state.right)
                release_fire(); release_support(); state.aiming=false
                if valid(state.ads_gun) then state.ads_gun:SetPancakeAimingDownSight(false); state.ads_gun=nil end
            end); break end
        end
        inventory.tick(state.inventory,state.right)
        gun=holding()
    end
    if menu then state.inventory.pending=nil end
    if pressed.R and not menu and valid(gun) and not state.reload_deadline and not state.inventory.pending then
        local plan,message=ammo.plan(pawn,gun)
        state.reload_result=message
        if plan then
            release_fire()
            state.reload_plan,state.reload_gun,state.reload_deadline=plan,gun,os.clock()+1.5
        end
    end
    cycle_bolt(gun,menu or state.reload_deadline~=nil or state.inventory.pending~=nil)
    if not same(state.aim_weapon,gun) then
        state.aim_weapon,state.ads_amount,state.ads_goal,state.sight=gun,0,nil,nil
    end
    aiming=down.RightMouseButton and valid(gun) and not menu and not over_ui and not state.inventory.pending
        and not state.reload_deadline and not state.sprint_aim_blocked
    state.aiming=aiming and not state.zoom_mode
    if valid(state.ads_gun) and (not same(state.ads_gun,gun) or not state.aiming) then
        state.ads_gun:SetPancakeAimingDownSight(false); state.ads_gun=nil
    end
    if state.aiming and not same(state.ads_gun,gun) then
        state.sight=sight_reference(gun)
        gun:SetPancakeAimingDownSight(true); state.ads_gun=gun
    end
    local goal=aiming and 1 or 0
    if state.ads_goal~=goal then
        state.ads_from,state.ads_goal,state.ads_started=state.ads_amount or 0,goal,os.clock()
    end
    local progress=math.min(1,math.max(0,(os.clock()-state.ads_started)/.2))
    state.ads_amount=state.ads_from+(goal-state.ads_from)*progress*progress*(3-2*progress)
    camera:SetFieldOfView(field_of_view*(1-(state.zoom_mode and .35*state.ads_amount or 0)))
    placement.update()
    local output={Rotation={},Translation={},Scale3D={}}
    state.aim_point=nil
    if valid(gun) and not menu then
        local origin,direction=camera:K2_GetComponentLocation(),camera:GetForwardVector()
        local start={X=origin.X,Y=origin.Y,Z=origin.Z}
        local finish={X=start.X+direction.X*100000,Y=start.Y+direction.Y*100000,Z=start.Z+direction.Z*100000}
        local hit,color={},{R=0,G=0,B=0,A=0}
        local system=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
        if system:LineTraceSingle(pawn,start,finish,2,true,{pawn,gun},0,hit,true,color,color,0) then
            state.aim_point=copy(hit.ImpactPoint,{'X','Y','Z'})
        end
    end
    local item=inventory.held(state.right)
    local gadget=valid(item) and (item:IsA('/Game/Core/VRInteractables/Throwables/Grenades/ZomboyGrenadeBP.ZomboyGrenadeBP_C')
        or item:IsA('/Game/Core/VRInteractables/Throwables/Grenades/Claymore/ZomboyClaymoreBP.ZomboyClaymoreBP_C'))
    for _,tag in ipairs({'Gadget1','Gadget2','Gadget3'}) do
        local slot=state.inventory.slots[tag]
        if slot and same(item,slot.item) then gadget=true end
    end
    state.hands_hidden=gadget and not menu
    if state.hand_mesh and valid(state.hand_mesh.component) then
        local visible=state.hand_mesh.visible and not state.hands_hidden
        if state.hand_mesh.component.bVisible~=visible then state.hand_mesh.component:SetVisibility(visible,false) end
    end
    if M.apply_gun_pose(item,output) then
        item:K2_SetActorLocationAndRotation(output.Translation,rotator(output.Rotation),false,{},true)
        if valid(gun) and valid(gun.ForeGripComponent) then
            local grip=gun.ForeGripComponent:K2_GetComponentLocation()
            state.left:K2_SetWorldLocationAndRotation(copy(grip,{'X','Y','Z'}),state.view,false,{},true)
            if not state.inventory.pending and not same(state.support_attempt,gun) then
                state.support_attempt=gun
                if not valid(pawn:GetHandHoldingGun(false)) then
                    state.left:TryBeginInteractWith(0,gun.ForeGripComponent)
                    state.support_owned,state.support_gun=true,gun
                end
            end
        end
    end
    actions.tick(state.action,down.LeftMouseButton,not menu and not over_ui,pc,state.left,state.right,camera)
end
function M.apply_utility_grab(item,output)
    if state and not same(item,holding()) and M.apply_gun_pose(item,output) then
        state.utility_grab_writes=(state.utility_grab_writes or 0)+1
        return true
    end
    return false
end
function M.capture_recoil(gun,original,output)
    if not state or not same(gun,holding()) or not same(gun:GetOwner(),state.pawn) then return false end
    state.recoil=relative(transform(output),transform(original))
    local q=state.recoil.Rotation
    assert(math.abs(q.X*q.X+q.Y*q.Y+q.Z*q.Z+q.W*q.W-1)<.001,'invalid native recoil rotation')
    state.recoil_gun=gun
    state.recoil_degrees=math.deg(2*math.acos(math.min(1,math.abs(state.recoil.Rotation.W))))
    state.recoil_peak=math.max(state.recoil_peak or 0,state.recoil_degrees)
    return true
end
function M.apply_gun_pose(gun,output)
    if not state or not state.view or not same(gun,inventory.held(state.right)) or not same(gun:GetOwner(),state.pawn) then return false end
    local camera=state.pawn.PlayerCamera
    local p=camera:K2_GetComponentLocation()
    local f,r,u=camera:GetForwardVector(),camera:GetRightVector(),camera:GetUpVector()
    local reference,forward,sideways,height,grip_turn,aim
    if not same(gun,holding()) then
        if not same(state.item_pose,gun) then
            local _,grip=inventory.held(state.right)
            state.item_reference=relative(transform(grip:K2_GetComponentToWorld()),transform(gun:GetTransform()))
            if gun:IsA('/Game/Core/VRInteractables/Throwables/Grenades/ZomboyGrenadeBP.ZomboyGrenadeBP_C')
                and valid(gun.GrabHintGripIndicator) then
                state.item_reference.Rotation=relative(transform(gun.GrabHintGripIndicator:K2_GetComponentToWorld()),
                    transform(gun:GetTransform())).Rotation
            end
            state.item_pose=gun
        end
        reference=state.item_reference
        forward,sideways,height=45+actions.offset(state.action),12,-10
        if gun:IsA('/Game/Core/VRInteractables/Throwables/Grenades/ZomboyGrenadeBP.ZomboyGrenadeBP_C') then
            -- Match the wrist pitch of the confirmed rifle grip using each grenade's own hand reference.
            grip_turn={X=0,Y=-math.sin(math.rad(40)),Z=0,W=math.cos(math.rad(40))}
        elseif gun:IsA('/Game/Core/VRInteractables/Throwables/Grenades/Claymore/ZomboyClaymoreBP.ZomboyClaymoreBP_C') then
            grip_turn={X=0,Y=0,Z=1,W=0}
        end
    else
        reference=transform(gun.DefaultMuzzleRelativeTransform)
        aim=not state.zoom_mode and state.sight and state.ads_amount or 0
        if aim>0 then reference=blend_reference(reference,state.sight,aim) end
        forward,sideways,height=100-82*aim,16*(1-aim),-14*(1-aim)
        if state.aim_point then
            local point=state.aim_point
            local distance=(point.X-p.X)*f.X+(point.Y-p.Y)*f.Y+(point.Z-p.Z)*f.Z
            if distance>1 then
                -- Pull the muzzle back as a wall gets close; never turn it back through the player.
                local clearance=math.min(1,distance*.5/100)
                forward=forward*(aim+(1-aim)*clearance)
                sideways,height=sideways*clearance,height*clearance
            end
        end
    end
    local target={X=p.X+f.X*forward+r.X*sideways+u.X*height,
        Y=p.Y+f.Y*forward+r.Y*sideways+u.Y*height,Z=p.Z+f.Z*forward+r.Z*sideways+u.Z*height}
    local reload=state.reload_deadline and same(state.reload_gun,gun)
        and math.sin(math.pi*math.max(0,math.min(1,1-(state.reload_deadline-os.clock())/1.5))) or 0
    local switching=inventory.lowering(state.inventory,gun)
    local sprint=aim~=nil and (state.sprint_amount or 0) or 0
    if reload>0 or switching>0 or sprint>0 then
        local back,down=10*reload+14*switching+8*sprint,14*reload+38*switching+22*sprint
        target.X=target.X-f.X*back-u.X*down
        target.Y=target.Y-f.Y*back-u.Y*down
        target.Z=target.Z-f.Z*back-u.Z*down
    end
    local q=reference.Rotation
    assert(math.abs(q.X*q.X+q.Y*q.Y+q.Z*q.Z+q.W*q.W-1)<.001,'invalid weapon reference rotation')
    local pitch,yaw=math.rad(state.view.Pitch)*.5,math.rad(state.view.Yaw)*.5
    local sp,cp,sy,cy=math.sin(pitch),math.cos(pitch),math.sin(yaw),math.cos(yaw)
    local view={X=sp*sy,Y=-sp*cy,Z=cp*sy,W=cp*cy}
    if aim and aim<1 and state.aim_point then
        local point=state.aim_point
        local x,y,z=point.X-target.X,point.Y-target.Y,point.Z-target.Z
        if x*f.X+y*f.Y+z*f.Z>1 then
            local pitch,yaw=math.atan(z,math.sqrt(x*x+y*y))*.5,math.atan(y,x)*.5
            local sp,cp,sy,cy=math.sin(pitch),math.cos(pitch),math.sin(yaw),math.cos(yaw)
            local toward={Rotation={X=sp*sy,Y=-sp*cy,Z=cp*sy,W=cp*cy},Translation={X=0,Y=0,Z=0}}
            -- Fade convergence out as the actual scope aligns; recoil is added below, unchanged.
            view=blend_reference(toward,{Rotation=view,Translation={X=0,Y=0,Z=0}},aim).Rotation
        end
    end
    if grip_turn then view=multiply(view,grip_turn) end
    local orientation=placement.orientation(gun) or multiply(view,{X=-q.X,Y=-q.Y,Z=-q.Z,W=q.W})
    local offset=rotate(orientation,reference.Translation)
    if reload>0 or switching>0 or sprint>0 then
        local pitch,roll=math.rad(18*reload+30*switching+25*sprint)*.5,math.rad(35*reload+15*switching+8*sprint)*.5
        orientation=multiply(orientation,multiply({X=0,Y=math.sin(pitch),Z=0,W=math.cos(pitch)},
            {X=-math.sin(roll),Y=0,Z=0,W=math.cos(roll)}))
    end
    local result={Rotation=orientation,Translation={X=target.X-offset.X,Y=target.Y-offset.Y,Z=target.Z-offset.Z},Scale3D={X=1,Y=1,Z=1}}
    if same(state.recoil_gun,gun) then
        local recoil=rotate(result.Rotation,state.recoil.Translation)
        result.Translation.X=result.Translation.X+recoil.X
        result.Translation.Y=result.Translation.Y+recoil.Y
        result.Translation.Z=result.Translation.Z+recoil.Z
        result.Rotation=multiply(result.Rotation,state.recoil.Rotation)
    end
    for field,axes in pairs({Rotation={'X','Y','Z','W'},Translation={'X','Y','Z'},Scale3D={'X','Y','Z'}}) do
        for _,axis in ipairs(axes) do output[field][axis]=result[field][axis] end
    end
    state.pose_writes=(state.pose_writes or 0)+1
    return true
end
function M.status()
    if not state then return '' end
    local gun=holding()
    return '|menu='..tostring(state.pawn.InputMode)..'|gun='..(valid(gun) and gun:GetFName():ToString() or 'none')
        ..'|pointer='..tostring(state.pointer.WidgetInteraction:IsOverHitTestVisibleWidget())
        ..'|crouch='..tostring(state.pawn:IsCrouching())..'|sprint='..tostring(state.pawn:IsSprinting())
        ..'|sprint_lower='..tostring(state.sprint_amount or 0)..'|sprint_blocked='..tostring(state.sprint_blocked or false)
        ..'|sprint_aim_blocked='..tostring(state.sprint_aim_blocked or false)
        ..'|slide='..tostring(state.pawn:GetIsSliding())
        ..'|slides_started='..tostring(state.slides_started or 0)
        ..'|pose_writes='..tostring(state.pose_writes or 0)
        ..'|recoil_degrees='..tostring(state.recoil_degrees or 0)..'|recoil_peak='..tostring(state.recoil_peak or 0)
        ..'|aim_mode='..(state.zoom_mode and 'zoom' or 'scope')
        ..'|ads_blend='..tostring(state.ads_amount or 0)..'|hands_hidden='..tostring(state.hands_hidden or false)
        ..'|support='..tostring(valid(gun) and valid(gun.ForeGripComponent) and gun.ForeGripComponent:IsInteracting() or false)
        ..'|fire_mode='..tostring(valid(gun) and gun:GetCurrentFiringMode() or 'none')
        ..'|crouch_requested='..tostring(state.crouched or false)
        ..'|inventory='..state.inventory.message
        ..'|interaction='..tostring(state.inventory.interaction or 'ready')
        ..'|reload_pending='..tostring(state.reload_deadline~=nil)
        ..'|bolt_pending='..tostring(state.bolt_deadline~=nil)
        ..'|bolts_cycled='..tostring(state.bolts_cycled or 0)
        ..'|reload_result='..tostring(state.reload_result or 'ready')
        ..'|reloads_completed='..tostring(state.reloads_completed or 0)
        ..'|reload_last_seconds='..tostring(state.reload_last_seconds or 0)
        ..'|item_action='..state.action.message
        ..'|utility_grab_writes='..tostring(state.utility_grab_writes or 0)
        ..'|item='..(valid(inventory.held(state.right)) and inventory.held(state.right):GetFName():ToString() or 'none')
        ..placement.status()
end
return M
