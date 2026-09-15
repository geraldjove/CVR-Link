local count,id=0,0
local real_clock,now=os.clock,0
os.clock=function() return now end
local function check(value,label) assert(value,label); count=count+1 end
local function object(values)
    id=id+1; local address=id
    values.IsValid=function(self) return not self.invalid end
    values.GetAddress=function() return address end
    values.GetFName=function() return {ToString=function() return 'MockGun' end} end
    values.IsA=function() return false end
    return values
end
local function component()
    return object({RelativeLocation={X=1,Y=2,Z=3},RelativeRotation={Pitch=4,Yaw=5,Roll=6},
        tick=true,bUseWithoutTracking=false,bDisableLowLatencyUpdate=false,PendingTrackingMode=0,
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
    StaticMesh=object({bVisible=true,SetVisibility=function(self,value) self.bVisible=value end}),
    WidgetInteraction=object({IsOverHitTestVisibleWidget=function() return over_ui end}),
    Enable=function(self) self.bIsEnabled=true end,Disable=function(self) self.bIsEnabled=false end,
    PressPointerKey=function(_,key) assert(key.KeyName=='LeftMouseButton'); presses=presses+1 end,
    ReleasePointerKey=function() releases=releases+1 end,
    ScrollWheel=function(_,value) pointer_scroll=value end})
local camera=object({FieldOfView=90,SetFieldOfView=function(self,value) self.FieldOfView=value end,
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
pawn.Mesh=object({bVisible=true,SetVisibility=function(self,value,propagate) assert(not propagate); self.bVisible=value end})
local function gun(owner,x)
    local result=object({PrimGripComponent=object({}),GetOwner=function() return owner end,
        GetCurrentClip=function(self) return self.clip end,
        GetInstigator=function() return nil end,K2_GetActorLocation=function() return {X=x,Y=0,Z=170} end,
        GetActorAttachingTo=function() return nil end,
        ReloadWeapon=function() reloads=reloads+1 end,
        ChangeFiringMode=function() mode_changes=mode_changes+1 end,
        GetCurrentFiringMode=function() return 0 end,
        SetPancakeAimingDownSight=function(self,value) self.ads=value end})
    result.PrimGripComponent.GetOwner=function() return result end
    result.PrimGripComponent.GetInteractable=function() return result end
    result.PrimGripComponent.K2_GetComponentLocation=result.K2_GetActorLocation
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
rifle.K2_SetActorLocationAndRotation=function() return true end
local function transform(p)
    return {Translation=p,Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}}
end
rifle.GetTransform=function() return transform({X=100,Y=0,Z=170}) end
rifle.GetGunFiringTransform=function() return transform({X=177,Y=0,Z=170}) end
rifle.DefaultMuzzleRelativeTransform=transform({X=77,Y=0,Z=0})
rifle.DefaultSightRelativeTransform=transform({X=4,Y=0,Z=8})
rifle.GetPancakeSightRelativeTransform=function() return transform({X=4,Y=0,Z=8}) end
-- Identity-rotation transform fixture isolates muzzle/sight offsets and ownership.
local pc=object({IsInputKeyDown=function(_,key) return keys[key.KeyName] or false end,
    GetInputAnalogKeyState=function() return wheel end})
FName=function(value) return value end
local center_hit
StaticFindObject=function(value)
    if value=='/Script/Engine.Default__KismetSystemLibrary' then return {LineTraceSingle=function(_,_,start,finish,channel,complex,ignore,debug,hit)
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
FindAllOf=function(name)
    if name=='ZomboyInteractableHolster' then return {} end
    if name=='ZomboyGunSightAttachmentActor' then return {sight} end
    if name=='ZomboyInteractionComponent' then return {foreign.PrimGripComponent,far.PrimGripComponent,own.PrimGripComponent} end
    assert(name=='ContractorsPrimaryGun_C'); return {foreign,far,own}
end
local controls=dofile('Controls.lua')
local function tick() controls.tick(pawn,pc,camera,{Pitch=0,Yaw=0,Roll=0}) end
local function input(values) keys=values or {}; tick() end
controls.start(pawn)
check(right.tick and left.tick and right.bUseWithoutTracking and right.PendingTrackingMode==1,'controllers retain interaction ticks with animation tracking')
check(pointer.bIsEnabled,'existing pointer is enabled')
check(not pointer.StaticMesh.bVisible,'decorative pointer rings are hidden without disabling interaction')
input({LeftMouseButton=true})
check(trigger==0 and presses==0,'activation does not fire a mouse button already held')
input()
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
check(controls.apply_gun_pose(rifle,output) and output.Translation.X==23 and output.Translation.Y==16 and output.Translation.Z==156,'hip pose accounts for the actual muzzle offset')
check(not controls.apply_gun_pose(foreign,output),'weapon pose excludes other players and unheld guns')
input({LeftMouseButton=true})
check(trigger==1,'mouse press drives stock trigger')
input({LeftMouseButton=true,Tab=true})
check(pawn.InputMode==1 and trigger==0,'opening menu releases a held trigger')
check(not controls.wants_look(pawn),'open menu freezes camera look')
controls.tick(pawn,pc,camera,{Pitch=0,Yaw=0,Roll=0},12,-8)
check(pointer.RootComponent.rotation.Yaw==12 and pointer.RootComponent.rotation.Pitch==-8,'menu mouse motion steers pointer in both axes')
input({R=true,E=true,G=true,B=true,RightMouseButton=true,LeftShift=true,LeftControl=true})
check(reloads==0 and held==rifle and not rifle.ads and not pawn.sprinting and crouches==0,'menu blocks weapon and movement actions')
input(); input({Tab=true}); input()
check(pawn.InputMode==0,'Tab closes the menu')
check(controls.wants_look(pawn) and pointer.RootComponent.rotation.Yaw==0,'closing menu restores centered pointer and camera input')
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
check(camera.FieldOfView==90,'zoom starts at the normal FOV')
now=now+.1; tick(); check(camera.FieldOfView>58.5 and camera.FieldOfView<90,'zoom transitions through an intermediate FOV')
now=now+.101; tick()
check(camera.FieldOfView==58.5 and not rifle.ads,'zoom fallback changes camera FOV without native sight aiming')
controls.apply_gun_pose(rifle,output)
check(output.Translation.X==23 and output.Translation.Y==16,'zoom fallback retains the hip weapon anchor')
input(); input({F6=true}); input()
check(camera.FieldOfView==90,'releasing zoom restores the original FOV')
local original=transform({X=1000,Y=400,Z=200})
local kicked=transform({X=998,Y=400,Z=200})
kicked.Rotation={X=0,Y=-math.sin(math.rad(3)),Z=0,W=math.cos(math.rad(3))}
check(controls.capture_recoil(rifle,original,kicked),'native recoil is captured for the owned held gun')
controls.apply_gun_pose(rifle,output)
check(math.abs(output.Rotation.Y-kicked.Rotation.Y)<.00001 and output.Translation.X==21,'native recoil rotation and displacement survive camera anchoring')
check(not controls.capture_recoil(foreign,original,kicked),'recoil from another gun is excluded')
controls.capture_recoil(rifle,original,original)
-- Intersect the corrected muzzle ray with the center target's plane.
local function shot_at(x)
    controls.apply_gun_pose(rifle,output)
    local q=output.Rotation
    local dx,dy,dz=1-2*(q.Y*q.Y+q.Z*q.Z),2*(q.X*q.Y+q.W*q.Z),2*(q.X*q.Z-q.W*q.Y)
    local muzzle={X=output.Translation.X+dx*77,Y=output.Translation.Y+dy*77,Z=output.Translation.Z+dz*77}
    local distance=(x-muzzle.X)/dx
    return muzzle,muzzle.Y+dy*distance,muzzle.Z+dz*distance,dx
end
center_hit={X=200,Y=0,Z=170}; tick()
local muzzle,hit_y,hit_z,dx=shot_at(200)
check(math.abs(hit_y)<.00001 and math.abs(hit_z-170)<.00001,'resting hip-fire ray meets the fixed center target at two metres')
controls.capture_recoil(rifle,original,kicked)
muzzle,hit_y,hit_z=shot_at(200)
check(hit_z>170.1,'native recoil still moves shots away from the center target')
controls.capture_recoil(rifle,original,original)
center_hit={X=40,Y=0,Z=170}; tick()
muzzle,hit_y,hit_z,dx=shot_at(40)
check(muzzle.X<40 and muzzle.X>0 and dx>0,'close wall retracts the hip muzzle without pointing it backwards')
check(math.abs(hit_y)<.00001 and math.abs(hit_z-170)<.00001,'retracted muzzle still aims at the close center target')
input({RightMouseButton=true}); now=now+.201; tick()
controls.apply_gun_pose(rifle,output)
check(math.abs(output.Translation.X-14)<.00001 and math.abs(output.Translation.Z-162)<.00001
    and math.abs(output.Rotation.Y)<.00001,'full scope ADS keeps its existing sight alignment near a wall')
input(); now=now+.201; tick()
center_hit={X=10000,Y=0,Z=170}; tick()
muzzle,hit_y,hit_z=shot_at(10000)
check(math.abs(hit_y)<.00001 and math.abs(hit_z-170)<.00001,'far center target retains muzzle convergence')
center_hit=nil; tick()
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
check(camera.FieldOfView==90 and not rifle.ads,'F6 zoom also waits for sprint recovery')
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
check(controls.apply_utility_grab(utility,output) and output.Translation.Z==160,'native utility grab uses the visible camera anchor')
check(not controls.apply_utility_grab(rifle,output),'native utility hook excludes guns')
check(not controls.apply_utility_grab(foreign,output),'native utility hook excludes other players and unheld items')
local grenade=gun(pawn,100); grenade.nongun=true
grenade.GetTransform=utility.GetTransform; grenade.PrimGripComponent.K2_GetComponentToWorld=utility.PrimGripComponent.K2_GetComponentToWorld
grenade.K2_SetActorLocationAndRotation=utility.K2_SetActorLocationAndRotation
utility=grenade
utility.IsA=function(_,path) return path:find('ZomboyGrenadeBP',1,true)~=nil end
utility.GrabHintGripIndicator=object({K2_GetComponentToWorld=function()
    local t=transform({X=100,Y=0,Z=170}); t.Rotation={X=0,Y=0,Z=-math.sqrt(.5),W=math.sqrt(.5)}; return t end})
held=rifle; tick(); held=utility; tick()
check(controls.apply_utility_grab(utility,output) and math.abs(output.Rotation.Z)>.5 and math.abs(output.Rotation.Y)>.4,
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
print(count..' keyboard interaction checks passed; slide physics and sight alignment require live verification')
os.clock=real_clock
