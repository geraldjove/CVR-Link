package.loaded.FlatMenu={bind=function() end,stop=function() end,status=function() return '' end,take_close=function() return false end,update=function() return false end}
local count,id=0,0
local unloaded=false
local real_clock,now=os.clock,0
os.clock=function() return now end
local function check(value,label) assert(value,label); count=count+1 end
local function object(values)
    id=id+1; local address=id
    values.IsValid=function(self) assert(not unloaded,'old control object touched after world unload'); return not self.invalid end
    values.GetAddress=function() return address end
    values.GetFName=function() return {ToString=function() return 'MockGun' end} end
    values.IsA=function() return false end
    return values
end
local function component()
    return object({RelativeLocation={X=1,Y=2,Z=3},RelativeRotation={Pitch=4,Yaw=5,Roll=6},
        tick=true,bUseWithoutTracking=false,bDisableLowLatencyUpdate=false,PendingTrackingMode=0,
        bReplicateWithoutTracking=true,PlayerIndex=0,CurrentTrackingStatus=2,ControllerNetUpdateRate=100,
        ReplicatedControllerTransform={Position={}},
        Server_SendControllerTransform=function(self,packet)
            -- 3.0.1 uses the outer table for nested Position, then leaves the
            -- nested table on top while copying the following scalar fields.
            self.packet={Position={X=packet.X or 0,Y=packet.Y or 0,Z=packet.Z or 0},
                YawPitchINT=packet.Position.YawPitchINT or 0,RollSHORT=packet.Position.RollSHORT or 0}
            self.sends=(self.sends or 0)+1
        end,
        IsComponentTickEnabled=function(self) return self.tick end,
        SetComponentTickEnabled=function(self,value) self.tick=value end,
        SetTrackingMode=function(self,value) self.PendingTrackingMode=value end,
        K2_SetWorldLocationAndRotation=function(self,p,r) self.position,self.rotation=p,r end,
        K2_SetRelativeLocationAndRotation=function(self,p,r) self.RelativeLocation,self.RelativeRotation=p,r end})
end
local keys,held,left_held,over_ui,wheel={},nil,nil,false,0
local presses,releases,trigger,reloads,crouches,uncrouches,mode_changes=0,0,0,0,0,0,0
local crouched_while_sprinting=false
local crouch_position=0
local ammo_available=true
local native_ammo=require('Ammo')
package.loaded.Ammo={
    plan=function(_,gun) return ammo_available and {gun=gun} or nil,ammo_available and 'reloading' or 'no-chest-magazine' end,
    complete=function(plan) plan.gun:ReloadWeapon(); return true,'used-chest-magazine' end,
    is_station=native_ammo.is_station,refill=native_ammo.refill,
}
local right,left=component(),component()
right.OnTriggerAxisChanged=function(_,value) trigger=value end
right.OnGripButtonPressed=function() right.grabs=(right.grabs or 0)+1 end
right.OnGripButtonReleased=function() held=nil end
right.GetCurrentInteraction=function() return {InteractionComponent={Get=function() return held and held.PrimGripComponent end}} end
right.TryBeginInteractWith=function(_,button,candidate)
    assert(button==0); right.candidate=candidate; right.grabs=(right.grabs or 0)+1
    held=candidate:GetOwner(); return true
end
local pointer=object({RootComponent=component(),bIsEnabled=false,
    LaserMesh=object({bHiddenInGame=false,SetHiddenInGame=function(self,value) self.bHiddenInGame=value end}),
    StaticMesh=object({bVisible=true,SetVisibility=function(self,value) self.bVisible=value end}),
    WidgetInteraction=object({IsOverHitTestVisibleWidget=function() return over_ui end}),
    Enable=function(self) self.bIsEnabled=true end,Disable=function(self) self.bIsEnabled=false end,
    PressPointerKey=function(_,key) assert(key.KeyName=='LeftMouseButton'); presses=presses+1 end,
    ReleasePointerKey=function() releases=releases+1 end,
    ScrollWheel=function(_,value) pointer_scroll=value end})
local camera=object({FieldOfView=90,SetFieldOfView=function(self,value) self.FieldOfView=value end,
    K2_SetWorldRotation=function(self,value) self.render_rotation=value; self.render_writes=(self.render_writes or 0)+1 end,
    K2_GetComponentLocation=function() return {X=0,Y=0,Z=170} end,
    GetForwardVector=function() return {X=1,Y=0,Z=0} end,
    GetRightVector=function() return {X=0,Y=1,Z=0} end,
    GetUpVector=function() return {X=0,Y=0,Z=1} end})
local pawn=object({RightMotionController=right,LeftMotionController=left,RightUIInteractionActor=pointer,
    PlayerCamera=camera,InputMode=0,
    GetHandHoldingGun=function(_,is_right) if is_right then return held and not held.nongun and held or nil else return left_held end end,
    ShowMenuUI=function(self,hand,anim) assert(hand and anim=='None'); self.InputMode=1 end,
    HideMenuUI=function(self) self.InputMode=0 end,
    IsSprinting=function(self) return self.sprinting or false end,
    IsCrouching=function(self) return self.crouching or false end,
    GetIsSliding=function(self) return self.sliding or false end,
    SetSprint=function(self,value,delay) assert(not delay); self.sprinting=value end,
    OnCrouch=function(self) crouch_position=0; crouches=crouches+1; self.crouching=true end,
    OnUncrouch=function(self) crouch_position=.4; uncrouches=uncrouches+1; self.crouching=false end})
pawn.CharacterMovement=object({Velocity={X=0,Y=0,Z=0},MaxWalkSpeed=420,
    IsMovingOnGround=function(self) return not self.airborne and not pawn.sliding end,
    SetMovementMode=function(_,mode,custom) assert(mode==6 and custom==3); pawn.sliding=true end})
pawn.UncrouchCurve=object({Stop=function() end})
pawn.CrouchCurve=object({
    Play=function() crouches=crouches+1; crouched_while_sprinting=pawn.sprinting; pawn.crouching=true end,
    Reverse=function() uncrouches=uncrouches+1; pawn.crouching=false end,
    PlayFromStart=function() crouch_position=0; error('crouch must resume at its current height') end,
    ReverseFromEnd=function() crouch_position=.4; error('stand must reverse from its current height') end})
pawn.Mesh=object({bVisible=true,SetVisibility=function(self,value,propagate) assert(not propagate); self.bVisible=value end,
    K2_GetComponentLocation=function() return {X=0,Y=0,Z=0} end})
local function gun(owner,x)
    local result=object({PrimGripComponent=object({}),bIsPhysicalInteractible=true,GunData={bBoltAction=false},Category={ToString=function() return 'Carbine' end},GetOwner=function() return owner end,
        GetCurrentClip=function(self) return self.clip end,
        GetInstigator=function() return nil end,K2_GetActorLocation=function() return {X=x,Y=0,Z=170} end,
        GetTransform=function() return {Translation={X=x,Y=0,Z=170},Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}} end,
        GetActorAttachingTo=function() return nil end,
        ReloadWeapon=function() reloads=reloads+1 end,
        ChangeFiringMode=function() mode_changes=mode_changes+1 end,
        GetCurrentFiringMode=function() return 0 end,
        SetPancakeAimingDownSight=function(self,value) self.ads=value end})
    result.PrimGripComponent.GetOwner=function() return result end
    result.PrimGripComponent.GetInteractable=function() return result end
    result.PrimGripComponent.K2_GetComponentLocation=result.K2_GetActorLocation
    result.PrimGripComponent.K2_GetComponentToWorld=function() return result:GetTransform() end
    result.PrimGripComponent.IsInteracting=function() return held==result end
    result.PrimGripComponent.CanBeginInteraction=function() return owner==pawn end
    result.PrimGripComponent.DefaultInteractionButton=0
    return result
end
local rifle=gun(pawn,50)
rifle.ForeGripComponent=object({K2_GetComponentLocation=function() return {X=55,Y=16,Z=148} end,
    IsInteracting=function() return left_held~=nil end})
left.TryBeginInteractWith=function(_,button,grip) assert(button==0 and grip==rifle.ForeGripComponent); left_held=rifle end
left.OnGripButtonReleased=function() left_held=nil end
left.GetCurrentInteraction=function() return {InteractionComponent={Get=function() return left_held and left_held.ForeGripComponent end}} end
rifle.ForeGripComponent.GetOwner=function() return rifle end
rifle.K2_SetActorLocationAndRotation=function() return true end
local function transform(p)
    return {Translation=p,Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}}
end
local function hand_transform(hand)
    local t=transform(hand.position)
    local r=hand.rotation
    local sp,cp=math.sin(math.rad(r.Pitch)/2),math.cos(math.rad(r.Pitch)/2)
    local sy,cy=math.sin(math.rad(r.Yaw)/2),math.cos(math.rad(r.Yaw)/2)
    local sr,cr=math.sin(math.rad(r.Roll)/2),math.cos(math.rad(r.Roll)/2)
    t.Rotation={X=cr*sp*sy-sr*cp*cy,Y=-cr*sp*cy-sr*cp*sy,Z=cr*cp*sy-sr*sp*cy,W=cr*cp*cy+sr*sp*sy}
    return t
end
right.K2_GetComponentToWorld=function() return hand_transform(right) end
left.K2_GetComponentToWorld=function() return hand_transform(left) end
pawn.GetTransform=function() return transform({X=0,Y=0,Z=0}) end
pawn.GetParentActor=function() return nil end
rifle.GetTransform=function() return transform({X=100,Y=0,Z=170}) end
rifle.GetGunFiringTransform=function() return transform({X=177,Y=0,Z=170}) end
rifle.DefaultMuzzleRelativeTransform=transform({X=77,Y=0,Z=0})
rifle.DefaultSightRelativeTransform=transform({X=4,Y=0,Z=8})
rifle.GetPancakeSightRelativeTransform=function() return transform({X=4,Y=0,Z=8}) end
-- Identity-rotation transform fixture isolates muzzle/sight offsets and ownership.
local pc=object({IsInputKeyDown=function(_,key) return keys[key.KeyName] or false end,
    GetInputAnalogKeyState=function() return wheel end})
FName=function(value) return value end
local center_hit,center_traces=nil,0
local native_hand_poses
StaticFindObject=function(value)
    assert(value~='/Script/ZomboyVR.Default__ZomboyInteractionLibrary',
        'FInteraction inputs crash UE4SS 3.0.1 while copying weak object properties')
    if value=='/Script/Engine.Default__KismetSystemLibrary' then return {SphereTraceSingle=function() return false end,LineTraceSingle=function(_,_,start,finish,channel,complex,ignore,debug,hit)
        center_traces=center_traces+1
        if center_hit then
            assert(start.X==0 and start.Y==0 and start.Z==170 and finish.X==100000 and channel==2 and complex)
            assert(#ignore==2 and ignore[1]==pawn and ignore[2]==rifle)
            hit.ImpactPoint=center_hit
            return true
        end
        return false
    end} end
    return value
end
local own,foreign,far=gun(pawn,75),gun(object({}),20),gun(pawn,500)
own.DefaultMuzzleRelativeTransform=rifle.DefaultMuzzleRelativeTransform
own.K2_SetActorLocationAndRotation=rifle.K2_SetActorLocationAndRotation
local sight=object({GetOwner=function() return rifle end,
    GetSightTransform=function() return transform({X=104,Y=0,Z=178}) end})
local function indicator(grip,usage,score)
    return object({HandUsage=usage,GetOwner=function() return grip:GetOwner() end,
        GetRegisteredInteractionComponent=function() return grip end,
        GetHandPosePriorityScore=function() return score end,
        GetTargetControllerTransformWorldSpace=function(_,is_right,current)
            assert(current.Rotation and current.Translation and current.Scale3D)
            if native_hand_poses then return native_hand_poses(is_right) end
            local missing=transform({X=0,Y=0,Z=0}); missing.Scale3D.X=0; return missing
        end})
end
local primary_indicator=indicator(rifle.PrimGripComponent,2,1)
local support_indicator=indicator(rifle.ForeGripComponent,0,1)
local wrong_hand=indicator(rifle.PrimGripComponent,0,100)
wrong_hand.GetTargetControllerTransformWorldSpace=function() error('wrong-hand indicator selected') end
local foreign_indicator=indicator(foreign.PrimGripComponent,2,100)
foreign_indicator.GetTargetControllerTransformWorldSpace=function() error('foreign indicator selected') end
local lower_priority=indicator(rifle.PrimGripComponent,2,0)
lower_priority.GetTargetControllerTransformWorldSpace=function() error('lower priority indicator selected') end
FindAllOf=function(name)
    if name=='ZomboyHandIndicatorComponent' then return {wrong_hand,foreign_indicator,lower_priority,primary_indicator,support_indicator} end
    if name=='ZomboyInteractableHolster' then return {} end
    if name=='ZomboyGunSightAttachmentActor' then return {sight} end
    if name=='ZomboyInteractionComponent' then return {foreign.PrimGripComponent,far.PrimGripComponent,own.PrimGripComponent} end
    assert(name=='ContractorsPrimaryGun_C'); return {foreign,far,own}
end
local controls=dofile('Controls.lua')
local function tick() controls.tick(pawn,pc,camera,{Pitch=0,Yaw=0,Roll=0}) end
local function input(values) keys=values or {}; tick() end
-- Local player setup creates the pointers after the pawn can start ticking.
for _,missing in ipairs({'RightUIInteractionActor','RightMotionController','LeftMotionController'}) do
    local saved=pawn[missing]
    pawn[missing]=nil
    check(controls.start(pawn)==false,'startup waits for missing '..missing)
    check(not right.bUseWithoutTracking and right.PendingTrackingMode==0 and not pointer.bIsEnabled,
        'waiting for '..missing..' leaves controls untouched')
    pawn[missing]=saved
end
pointer.invalid=true
check(controls.start(pawn)==false,'startup waits for an invalid pointer wrapper')
pointer.invalid=false
for _,missing in ipairs({'RootComponent','WidgetInteraction'}) do
    local saved=pointer[missing]
    pointer[missing]=nil
    check(controls.start(pawn)==false,'startup waits for pointer '..missing)
    pointer[missing]=saved
end
check(controls.start(pawn)==true,'startup resumes when all control components are ready')
check(right.tick and left.tick and right.bUseWithoutTracking and left.bUseWithoutTracking
    and right.PendingTrackingMode==0 and left.PendingTrackingMode==0,
    'untracked hands retain controller-driven grips for local and remote players')
check(pointer.bIsEnabled,'existing pointer is enabled')
check(not right.bReplicateWithoutTracking and right.PlayerIndex==-1 and right.CurrentTrackingStatus==0,
    'native tracking cannot replace or broadcast the synthetic pose')
check(not pointer.StaticMesh.bVisible,'decorative pointer rings are hidden without disabling interaction')
input({LeftMouseButton=true})
check(trigger==0 and presses==0,'activation does not fire a mouse button already held')
input()
check(pointer.LaserMesh.bHiddenInGame and pointer.bIsEnabled,'gameplay hides the laser mesh while keeping widget interaction available')
check(right.position.X==35 and right.position.Y==16 and right.position.Z==150,'right hand uses camera-relative placement')
check(pointer.RootComponent.position.X==5 and pointer.RootComponent.position.Y==0,'laser points along camera center')
over_ui=true
input({LeftMouseButton=true})
check(presses==1 and trigger==0,'UI click cannot also fire')
over_ui=false
input()
check(releases==1,'UI release returns to the original pointer after hover leaves')
held=rifle
local output=transform({X=0,Y=0,Z=0})
tick()
check(left_held==rifle,'equipping a rifle automatically takes its native support grip')
check(controls.apply_gun_pose(rifle,output) and output.Translation.X==20 and output.Translation.Y==16 and output.Translation.Z==156,'hip pose holds the primary grip at a natural distance')
for _,length in ipairs({16,49,85}) do
    rifle.DefaultMuzzleRelativeTransform.Translation.X=length
    controls.apply_gun_pose(rifle,output)
    check(math.abs(output.Translation.X-20)<.00001,'rifle barrel length does not extend the hip-fire grip: '..length)
end
rifle.DefaultMuzzleRelativeTransform.Translation.X=77
check(not controls.apply_gun_pose(foreign,output),'weapon pose excludes other players and unheld guns')
input({LeftMouseButton=true})
check(trigger==1,'mouse press drives stock trigger')
input({LeftMouseButton=true,Tab=true})
check(pawn.InputMode==1 and trigger==0,'opening menu releases a held trigger')
check(not pointer.LaserMesh.bHiddenInGame,'menu restores its visible laser')
check(not controls.wants_look(pawn),'open menu freezes camera look')
controls.tick(pawn,pc,camera,{Pitch=0,Yaw=0,Roll=0},12,-8)
check(pointer.RootComponent.rotation.Yaw==12 and pointer.RootComponent.rotation.Pitch==-8,'menu mouse motion steers pointer in both axes')
input({R=true,E=true,G=true,B=true,RightMouseButton=true,LeftShift=true,LeftControl=true})
check(reloads==0 and held==rifle and not rifle.ads and not pawn.sprinting and crouches==0,'menu blocks weapon and movement actions')
input(); input({Tab=true}); input()
check(pawn.InputMode==0,'Tab closes the menu')
check(controls.wants_look(pawn) and pointer.RootComponent.rotation.Yaw==0,'closing menu restores centered pointer and camera input')
-- Stationary loadout/respawn UI is separate from the pause menu.
pawn.InputMode=2; input({Tab=true})
check(pawn.InputMode==2 and not controls.wants_look(pawn),'Tab cannot cover a stationary screen with the pause menu')
input(); input({F9=true}); input()
check(controls.wants_look(pawn) and controls.ui_active(pawn),'F9 permits looking toward an off-screen menu without leaving its input block')
local before_presses=presses
over_ui=true; input({LeftMouseButton=true,R=true,G=true,One=true,LeftShift=true,W=true})
check(trigger==0 and held==rifle and reloads==0 and presses==before_presses and not pawn.sprinting,
    'looking around a stationary menu cannot fire, reload, drop, swap, sprint, or click through it')
over_ui=false; input(); input({F9=true}); input()
controls.tick(pawn,pc,camera,{Pitch=0,Yaw=0,Roll=0},10,6)
check(not controls.wants_look(pawn) and pointer.RootComponent.rotation.Yaw==10,'F9 returns mouse motion to the pointer')
pawn.StationaryUI=object({bIsShowing=true}); pawn.InputMode=1; input({Tab=true}); input()
check(pawn.InputMode==0 and not controls.wants_look(pawn),'closing an overlapping pause menu keeps the visible loadout pointer')
input({Tab=true}); input()
check(pawn.InputMode==0 and controls.pointer_mode(pawn),'visible stationary UI blocks reopening the pause menu even with input mode zero')
pawn.StationaryUI.bIsShowing=false; pawn.bForcedUIInput=true; input()
check(not controls.wants_look(pawn) and controls.ui_active(pawn),'forced UI gets pointer control independently of input mode')
pawn.bForcedUIInput=false; input()
check(controls.wants_look(pawn) and not controls.ui_active(pawn),'closing the last UI restores mouse look automatically')
input({LeftMouseButton=true}); input({F9=true,LeftMouseButton=true})
check(trigger==0 and not controls.wants_look(pawn),'manual pointer mode releases a held trigger and freezes camera look')
input({F9=true,LeftMouseButton=true})
check(controls.pointer_mode(pawn),'holding F9 cannot repeatedly toggle pointer mode')
input(); input({F9=true}); input()
check(controls.wants_look(pawn) and trigger==0,'F9 returns to gameplay without queuing a shot')
controls.configure({F9='F10'}); input({F9=true})
check(controls.wants_look(pawn),'old pointer key does nothing after rebinding')
input(); input({F10=true})
check(not controls.wants_look(pawn),'configured pointer key takes effect')
pawn.InputMode=1; input(); pawn.InputMode=0; input(); controls.configure()
check(controls.wants_look(pawn),'menu transitions reset a manual pointer override')
input({R=true}); tick()
check(reloads==0,'R starts a delay instead of instantly refilling')
input({LeftMouseButton=true}); check(trigger==0,'reload blocks firing')
now=.75; tick(); controls.apply_gun_pose(rifle,output)
check(output.Translation.Z<156 and math.abs(output.Rotation.X)>.1,'reload lowers and tilts the gun halfway through the delay')
now=1; input(); input({R=true}); now=1.49; tick()
check(reloads==0,'repeat R cannot shorten the reload delay')
now=1.5; tick()
check(reloads==1,'reload completes at 1.5 seconds without restarting on repeated R')
controls.apply_gun_pose(rifle,output)
check(output.Translation.Z==156 and output.Rotation.X==0,'reload returns to the normal pose on completion')
input(); input({RightMouseButton=true})
check(rifle.ads==true,'right mouse enables native ADS')
controls.apply_gun_pose(rifle,output)
check(output.Translation.Y==16,'ADS starts from hip without a cut')
now=now+.1; tick(); controls.apply_gun_pose(rifle,output)
check(output.Translation.Y>0 and output.Translation.Y<16,'ADS travels through an intermediate pose')
check(camera.FieldOfView>72 and camera.FieldOfView<80,'iron ADS zoom follows the smooth pose transition')
local entering=output.Translation.Y
input(); controls.apply_gun_pose(rifle,output)
check(output.Translation.Y==entering,'releasing ADS midway preserves the current pose')
now=now+.1; tick(); controls.apply_gun_pose(rifle,output)
check(output.Translation.Y>entering and output.Translation.Y<16,'ADS release eases back toward hip')
input({RightMouseButton=true}); now=now+.201; tick()
check(controls.apply_gun_pose(rifle,output) and output.Translation.X==14 and output.Translation.Y==0 and output.Translation.Z==162,'ADS places the native sight reference in front of the camera')
input()
check(rifle.ads==false,'right mouse release clears ADS')
input({F6=true}); input(); input({RightMouseButton=true})
check(camera.FieldOfView==72,'retired F6 leaves the short iron ADS zoom active')
now=now+.1; tick(); check(camera.FieldOfView==72,'retired F6 cannot change iron ADS FOV')
now=now+.101; tick()
check(camera.FieldOfView==72 and rifle.ads,'iron ADS has a short FOV zoom and retired F6 stays inactive')
controls.apply_gun_pose(rifle,output)
check(output.Translation.X==14 and output.Translation.Y==0,'retired F6 preserves the sight-aligned ADS anchor')
input(); input({F6=true}); input()
check(camera.FieldOfView==72,'releasing iron ADS does not snap FOV')
now=now+.1;tick();check(camera.FieldOfView>72 and camera.FieldOfView<80,'iron ADS FOV eases out')
now=now+.101;tick();check(camera.FieldOfView==80,'ADS release restores the configured FOV')
controls.configure(nil,120); tick()
check(camera.FieldOfView==120,'saved FOV applies without restarting controls')
input({F6=true}); input(); input({RightMouseButton=true}); now=now+.201; tick()
check(camera.FieldOfView==108 and rifle.ads,'iron ADS zoom follows the selected FOV baseline')
input(); now=now+.201; tick()
check(camera.FieldOfView==120,'ADS release keeps the selected FOV')
input({F6=true}); input(); controls.configure(); tick()
local original=transform({X=1000,Y=400,Z=200})
local kicked=transform({X=998,Y=400,Z=200})
kicked.Rotation={X=0,Y=-math.sin(math.rad(3)),Z=0,W=math.cos(math.rad(3))}
check(controls.capture_recoil(rifle,original,kicked),'native recoil is captured for the owned held gun')
controls.apply_gun_pose(rifle,output)
check(math.abs(output.Rotation.Y-kicked.Rotation.Y)<.00001 and output.Translation.X==18,'native recoil rotation and displacement survive camera anchoring')
check(not controls.capture_recoil(foreign,original,kicked),'recoil from another gun is excluded')
local native_pass=transform({X=-500,Y=300,Z=900})
check(controls.apply_local_grab(rifle,native_pass),'native gun update uses the local first-person pose')
check(native_pass.Translation.X==output.Translation.X and native_pass.Translation.Y==output.Translation.Y
    and native_pass.Translation.Z==output.Translation.Z and native_pass.Rotation.Y==output.Rotation.Y,
    'native and character pose passes agree without losing or doubling recoil')
check(not controls.apply_local_grab(foreign,native_pass),'local gun override cannot change another player weapon')
-- Recoil must keep the eye on the sight axis at the same distance, while
-- the barrel still climbs by the full native angle. Test a burst and recovery.
input({RightMouseButton=true}); now=now+.201; tick()
local function rotated(q,p)
    return {X=(1-2*(q.Y*q.Y+q.Z*q.Z))*p.X+2*(q.X*q.Y-q.W*q.Z)*p.Y+2*(q.X*q.Z+q.W*q.Y)*p.Z,
        Y=2*(q.X*q.Y+q.W*q.Z)*p.X+(1-2*(q.X*q.X+q.Z*q.Z))*p.Y+2*(q.Y*q.Z-q.W*q.X)*p.Z,
        Z=2*(q.X*q.Z-q.W*q.Y)*p.X+2*(q.Y*q.Z+q.W*q.X)*p.Y+(1-2*(q.X*q.X+q.Y*q.Y))*p.Z}
end
for _,degrees in ipairs({0,6,20,6,0}) do
    local burst=transform({X=990,Y=403,Z=202})
    burst.Rotation={X=0,Y=-math.sin(math.rad(degrees)/2),Z=0,W=math.cos(math.rad(degrees)/2)}
    controls.capture_recoil(rifle,original,burst)
    controls.apply_gun_pose(rifle,output)
    local lens=rotated(output.Rotation,{X=4,Y=0,Z=8})
    local sight_ray=rotated(output.Rotation,{X=18,Y=0,Z=0})
    check(math.abs(output.Translation.X+lens.X-sight_ray.X)<.00001
        and math.abs(output.Translation.Y+lens.Y-sight_ray.Y)<.00001
        and math.abs(output.Translation.Z+lens.Z-sight_ray.Z-170)<.00001,
        'ADS keeps the eye on the sight axis at 18 cm during recoil '..degrees)
    check(math.abs(output.Rotation.Y-burst.Rotation.Y)<.00001
        and math.abs(output.Rotation.W-burst.Rotation.W)<.00001,
        'ADS preserves native recoil angle and recovery '..degrees)
    check(math.abs(camera.render_rotation.Pitch-degrees)<.00001 and camera.render_rotation.Roll==0,
        'ADS camera follows sight recoil and recovery with a level horizon '..degrees)
    local cam_pitch=math.rad(camera.render_rotation.Pitch)
    check(math.abs(math.cos(cam_pitch)-(lens.X+output.Translation.X)/18)<.00001
        and math.abs(math.sin(cam_pitch)-(lens.Z+output.Translation.Z-170)/18)<.00001,
        'recoiling sight stays centered in the ADS camera '..degrees)
end
controls.apply_local_grab(rifle,native_pass)
check(math.abs(native_pass.Translation.X-output.Translation.X)<.00001
    and math.abs(native_pass.Translation.Z-output.Translation.Z)<.00001,
    'native grab pass keeps the same stable ADS eye point')
-- Simulate the real camera basis changing after render rotation. Native grab
-- passes must reuse the un-recoiled ADS frame, including pitch AND yaw.
local saved_forward,saved_right,saved_up=camera.GetForwardVector,camera.GetRightVector,camera.GetUpVector
local function render_quat() return hand_transform({position={X=0,Y=0,Z=170},rotation=camera.render_rotation}).Rotation end
camera.GetForwardVector=function() return rotated(render_quat(),{X=1,Y=0,Z=0}) end
camera.GetRightVector=function() return rotated(render_quat(),{X=0,Y=1,Z=0}) end
camera.GetUpVector=function() return rotated(render_quat(),{X=0,Y=0,Z=1}) end
for _,view in ipairs({{Pitch=0,Yaw=0,Roll=0},{Pitch=35,Yaw=75,Roll=0},{Pitch=-45,Yaw=-120,Roll=0}}) do
    camera.render_rotation=view -- main.lua restores mouse rotation before each tick.
    local burst=transform({X=990,Y=403,Z=202})
    burst.Rotation=hand_transform({position=burst.Translation,rotation={Pitch=9,Yaw=4,Roll=2}}).Rotation
    controls.capture_recoil(rifle,original,burst)
    controls.tick(pawn,pc,camera,view)
    controls.apply_gun_pose(rifle,output)
    local lens=rotated(output.Rotation,{X=4,Y=0,Z=8})
    local forward=camera:GetForwardVector()
    check(math.abs(output.Translation.X+lens.X-18*forward.X)<.00001
        and math.abs(output.Translation.Y+lens.Y-18*forward.Y)<.00001
        and math.abs(output.Translation.Z+lens.Z-170-18*forward.Z)<.00001
        and camera.render_rotation.Roll==0,'ADS sight remains centered with combined native recoil and mouse rotation')
    for pass=1,3 do
        controls.apply_local_grab(rifle,native_pass)
        local stable=true
        for _,axis in ipairs({'X','Y','Z'}) do
            stable=stable and math.abs(native_pass.Translation[axis]-output.Translation[axis])<.00001
        end
        check(stable,'repeated native pass does not feed rendered ADS recoil into placement '..pass)
    end
end
local menu_camera_writes=camera.render_writes
pawn.InputMode=1; controls.apply_local_grab(rifle,native_pass)
check(camera.render_writes==menu_camera_writes,'opening a menu blocks late native ADS camera writes')
pawn.InputMode=0
check(controls.status():find('scope_state=unavailable',1,true),'scope diagnostic tolerates a sight without stock zoom fields')
rifle.GetIsAimDownSight=function() return true end
sight.bEnablingScop=false
check(controls.status():find('native_ads=true|scope_enabled=false|scope_capture=false',1,true),
    'scope diagnostic distinguishes native aim from a disabled scope without changing it')
camera.GetForwardVector,camera.GetRightVector,camera.GetUpVector=saved_forward,saved_right,saved_up
input(); now=now+.201; tick(); controls.capture_recoil(rifle,original,kicked)
controls.apply_gun_pose(rifle,output)
check(output.Translation.X==18,'leaving ADS restores full native hip kickback')
local hip_camera_writes=camera.render_writes
controls.apply_local_grab(rifle,native_pass)
check(camera.render_writes==hip_camera_writes,'hip recoil does not turn the camera')
-- Camera-only damping; native gun pose and rifle follow must stay unchanged.
rifle.Category={ToString=function() return 'Pistol' end}
input({RightMouseButton=true}); now=now+.201; tick()
for _,degrees in ipairs({6,20,0}) do
    local burst=transform({X=990,Y=403,Z=202})
    burst.Rotation={X=0,Y=-math.sin(math.rad(degrees)/2),Z=0,W=math.cos(math.rad(degrees)/2)}
    controls.capture_recoil(rifle,original,burst)
    controls.apply_gun_pose(rifle,output)
    check(math.abs(camera.render_rotation.Pitch-degrees*.35)<.05 and camera.render_rotation.Roll==0,
        'pistol camera follows about 35 percent of kick and recovery '..degrees)
    check(math.abs(output.Rotation.Y-burst.Rotation.Y)<.00001 and math.abs(output.Rotation.W-burst.Rotation.W)<.00001,
        'pistol keeps full native gun recoil '..degrees)
    local pitch=camera.render_rotation.Pitch
    controls.apply_local_grab(rifle,native_pass)
    check(math.abs(camera.render_rotation.Pitch-pitch)<.00001,
        'pistol follow does not accumulate across native pose passes '..degrees)
end
rifle.Category={ToString=function() return 'Carbine' end}
controls.capture_recoil(rifle,original,kicked);controls.apply_gun_pose(rifle,output)
check(math.abs(camera.render_rotation.Pitch-6)<.00001,'rifle resumes full camera follow with no pistol damping retained')
input();now=now+.201;tick();controls.apply_gun_pose(rifle,output)


-- A pistol's authored wrist angle differs from its barrel angle. Use each
-- active native hand pose and send the base hold, leaving recoil to the gun.
native_hand_poses=function(is_right)
    local result=transform({X=rifle:GetTransform().Translation.X+8,Y=is_right and 2 or 4,Z=174})
    result.Rotation={X=0,Y=-math.sin(math.rad(30)),Z=0,W=math.cos(math.rad(30))}
    return result
end
tick()
check(math.abs(right.rotation.Pitch-60)<.00001 and math.abs(left.rotation.Pitch-60)<.00001,
    'both controller angles use the authored grip instead of the level camera angle')
check(math.abs(right.position.X-28)<.00001 and math.abs(right.position.Y-18)<.00001
    and math.abs(right.position.Z-160)<.00001,'right grip matches the base gun pose without adding its captured recoil')
check(math.abs(left.position.Y-20)<.00001,'support hand uses its own native controller reference')
for _,pitch in ipairs({-85,85}) do
    controls.tick(pawn,pc,camera,{Pitch=pitch,Yaw=0,Roll=0})
    -- Compare forward vectors because rotations past vertical have another Euler representation.
    local p,y=math.rad(right.rotation.Pitch),math.rad(right.rotation.Yaw)
    local wanted=math.rad(pitch+60)
    check(math.abs(math.cos(p)*math.cos(y)-math.cos(wanted))<.00001
        and math.abs(math.sin(p)-math.sin(wanted))<.00001,'native wrist correction keeps full view pitch '..pitch)
end
pawn.InputMode=1; tick()
check(right.rotation.Pitch==0,'menus retain their normal controller and pointer placement')
pawn.InputMode=0
primary_indicator.invalid=true; lower_priority.invalid=true; tick()
check(right.position.X==20 and right.rotation.Pitch==0,'destroyed indicators do not receive native pose calls')
primary_indicator.invalid=false; lower_priority.invalid=false
native_hand_poses=function() return transform({X=5000,Y=0,Z=0}) end; tick()
check(right.position.X==20 and right.rotation.Pitch==0,'an unusable native pose cannot fling the controller away from the held gun')
native_hand_poses=nil; tick()
check(right.position.X==20 and right.rotation.Pitch==0,'missing native hand data keeps the existing safe placement')
controls.capture_recoil(rifle,original,original)
-- Replaces convergence expectations only in the generated stable hip candidate.
local baseline=transform({X=0,Y=0,Z=0})
controls.apply_gun_pose(rifle,baseline)
local trace_count=center_traces
for _,depth in ipairs({200,40,10000,40,1000}) do
    center_hit={X=depth,Y=0,Z=170};tick();controls.apply_gun_pose(rifle,output)
    local unchanged=true
    for field,axes in pairs({Translation={'X','Y','Z'},Rotation={'X','Y','Z','W'}}) do
        for _,axis in ipairs(axes) do unchanged=unchanged and math.abs(output[field][axis]-baseline[field][axis])<.00001 end
    end
    check(unchanged,'crossing near/far targets cannot turn or retract the hip gun '..depth)
end
check(center_traces==trace_count,'stable hip pose does not query surfaces or concealed targets')
check(output.Translation.X==20 and output.Translation.Y==16 and output.Translation.Z==156,
    'rifle grip is fifteen cm closer with the same vertical and side placement')
check(output.Rotation.Y==0 and output.Rotation.Z==0,
    'resting hip barrel stays parallel to the mouse camera')
-- Barrel starts 16 cm right and 14 cm below the fixed center ray in this fixture.
check(output.Translation.Y==16 and output.Translation.Z-170==-14,
    'close hip shots retain the documented camera-to-barrel offset')
controls.capture_recoil(rifle,original,kicked);controls.apply_gun_pose(rifle,output)
check(output.Translation.X==18 and math.abs(output.Rotation.Y-kicked.Rotation.Y)<.00001,
    'stable hip keeps native angular recoil and kickback')
controls.apply_local_grab(rifle,native_pass)
check(math.abs(native_pass.Translation.X-output.Translation.X)<.00001
    and math.abs(native_pass.Rotation.Y-output.Rotation.Y)<.00001,'late native hip pass reuses the same recoil and placement')
controls.capture_recoil(rifle,original,original)
input({RightMouseButton=true});now=now+.201;tick();controls.apply_gun_pose(rifle,output)
check(math.abs(output.Translation.X-14)<.00001 and math.abs(output.Translation.Z-162)<.00001
    and math.abs(output.Rotation.Y)<.00001,'stable hip candidate preserves aligned full ADS')
input();now=now+.201;tick();controls.apply_gun_pose(rifle,output)
check(output.Translation.X==20 and output.Translation.Y==16 and output.Translation.Z==156,
    'leaving ADS restores the closer rifle hip pose')
local old_category=rifle.Category
for _,category in ipairs({'Pistol','Shotgun','SMG'}) do
    rifle.Category={ToString=function() return category end}
    controls.apply_gun_pose(rifle,output)
    check(output.Translation.X==35,category..' retains its existing hip distance')
end
rifle.Category=old_category
center_hit=nil;tick()

-- Sprint lowering follows movement, and recovery belongs to the player, not the gun.
now=10
input({LeftShift=true}); controls.apply_gun_pose(rifle,output)
check(not pawn.sprinting and output.Translation.Z==156 and not controls.status():find('sprint_blocked=true',1,true),
    'Shift without forward input cannot request auto-run, lower the gun, or block firing')
input({LeftMouseButton=true})
check(trigger==1,'stationary sprint request does not add a recovery penalty')
pawn.CharacterMovement.Velocity.X=550
input({W=true,LeftShift=true,LeftMouseButton=true})
check(trigger==0 and not rifle.ads,'starting a moving sprint releases an already-held trigger')
now=10.1; tick(); controls.apply_gun_pose(rifle,output)
check(output.Translation.Z<156 and output.Translation.Z>134,'sprint lowers the gun through an intermediate pose')
now=10.2; tick(); controls.apply_gun_pose(rifle,output)
check(math.abs(output.Translation.Z-134)<.00001 and output.Rotation.Y>.1,'running holds the gun lowered and tilted')
input({W=true,LeftShift=true}); input({W=true,LeftShift=true,LeftMouseButton=true})
check(trigger==0,'a fresh shot is blocked while running')
-- Aim waits after sprint, but fresh shots are allowed as soon as sprint stops.
now=11; input({W=true,LeftShift=true,RightMouseButton=true,LeftMouseButton=true})
check(not pawn.sprinting and not rifle.ads and trigger==0,'aim stops sprint without queuing a shot held from sprint')
input({W=true,LeftShift=true,RightMouseButton=true})
input({W=true,LeftShift=true,RightMouseButton=true,LeftMouseButton=true})
check(trigger==1 and not rifle.ads,'a fresh shot fires at the exact sprint-stop time while aim still waits')
now=11.25; tick(); controls.apply_gun_pose(rifle,output)
check(not rifle.ads and trigger==1 and output.Translation.Z>134 and output.Translation.Z<156,
    'gun rises over half a second while firing works and aim still waits')
now=11.299; tick()
check(not rifle.ads and trigger==1 and not pawn.sprinting,'held aim does not restart sprint or unlock aim early')
now=11.3; tick()
check(rifle.ads and trigger==1,'aim begins at 0.3 seconds without interrupting firing')
now=11.5; tick()
check(rifle.ads and trigger==1,'finishing the gun rise does not interrupt firing')
input({RightMouseButton=true}); input({RightMouseButton=true,LeftMouseButton=true})
check(trigger==1,'a fresh shot still works after the gun finishes rising')
input(); now=12; tick()
input({W=true,LeftShift=true}); now=12.2; tick(); input()
now=12.3; input({W=true,LeftShift=true}); now=12.4; tick(); input()
now=12.65; input({RightMouseButton=true,LeftMouseButton=true})
check(not rifle.ads and trigger==1,'restarting sprint restarts only the aim delay')
-- Menus and changing items must not reset the player's recovery deadline.
held=own; input(); input({Tab=true}); input(); input({Tab=true})
now=12.699; input({RightMouseButton=true,LeftMouseButton=true})
check(not own.ads and trigger==1,'menu round trip and replacement gun preserve the aim delay with firing available')
held=rifle; input(); now=13; tick(); controls.apply_gun_pose(rifle,output)
check(math.abs(output.Translation.Z-156)<.00001 and math.abs(output.Rotation.Y)<.00001,
    'sprint recovery restores the default hip position and angle')
input({W=true,LeftShift=true}); now=13.2; tick(); input({F6=true,RightMouseButton=true})
now=13.499; tick()
check(camera.FieldOfView==80 and not rifle.ads,'retired F6 cannot bypass sprint recovery')
input(); input({F6=true}); now=14; input()
pawn.CharacterMovement.Velocity.X=0
input({W=true,S=true,LeftShift=true})
check(not pawn.sprinting,'opposed forward and backward input cannot request auto-run')
input({W=true,LeftShift=true})
check(pawn.sprinting,'Shift plus forward requests native sprint')
input({LeftShift=true})
check(not pawn.sprinting,'releasing forward stops sprint even while Shift stays held')
pawn.sprinting=true -- The game's input tick can start sprint before our bridge sees it.
input({W=true,LeftShift=true})
input({W=true})
check(not pawn.sprinting,'releasing Shift stops sprint even when native input started it first')
pawn.sprinting=true; input({W=true})
check(not pawn.sprinting,'a native sprint reasserted without Shift is stopped by the next bridge tick')
input({W=true,LeftShift=true})
pawn.CharacterMovement.Velocity.X=550
local crouch_started=now
input({W=true,LeftShift=true,LeftControl=true})
check(crouches==1 and crouched_while_sprinting,'sprint remains active when native crouch starts, allowing native slide rules')
check(pawn.sliding,'grounded sprint then crouch enters stock slide mode')
input({W=true,LeftShift=true,C=true}); tick()
check(crouches==1,'crouch aliases do not restart the transition while held')
crouch_position=.05
input()
check(uncrouches==1 and not pawn.sprinting,'releasing crouch and sprint clears both requests')
check(crouch_position==.05,'a short tap reverses at the partial crouch height')
pawn.sliding=false; pawn.CharacterMovement.Velocity.X=0
now=crouch_started+.1; input({LeftControl=true})
check(crouches==1 and not pawn.crouching,'rapid crouch press is blocked during the cooldown')
input(); now=crouch_started+.2; input({C=true})
check(crouches==1,'the alternate crouch key cannot bypass the cooldown')
now=crouch_started+.499; tick()
check(crouches==1,'blocked press stays blocked during the cooldown')
now=crouch_started+.5; tick()
check(crouches==1 and not pawn.crouching,'blocked press cannot cause a delayed crouch at expiry')
input({LeftControl=true,C=true}); input({LeftControl=true})
check(crouches==1,'switching aliases without releasing both cannot queue another crouch')
input(); input({C=true})
check(crouches==2 and pawn.crouching,'a fresh press at the half-second boundary starts crouch')
input()
check(uncrouches==2 and not pawn.crouching,'standing up is immediate during the cooldown')
now=now+.5
input({W=true,LeftShift=true,LeftControl=true})
check(not pawn.sliding,'stationary crouch cannot start a slide')
input(); pawn.CharacterMovement.Velocity.X=550; pawn.CharacterMovement.airborne=true
now=now+.5
input({W=true,LeftShift=true}); input({W=true,LeftShift=true,LeftControl=true})
check(not pawn.sliding,'airborne sprint and crouch cannot start a slide')
input(); pawn.CharacterMovement.airborne=false; pawn.CharacterMovement.Velocity.X=0
input({E=true})
check(held==rifle,'E invokes interaction without releasing a held rifle')
input(); input({B=true}); tick()
check(mode_changes==1,'B changes firing mode once per press')
input(); input({G=true})
check(held==nil,'G releases a held rifle')
input(); input({E=true})
check(held==own and right.grabs==1,'E picks up the aimed nearby gun with an empty hand')
tick(); check(right.grabs==1,'holding E does not repeat the pickup')
input(); input({One=true})
check(right.grabs==1,'empty inventory does not grab an unholstered gun')
input(); held=rifle; input({R=true})
now=now+1.5; tick()
check(reloads==2,'fresh reload press waits another 1.5 seconds')
input(); input({R=true}); input({G=true}); now=now+2; tick()
check(reloads==2,'dropping cancels a pending reload')
held=rifle; input(); input({R=true}); held=own; now=now+2; tick()
check(reloads==2,'changing the held gun cancels a pending reload')
held=rifle; input(); input({R=true}); input({Tab=true}); now=now+2; tick()
check(reloads==2,'opening the menu cancels a pending reload')
input(); input({Tab=true})
local clip=object({}); rifle.clip=clip
rifle.EjectClip=function() error('reload must leave the magazine attached') end
local completed=reloads
input(); input({R=true}); now=now+.75; tick()
check(rifle.clip==clip and reloads==completed,'lowering the weapon leaves its magazine attached')
now=now+.75; tick()
check(rifle.clip==clip and reloads==completed+1,'reload refills the original magazine without creating or ejecting one')
input(); ammo_available=false; completed=reloads; input({R=true}); now=now+2; tick()
check(reloads==completed and controls.status():find('reload_result=no%-chest%-magazine'),
    'R cannot reload without a usable chest magazine')
ammo_available=true; input()
local magazine_plan,magazine_complete=package.loaded.Ammo.plan,package.loaded.Ammo.complete
local shells=0
package.loaded.Ammo.plan=function(_,gun) return {gun=gun,kind='shell',delay=.5} end
package.loaded.Ammo.complete=function() shells=shells+1; return true,'loaded-shell',shells<3 end
input({R=true}); now=now+.49; tick()
check(shells==0,'shell reload waits the full half second')
now=now+.01; tick()
check(shells==1,'first shell loads after half a second')
input(); input({R=true}); now=now+.49; tick()
check(shells==1,'repeated R cannot shorten the next shell delay')
now=now+.01; tick()
check(shells==2,'reload continues without another R press')
now=now+.5; input({G=true})
check(shells==2,'drop on the shell deadline cancels before spending another shell')
held=rifle; input(); input({R=true}); now=now+3; tick()
check(shells==3,'a late tick loads only one shell and stops at full')
package.loaded.Ammo.plan=function(_,gun) return {gun=gun,kind='loader',delay=2.5} end
package.loaded.Ammo.complete=magazine_complete
completed=reloads
input(); input({R=true}); now=now+2.49; tick()
check(reloads==completed,'revolver keeps its loader through the whole per-round delay')
now=now+.01; tick()
check(reloads==completed+1,'revolver finishes once after the full delay')
input(); input({R=true}); now=now+2.5; input({Tab=true})
check(reloads==completed+1,'opening pause on the reload deadline preserves the speedloader')
input(); input({Tab=true})
package.loaded.Ammo.plan=magazine_plan
input()
local utility=gun(pawn,100); utility.nongun=true
utility.GetTransform=function() return transform({X=100,Y=0,Z=170}) end
utility.PrimGripComponent.K2_GetComponentToWorld=function() return transform({X=110,Y=0,Z=170}) end
utility.K2_SetActorLocationAndRotation=function() return true end
held=utility; tick()
check(right.tick and left.tick,'utility holds retain native hand and pin interaction ticks')
check(controls.apply_gun_pose(utility,output) and output.Translation.X==35 and output.Translation.Y==12 and output.Translation.Z==160,
    'utility placement aligns the actual grip to a visible camera-relative anchor')
check(right.position.X==45 and right.position.Y==12 and right.position.Z==160,'utility hand follows the same visible anchor')
check(controls.apply_local_grab(utility,output) and output.Translation.Z==160,'native utility grab uses the visible camera anchor')
check(not controls.apply_local_grab(rifle,output),'native grab hook excludes a gun while a utility is held')
check(not controls.apply_local_grab(foreign,output),'native utility hook excludes other players and unheld items')
local grenade=gun(pawn,100); grenade.nongun=true
grenade.GetTransform=utility.GetTransform; grenade.PrimGripComponent.K2_GetComponentToWorld=utility.PrimGripComponent.K2_GetComponentToWorld
grenade.K2_SetActorLocationAndRotation=utility.K2_SetActorLocationAndRotation
utility=grenade
utility.IsA=function(_,path) return path:find('ZomboyGrenadeBP',1,true)~=nil end
utility.GrabHintGripIndicator=object({K2_GetComponentToWorld=function()
    local t=transform({X=100,Y=0,Z=170}); t.Rotation={X=0,Y=0,Z=-math.sqrt(.5),W=math.sqrt(.5)}; return t end})
held=rifle; tick(); held=utility; tick()
check(controls.apply_local_grab(utility,output) and math.abs(output.Rotation.Z)>.5 and math.abs(output.Rotation.Y)>.4,
    'grenade orientation compensates for its authored hand pose instead of one shared yaw')
check(not pawn.Mesh.bVisible,'gadget hides the local hand mesh without hiding the item')
input({MiddleMouseButton=true}); check(controls.wants_look(pawn),'middle mouse with a grenade does not lock the camera')
local grenade_type=utility.IsA
utility.IsA=function(_,path) return path:find('ZomboyClaymoreBP',1,true)~=nil end
check(not controls.wants_look(pawn),'middle mouse with the held Claymore locks camera look immediately')
local placement=package.loaded.Placement
local follow,drag=placement.follow,nil
placement.follow=function(_,_,_,_,rotating,x,y) drag={rotating=rotating,x=x,y=y} end
controls.tick(pawn,pc,camera,{Pitch=0,Yaw=0,Roll=0},12,8)
check(drag.rotating and drag.x==12 and drag.y==0,'middle drag forwards horizontal motion only')
input({MiddleMouseButton=true,LeftAlt=true})
controls.tick(pawn,pc,camera,{Pitch=0,Yaw=0,Roll=0},12,8)
check(drag.rotating and drag.x==0 and drag.y==8 and not controls.wants_look(pawn),'left Alt selects vertical drag while keeping camera locked')
input({MiddleMouseButton=true,RightAlt=true})
controls.tick(pawn,pc,camera,{Pitch=0,Yaw=0,Roll=0},12,8)
check(drag.x==0 and drag.y==8,'right Alt also selects vertical drag')
input({MiddleMouseButton=true})
controls.tick(pawn,pc,camera,{Pitch=0,Yaw=0,Roll=0},12,8)
check(drag.x==12 and drag.y==0,'releasing Alt restores horizontal drag without releasing middle mouse')
placement.follow=follow
utility.IsA=grenade_type
input()
held=rifle; tick()
check(pawn.Mesh.bVisible,'switching back to a gun restores the hand mesh')
check(right.tick,'gun controller ticks remain enabled for normal recoil')
input(); over_ui=true; wheel=1; tick(); wheel=0
check(pointer_scroll==1,'wheel scroll uses the existing pointer')
input({LeftMouseButton=true,LeftShift=true,LeftControl=true})
controls.stop()
check(not controls.apply_gun_pose(rifle,output),'disabled bridge cannot write a weapon pose')
check(releases==2 and not pointer.bIsEnabled,'disable releases pointer and restores prior enabled state')
check(right.tick and left.tick and right.PendingTrackingMode==0 and not right.bUseWithoutTracking and not right.bDisableLowLatencyUpdate,'disable restores controller tracking, flags and ticks')
check(right.RelativeRotation.Roll==6 and pointer.RootComponent.RelativeLocation.X==1,'disable restores relative poses')
check(not pawn.sprinting and not pawn.crouching and trigger==0,'disable clears synthetic movement and trigger state')
check(left_held==nil and camera.FieldOfView==90,'disable releases the synthetic support grip and restores FOV')
check(pointer.StaticMesh.bVisible,'disable restores pointer ring visibility')
check(not pointer.LaserMesh.bHiddenInGame and right.bReplicateWithoutTracking and right.PlayerIndex==0 and right.CurrentTrackingStatus==2,
    'disable restores the laser, hardware index, tracking state, and stock replication')
controls.start(pawn); held=utility; input(); controls.stop()
check(pawn.Mesh.bVisible,'disable while holding a gadget restores the original hand visibility')
local movement_x,movement_y=0,0
pawn.SetMovementInput_X=function(_,value) movement_x=value end
pawn.SetMovementInput_Y=function(_,value) movement_y=value end
controls.configure({W='Up',S='Down',A='Left',D='Right',E='F',LeftMouseButton='ThumbMouseButton'})
controls.start(pawn); held=rifle; over_ui=false; input()
input({Up=true,Right=true})
check(movement_x==1 and movement_y==1,'rebound movement reaches the native movement setters')
input({W=true,D=true})
check(movement_x==0 and movement_y==0,'old movement keys no longer drive the bridge')
input({W=true,LeftShift=true})
check(not pawn.sprinting and movement_y==0,'the old forward key cannot start sprint after rebinding')
input({Up=true,LeftShift=true})
check(pawn.sprinting and movement_y==1,'sprint follows the rebound forward key')
input({LeftShift=true})
check(not pawn.sprinting and movement_y==0,'releasing rebound forward stops sprint and movement')
local grabs=right.grabs or 0
held=nil
input({F=true})
check(right.grabs==grabs+1 and held==own,'rebound interact key picks up the aimed item')
held=rifle
input({ThumbMouseButton=true})
check(trigger==1,'rebound fire key fires')
input()
check(trigger==0,'releasing rebound fire stops firing')
local station_refills=0
own.IsA=function(_,path) return path:find('/AmmoSupply.',1,true)~=nil end
package.loaded.Ammo.refill=function() station_refills=station_refills+1; return 1,'chest-refilled' end
over_ui=true; local old_presses=presses; input({F=true})
check(station_refills==1 and presses==old_presses and held==rifle,
    'E uses the station before its floating label without dropping the gun')
pawn.InputMode=1; input(); input({F=true})
check(station_refills==1 and presses==old_presses+1,'E in the game menu clicks its button instead of refilling')
input(); over_ui=false
pawn.InputMode=1; input({Up=true})
check(movement_y==0,'settings and game menus stop keyboard movement')
pawn.InputMode=0; input({Up=true}); controls.stop()
check(movement_x==0 and movement_y==0,'disable releases movement after rebinding')
controls.configure()
-- A spent case, not an empty trigger pull, starts the automatic bolt cycle.
local cycles,ejected,chambered=0,0,0
rifle.GunData.bBoltAction=true
rifle.used,rifle.chamber,rifle.rounds=true,false,3
rifle.HasBulletInChamber=function(self) return self.chamber end
rifle.HaseUsedBulletInChamber=function(self) return self.used end
rifle.EjectChamberBullet=function(self) ejected=ejected+1; self.used=false; self.chamber=false end
rifle.MoveBulletToChamber=function(self)
    chambered=chambered+1
    if self.rounds==0 then return false end
    self.rounds=self.rounds-1; self.chamber=true; return true
end
rifle.GunBoltComponent=object({GetBoltState=function() return 0 end,
    BoltTravelFullRound=function(_,remaining) assert(remaining==0); cycles=cycles+1 end})
held=rifle; pawn.InputMode=0; controls.start(pawn); input()
now=now+.799; tick()
check(cycles==0 and not rifle.chamber,'spent bolt-action round waits before cycling')
now=now+.002; tick()
check(cycles==1 and rifle.chamber and not rifle.used and rifle.rounds==2,'automatic bolt chambers exactly one existing round')
now=now+2; tick()
check(cycles==1 and ejected==1 and chambered==1,'loaded bolt-action rifle is not cycled repeatedly')
rifle.chamber=false; rifle.used=false; tick(); now=now+2; tick()
check(cycles==1,'empty chamber without a fired case does not auto-cycle')
rifle.used=true; rifle.GunData.bBoltAction=false; tick(); now=now+2; tick()
check(cycles==1,'semi-auto and automatic guns keep their own cycling')
rifle.GunData.bBoltAction=true; input({LeftMouseButton=true})
check(trigger==0,'automatic cycling releases the held trigger')
input({Tab=true}); now=now+2; tick()
check(cycles==1,'game menu cancels pending bolt work')
input(); input({Tab=true}); input(); now=now+.4; tick(); held=own; tick(); now=now+1; tick()
check(cycles==1,'weapon change cancels pending bolt work on the old gun')
held=rifle; input(); input({R=true}); now=now+.9; tick()
check(cycles==1,'reload takes priority over automatic cycling')
input({G=true}); now=now+2; tick()
check(cycles==1,'dropping a rifle cancels both pending reload and bolt work')
held=rifle; rifle.rounds=0; input(); now=now+.801; tick()
check(cycles==2 and not rifle.chamber and not rifle.used and rifle.rounds==0,'last shot ejects its case without creating ammo')
now=now+2; tick()
check(cycles==2,'empty rifle does not repeatedly run the bolt')
rifle.used=true; input(); controls.stop(); now=now+2; tick()
check(cycles==2,'stopping flatscreen cancels pending bolt work')
held=nil; pawn.InputMode=0; controls.start(pawn); input({F9=true})
check(controls.wants_look(pawn),'a pointer key already held during activation does not toggle')
input(); input({F9=true}); input(); over_ui=true
local old_presses,old_releases=presses,releases
input({LeftMouseButton=true})
check(presses==old_presses+1 and trigger==0,'manual pointer mode selects through the stock widget pointer')
input({LeftMouseButton=true,F9=true})
check(releases==old_releases+1 and trigger==0 and controls.wants_look(pawn),'leaving pointer mode releases its UI click without firing a held mouse button')
over_ui=false; input(); input({F9=true}); controls.stop(); controls.start(pawn); input()
check(controls.wants_look(pawn),'stop and pawn replacement clear manual pointer control')
controls.stop()
-- Send the final two-hand grip, not the native untracked fallback position.
rifle.GunData.bBoltAction=false; held=rifle; keys={}; now=now+1
controls.start(pawn)
native_hand_poses=function(is_right)
    local t=transform({X=108,Y=is_right and 2 or 4,Z=174})
    t.Rotation={X=0,Y=-math.sin(math.rad(30)),Z=0,W=math.cos(math.rad(30))}
    return t
end
tick()
check(math.abs(right.packet.Position.X-right.position.X)<.00001
    and math.abs(left.packet.Position.Z-left.position.Z)<.00001
    and right.packet.Position.Y~=left.packet.Position.Y,'packets contain both final authored grips')
local sends=right.sends; now=now+.005; tick()
check(right.sends==sends,'pose sender respects the stock update rate')
now=now+.006; tick()
check(right.sends==sends+1,'pose sender resumes after its update interval')
local function angles(packet)
    return {Pitch=(packet.YawPitchINT%65536)*360/65536,Yaw=math.floor(packet.YawPitchINT/65536)*360/65536,Roll=packet.RollSHORT*360/65536}
end
for _,ads in ipairs({false,true}) do
    keys={RightMouseButton=ads}; now=now+1; tick(); now=now+1; tick()
    local previous
    for _,pitch in ipairs({20,29,30,31,40,80,40,31,30,29,20,-85}) do
        now=now+.02; controls.tick(pawn,pc,camera,{Pitch=pitch,Yaw=0,Roll=0})
        local r=angles(right.packet)
        check(math.abs((r.Pitch-(pitch+60)+180)%360-180)<.01,'packet retains full wrist pitch in '..(ads and 'ADS' or 'hip fire'))
        if previous then
            check(math.abs((r.Yaw-previous.Yaw+180)%360-180)<.01 and math.abs((r.Roll-previous.Roll+180)%360-180)<.01,
                'vertical wrist crossing does not flip the remote yaw or roll')
        end
        previous=r
    end
end
-- Mesh origin differs from capsule origin; an attached actor supplies rotation/scale.
local parent=object({GetTransform=function()
    local t=transform({X=900,Y=900,Z=900});t.Rotation={X=0,Y=0,Z=math.sqrt(.5),W=math.sqrt(.5)}
    t.Scale3D={X=2,Y=2,Z=2};return t
end})
pawn.GetParentActor=function() return parent end
pawn.Mesh.K2_GetComponentLocation=function() return {X=10,Y=20,Z=30} end
now=now+.02; tick()
local p=right.packet.Position
check(math.abs(p.X-(right.position.Y-20)/2)<.00001 and math.abs(p.Y+(right.position.X-10)/2)<.00001
    and math.abs(p.Z-(right.position.Z-30)/2)<.00001,'packets use native mesh origin with parent rotation and scale')
unloaded=true
controls.stop(true)
check(controls.status()=='','world unload discards control references without accessing freed objects')
unloaded=false
check(controls.start(pawn),'controls can start again after discarding an unloaded world')
controls.stop()
-- Runs within the generated control fixture, after the shared checks.
do
    held=rifle; pawn.InputMode=0; keys={}; now=now+1
    controls.start(pawn); input(); now=now+.21; tick()
    local old_plan,old_complete=package.loaded.Ammo.plan,package.loaded.Ammo.complete
    local loaded=0
    rifle.HasBulletInChamber=function() return loaded>0 end
    package.loaded.Ammo.plan=function(_,gun) return {gun=gun,kind='shell',delay=.5} end
    package.loaded.Ammo.complete=function() loaded=loaded+1; return true,'loaded-shell',true end
    input({R=true}); input({LeftMouseButton=true})
    check(trigger==0 and controls.status():find('reload_pending=true',1,true),'empty shotgun click cannot interrupt before a shell is ready')
    input(); now=now+.501; tick(); input({LeftMouseButton=true})
    check(loaded==1 and trigger==0 and controls.status():find('shell_raise=true',1,true)
        and controls.status():find('reload_pending=false',1,true),'fire cancels the next shell and starts a raise delay')
    now=now+.125;tick();controls.apply_gun_pose(rifle,output)
    check(trigger==0 and output.Translation.Z<156 and output.Translation.Z>142,'shotgun rises smoothly while firing stays blocked')
    now=now+.124;tick();check(trigger==0,'shotgun cannot fire before 250 ms')
    now=now+.002;tick();check(trigger==1 and loaded==1,'held fire works after 250 ms without loading another shell')
    input();now=now+1;tick();check(loaded==1 and trigger==0,'interrupted reload stays cancelled')
    local function interrupt()
        input();input({R=true});now=now+.1;input({LeftMouseButton=true})
    end
    interrupt();input();now=now+.3;tick()
    check(trigger==0,'releasing fire during the raise cancels the delayed shot')
    interrupt();input({LeftMouseButton=true,Tab=true});now=now+.3;tick()
    check(trigger==0,'menu cancels a delayed shotgun shot')
    input();input({Tab=true});input()
    interrupt();input({LeftMouseButton=true,G=true});now=now+.3;tick()
    check(trigger==0 and held==nil,'drop cancels a delayed shotgun shot')
    held=rifle;input()
    interrupt();held=own;now=now+.3;tick()
    check(trigger==0,'weapon replacement cancels a delayed shotgun shot');held=rifle;input()
    interrupt();controls.stop();now=now+.3;controls.start(pawn);tick()
    check(trigger==0,'stop cancels a delayed shotgun shot');input()
    package.loaded.Ammo.plan,package.loaded.Ammo.complete=old_plan,old_complete

    local began,ended=0,0
    sight.IsA=function(_,path) return path:find('ZomboyZoomSightBaseNew',1,true)~=nil end
    sight.bEnablingScop=false
    sight.OnBeginAimDownSight=function(self) began=began+1;self.bEnablingScop=true end
    sight.OnEndAimDownSight=function(self) ended=ended+1;self.bEnablingScop=false end
    input({RightMouseButton=true});now=now+.21;tick()
    check(began==1 and sight.bEnablingScop,'independent ADS starts the owned magnified scope')
    tick();check(began==1,'enabled scope is not restarted every tick')
    sight.bEnablingScop=false;tick();check(began==2,'stock geometry disable is repaired while independent ADS stays on')
    input();check(ended==1 and not sight.bEnablingScop,'lowering the gun stops the owned scope')

    input({RightMouseButton=true});input({RightMouseButton=true,F6=true})
    check(sight.bEnablingScop,'retired F6 does not stop magnified scope capture')
    input();input({F6=true});input();input({RightMouseButton=true});controls.stop()
    check(not sight.bEnablingScop,'controls stop restores the forced scope')
    sight.IsA=function() return false end
    controls.start(pawn);input();input({RightMouseButton=true});tick()
    check(not sight.bEnablingScop,'ordinary sights do not receive forced zoom events')
    input();now=now+.21;tick()

    local old_find=StaticFindObject
    local old_trigger=right.OnTriggerAxisChanged
    local trigger_presses=0
    right.OnTriggerAxisChanged=function(self,value)
        if value>0 then trigger_presses=trigger_presses+1 end
        old_trigger(self,value)
    end
    local hit_time=nil
    local hit_normal={X=-1,Y=0,Z=0}
    local traces=0
    StaticFindObject=function(path)
        if path~='/Script/Engine.Default__KismetSystemLibrary' then return old_find(path) end
        return {SphereTraceSingle=function(_,context,start,finish,radius,channel,complex,ignored,debug,hit,ignore_self)
            check(context==pawn and radius==5 and channel==2 and not complex and #ignored==0 and ignore_self,
                'obstruction sweep uses Weapon collision and native pawn self-ignore')
            traces=traces+1
            if hit_time then hit.Time=hit_time;hit.Normal=hit_normal;return true end
            return false
        end}
    end
    controls.capture_recoil(rifle,original,original);tick();controls.apply_gun_pose(rifle,output)
    local rest=output.Translation.X
    hit_time=.5;input({LeftMouseButton=true});controls.apply_gun_pose(rifle,output)
    check(trigger==0 and trigger_presses==0 and output.Translation.X<rest and output.Rotation.Y==0 and output.Rotation.Z==0,
        'new obstruction retracts without ever pressing the native trigger or turning the gun')
    local traced=traces;controls.apply_local_grab(rifle,native_pass)
    check(traces==traced and math.abs(native_pass.Translation.X-output.Translation.X)<.00001,
        'native grab uses the same obstruction correction without another query')
    hit_time=nil;now=now+.05;tick();controls.apply_gun_pose(rifle,output)
    check(output.Translation.X<rest and trigger==0,'clearing cover never queues the blocked click')
    now=now+.151;tick();controls.apply_gun_pose(rifle,output)
    check(math.abs(output.Translation.X-rest)<.00001,'gun returns to its original extended grip after cover clears')
    input();input({LeftMouseButton=true});check(trigger==1,'fresh click works after cover clears')
    hit_time=0;tick();controls.apply_gun_pose(rifle,output)
    check(trigger==0 and controls.status():find('wall_blocked=true',1,true),'initial overlap blocks fire and fully retracts')
    check(output.Translation.Z<130,'point-blank wall keeps the weapon below the camera instead of inside its barrel')
    hit_normal={X=0,Y=0,Z=1};tick();controls.apply_gun_pose(rifle,output)
    check(output.Translation.Y>30,'floor obstruction uses lateral clearance when downward motion is blocked')
    input({Tab=true});check(controls.status():find('wall_blocked=false',1,true),'menu clears old obstruction state')
    input();input({Tab=true});input();hit_time=nil;now=now+.2;tick()
    StaticFindObject=old_find;right.OnTriggerAxisChanged=old_trigger;controls.stop()
end
do
    held=rifle;pawn.InputMode=0;keys={};rifle.bIsPhysicalInteractible=true
    controls.start(pawn);input();now=now+.3;tick()
    check(not rifle.bIsPhysicalInteractible,'owned held gun uses the native direct-pose path')
    input({Tab=true})
    check(rifle.bIsPhysicalInteractible,'menu returns held physics to its original value')
    input();input({Tab=true});input()
    local release=right.OnGripButtonReleased
    right.OnGripButtonReleased=function(self)
        check(rifle.bIsPhysicalInteractible,'drop restores the flag before the native release')
        release(self)
    end
    input({G=true});right.OnGripButtonReleased=release
    check(rifle.bIsPhysicalInteractible and not held,'dropped gun retains normal physics')
    held=rifle;input();held=own;input()
    check(rifle.bIsPhysicalInteractible and not own.bIsPhysicalInteractible,'replacement restores old gun and drives only the new gun')
    held=foreign;input()
    check(own.bIsPhysicalInteractible and foreign.bIsPhysicalInteractible,'foreign gun is untouched and old gun is restored')
    held=rifle;input();controls.stop()
    check(rifle.bIsPhysicalInteractible,'controls stop restores held physics for VR')
    rifle.bIsPhysicalInteractible=false;controls.start(pawn);input();controls.stop()
    check(not rifle.bIsPhysicalInteractible,'a gun authored without held physics keeps that original setting')
    rifle.bIsPhysicalInteractible=true
end

print(count..' keyboard interaction checks passed; slide physics and sight alignment require live verification')
os.clock=real_clock
