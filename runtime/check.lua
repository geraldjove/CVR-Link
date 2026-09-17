-- Run with Lua 5.4. Tests the lease and restoration behavior without a game.
local now, lease, begin_play, post_tick, travel, leave_game, open_local_map = 100, 0
local world_id=1
local unreadable, read_error = false, false
local mouse_x, mouse_y = 0, 0
local camera_rotation = {Pitch=10,Yaw=179,Roll=25}
local restored_pose, written_location, controller_rotation
local written_status=''
local function copy(v)
    local result = {}
    for k,value in pairs(v) do result[k]=value end
    return result
end
local count = 0
local function object(values)
    values.IsValid = function() return values.valid~=false end
    values.IsLocallyControlled = function() return values.local_player~=false end
    values.IsA = function() return true end
    values.GetFName = function() return {ToString=function() return 'MockPawn' end} end
    values.GetAddress = function() return values.address or 1 end
    values.GetFullName = function() return 'MockGame '..(values.address or 1) end
    values.GetWorld = function() return {GetAddress=function() return world_id end,GetFullName=function() return 'MockWorld '..world_id end} end
    return values
end
local camera = object({bAutoSetLockToHmd=true,bLockToHmd=true,bUsePawnControlRotation=false,
    RelativeLocation={X=10,Y=2,Z=170},RelativeRotation={Pitch=1,Yaw=2,Roll=3},
    K2_SetRelativeLocationAndRotation=function(_,position,rotation)
        restored_pose={position=copy(position),rotation=copy(rotation)}
    end,
    K2_SetRelativeLocation=function(_,position) written_location=copy(position) end,
    K2_SetWorldRotation=function(_,rotation) camera_rotation=copy(rotation) end,
    K2_GetComponentRotation=function() return camera_rotation end})
local instance = object({PlayMode=0})
local xr_enabled=true
local returns,headset_free_start=0,false
local online_member=false
local hmd=object({IsHeadMountedDisplayEnabled=function() return xr_enabled end,
    IsHeadMountedDisplayConnected=function() return not headset_free_start end,
    EnableHMD=function(_,value) xr_enabled=value; return true end})
local pawn = object({PlayerCamera=camera,PlayMode=0,bVRMode=true})
local pc = object({
    IsLocalController=function() return true end,
    GetInputAnalogKeyState=function(_,key) return key.KeyName=='MouseX' and mouse_x or mouse_y end,
    IsInputKeyDown=function() return false end,
    SetControlRotation=function(_,rotation) controller_rotation=copy(rotation) end,
    ClientReturnToMainMenu=function() error('generic engine return leaves the Contractors lobby registered') end,
    ClientLeaveGame=function()
        assert((pawn.PlayMode==0 and pawn.bVRMode),'unsupported match controls must be restored before disconnect')
        returns=returns+1; leave_game()
        online_member=false
    end})
StaticFindObject = function(path)
    if path:find('HeadMountedDisplay') then return hmd end
    if path:find('KismetSystemLibrary') then return object({IsStandalone=function() return true end}) end
    return object({
    GetGameInstance=function() return instance end,GetGameState=function() return instance end,
    GetPlayerController=function() return pc end}) end
FName = function(value) return value end
RegisterBeginPlayPostHook = function(callback) begin_play=callback end
RegisterHook = function(path,callback,third)
    assert(not path:find('GameplayStatics:',1,true),'UE4SS 3.0.1 cannot hook static Blueprint libraries')
    if path=='/Script/ZomboyVR.ZomboyGameInstance:OpenLocalMap' then
        assert(third==nil,'local map cleanup must run before the native call')
        open_local_map=callback; return
    end
    if path:find('PlayerController:',1,true) then
        if path:find(':ClientTravelInternal',1,true) then travel=function() callback({get=function() return pc end}) end end
        if path:find(':ClientLeaveGame',1,true) then leave_game=function() callback({get=function() return pc end}) end end
        assert(third==nil,'travel restoration must run before travel')
        return
    end
    if path:sub(1,8)=='/Script/' then assert(third,'native hook requires a post callback'); return end
    assert(path:sub(1,6)=='/Game/' and third==nil, 'Blueprint hook callback must be argument two')
    if path:find('CS_Character') then post_tick=callback end
end
local native_os, native_io = os, io
local controls_pawn,controls_stops,controls_ready=nil,0,true
package.loaded.Controls={start=function(p) if not controls_ready then return false end; controls_pawn=p; return true end,stop=function() controls_stops=controls_stops+1; controls_pawn=nil end,
    tick=function(p) assert(p==controls_pawn,'controls must use the active pawn') end,status=function() return '' end,configure=function() end,
    hud_state=function() return false,false end,
    wants_look=function() return pawn.InputMode~=1 end}
local room_allowed,unsupported=true,false
package.loaded.Menu={settings={mouse=2.5,aim=1,keys={RightMouseButton='RightMouseButton'}},
    hud=function() return nil end,
    update=function(_,_,_,ready) return ready and room_allowed,unsupported end,
    clear=function() room_allowed=false end,status=function() return '' end}
os = {getenv=function() return 'mock' end, time=function() return now end, clock=function() return now end}
io = {open=function(path, mode)
    if mode=='r' and unreadable then return nil,'busy' end
    return {read=function()
        if read_error then return nil,'read failed' end
        return lease and tostring(lease) or nil
    end,write=function(_,...) written_status=table.concat({...}) end,close=function() end}
end}
dofile('main.lua')
begin_play({get=function() return pawn end})
assert(post_tick, 'character tick must be registered')
local function tick() now=now+1; post_tick({get=function() return pawn end}) end
local function check(condition, label) assert(condition,label); count=count+1 end
tick()
check((pawn.PlayMode==0 and pawn.bVRMode) and camera.bLockToHmd, 'inactive startup preserves VR')
controls_ready=false
for _=1,3 do lease=now+3; tick() end
check((pawn.PlayMode==0 and pawn.bVRMode) and instance.PlayMode==0 and pawn.bVRMode and xr_enabled and camera.bLockToHmd and not controls_pawn,
    'late local player setup waits without changing camera, mode, XR, or controls')
check(written_status:find('|WAITING|',1,true),'missing pointer reports waiting instead of a latched error')
lease=0; tick(); controls_ready=true; tick()
check((pawn.PlayMode==0 and pawn.bVRMode) and not controls_pawn,'a pointer arriving after helper off cannot activate flatscreen')
lease=now+3
tick()
check((pawn.PlayMode==0 and not pawn.bVRMode) and instance.PlayMode==0, 'valid lease activates flatscreen without disabling native VR gun following')
check(not camera.bLockToHmd and not camera.bAutoSetLockToHmd, 'active camera ignores HMD')
check(not camera.bUsePawnControlRotation, 'camera excludes headset-derived controller rotation')
check(not xr_enabled, 'activation disables native HMD/stereo rendering')
check(camera_rotation.Roll==0, 'activation levels a tilted horizon')
check(written_location.X==10 and written_location.Y==2 and written_location.Z==170, 'activation retains camera position')
unreadable=true
tick()
check((pawn.PlayMode==0 and not pawn.bVRMode), 'transient open failure keeps the unexpired lease')
tick()
check((pawn.PlayMode==0 and pawn.bVRMode) and instance.PlayMode==0, 'continued read failures cannot extend expiry')
check(camera.bLockToHmd and camera.bAutoSetLockToHmd and not camera.bUsePawnControlRotation, 'expiry restores camera flags')
check(restored_pose.position.X==10 and restored_pose.rotation.Roll==3, 'expiry restores original camera pose')
check(xr_enabled, 'expiry restores previously-enabled native HMD')
unreadable=false
lease=now+100
tick()
check((pawn.PlayMode==0 and pawn.bVRMode), 'far-future lease cannot latch activation')
lease=now+3
tick()
check((pawn.PlayMode==0 and not pawn.bVRMode), 'fresh lease can reactivate')
read_error=true
tick()
check((pawn.PlayMode==0 and not pawn.bVRMode), 'transient read error retains the original deadline')
read_error=false
lease=0
tick()
check((pawn.PlayMode==0 and pawn.bVRMode) and camera.bLockToHmd, 'explicit off restores original settings')
local function active_tick() lease=now+3; tick() end
camera_rotation={Pitch=10,Yaw=179,Roll=25}
mouse_x,mouse_y=2,4
active_tick()
check(camera_rotation.Yaw==-176 and camera_rotation.Pitch==20, 'mouse changes yaw and pitch with yaw wrap')
check(controller_rotation.Yaw==-176 and controller_rotation.Roll==0, 'movement controller matches level view')
pawn.InputMode=1
active_tick()
check(camera_rotation.Yaw==-176 and camera_rotation.Pitch==20, 'menu input cannot rotate the camera')
pawn.InputMode=0
mouse_x,mouse_y=0,0
camera_rotation={Pitch=-30,Yaw=40,Roll=-45}
active_tick()
check(camera_rotation.Pitch==20 and camera_rotation.Yaw==-176 and camera_rotation.Roll==0, 'simulated headset rotation cannot change stored mouse view')
mouse_y=100
active_tick()
check(camera_rotation.Pitch==85 and camera_rotation.Roll==0, 'upward pitch clamps without roll')
mouse_y=-100
active_tick()
check(camera_rotation.Pitch==-85, 'downward pitch clamps')
mouse_y=0
lease='malformed'
tick()
check((pawn.PlayMode==0 and pawn.bVRMode), 'malformed readable lease clears active mode immediately')
active_tick()
lease=nil
tick()
check((pawn.PlayMode==0 and pawn.bVRMode), 'empty readable file clears active mode immediately')
active_tick()
lease=now+100
tick()
check((pawn.PlayMode==0 and pawn.bVRMode), 'far-future value clears an already-active lease')
active_tick()
local old_pawn,old_camera,stops=pawn,camera,controls_stops
camera=object(copy(camera))
camera.bAutoSetLockToHmd,camera.bLockToHmd=true,true
pawn=object({address=2,PlayerCamera=camera,PlayMode=0,bVRMode=true})
controls_ready=false
active_tick()
check((pawn.PlayMode==0 and pawn.bVRMode) and old_pawn.PlayMode==0 and old_camera.bLockToHmd and not controls_pawn and xr_enabled,
    'respawn releases old controls and waits for the new pointer without latching an error')
controls_ready=true
active_tick()
check((pawn.PlayMode==0 and not pawn.bVRMode) and not pawn.bVRMode and not camera.bLockToHmd and not xr_enabled,
    'respawn reapplies flatscreen to the replacement pawn with the same match choice')
check(old_pawn.PlayMode==0 and old_camera.bLockToHmd and controls_stops==stops+1 and controls_pawn==pawn,
    'respawn releases old controls and camera before binding the new pawn')
local remote=object({address=99,local_player=false})
post_tick({get=function() return remote end})
check(controls_pawn==pawn and (pawn.PlayMode==0 and not pawn.bVRMode),'remote pawn ticks cannot replace local flatscreen controls')
old_pawn,old_camera=pawn,camera
old_pawn.valid,old_camera.valid=false,false
camera=object(copy(camera)); camera.valid=true
camera.bAutoSetLockToHmd,camera.bLockToHmd=true,true
pawn=object({address=3,PlayerCamera=camera,PlayMode=0,bVRMode=true})
active_tick()
check(controls_pawn==pawn and (pawn.PlayMode==0 and not pawn.bVRMode) and not xr_enabled,'respawn also recovers after the old pawn and camera are destroyed')
lease=0; tick()
check((pawn.PlayMode==0 and pawn.bVRMode) and pawn.bVRMode and camera.bLockToHmd and xr_enabled and not controls_pawn,
    'link off after repeated respawns restores the new pawn and original HMD mode')
-- An incompatible property fails activation, restores partial changes, and stays off.
active_tick()
room_allowed=false; unsupported=true
active_tick()
check((pawn.PlayMode==0 and pawn.bVRMode) and xr_enabled and returns==0,'normal VR start restores VR outside the loadout without leaving')
room_allowed=true; unsupported=false
active_tick()
assert(leave_game,'Contractors leave-session RPC must be hooked before its body')
leave_game()
check((pawn.PlayMode==0 and pawn.bVRMode) and xr_enabled and not controls_pawn,'Contractors leave-session route releases controls and restores VR before teardown')
active_tick()
check((pawn.PlayMode==0 and pawn.bVRMode),'Contractors leave-session route clears the previous choice')
room_allowed=true; active_tick()
travel()
check((pawn.PlayMode==0 and pawn.bVRMode) and xr_enabled,'map travel restores VR before leaving the old world')
active_tick()
check((pawn.PlayMode==0 and pawn.bVRMode),'map travel clears the previous room choice')
room_allowed=true
active_tick()
assert(open_local_map,'local map starts must have an early cleanup hook')
open_local_map()
check(pawn.bVRMode and xr_enabled and not controls_pawn,'local map start restores controls before unloading HQ')
active_tick()
check(pawn.bVRMode,'local map cleanup blocks late old-world ticks')
room_allowed=true; active_tick()
old_pawn,old_camera=pawn,camera
local stale_reads=0
local function freed() stale_reads=stale_reads+1; error('unloaded UObject was dereferenced') end
old_pawn.IsValid,old_camera.IsValid=freed,freed
camera=object(copy(camera)); camera.bAutoSetLockToHmd,camera.bLockToHmd=true,true
pawn=object({address=4,PlayerCamera=camera,PlayMode=0,bVRMode=true})
world_id=2
active_tick()
check(stale_reads==0 and pawn.bVRMode and xr_enabled and not controls_pawn,
    'unhooked world travel discards freed objects and restores shared XR state without reading old memory')
check(instance.PlayMode==0,'unhooked travel preserves the persistent game instance mode')
room_allowed=true; active_tick()
check(not pawn.bVRMode and controls_pawn==pawn and not xr_enabled,'the next allowed world can activate after stale references are discarded')
lease=0; tick()
camera.bAutoSetLockToHmd=nil
lease=now+3
tick()
check((pawn.PlayMode==0 and pawn.bVRMode) and instance.PlayMode==0, 'partial activation failure restores already-written fields')
camera.bAutoSetLockToHmd=true
lease=now+3
tick()
check((pawn.PlayMode==0 and pawn.bVRMode), 'error latches off until restart')
-- A new headset-free process must enforce the gate even after settings change.
headset_free_start=true; xr_enabled=false; room_allowed=true; unsupported=false
dofile('main.lua'); begin_play({get=function() return pawn end})
active_tick()
check((pawn.PlayMode==0 and not pawn.bVRMode) and not xr_enabled,'headset-free process can activate without enabling XR')
lease=0; tick()
check((pawn.PlayMode==0 and pawn.bVRMode) and not xr_enabled,'stopping headset-free mode keeps XR disabled')
active_tick(); room_allowed=false
for i=1,8 do active_tick() end
check((pawn.PlayMode==0 and pawn.bVRMode) and returns==0,'unknown replicated data keeps controls off without returning too soon')
unsupported=true; active_tick(); active_tick(); active_tick()
check(returns==0,'a known incompatible loadout gets a short replication grace period')
room_allowed=true; unsupported=false; active_tick()
check((pawn.PlayMode==0 and not pawn.bVRMode) and returns==0,'the real CVR plan arriving during grace cancels the return')
room_allowed=false; unsupported=true; online_member=true
for i=1,4 do active_tick() end
check(returns==1 and (pawn.PlayMode==0 and pawn.bVRMode) and not xr_enabled,'a confirmed incompatible match uses Contractors Leave Match')
check(not online_member,'unsupported-match rejection uses the stock online-session cleanup route')
for i=1,8 do active_tick() end
check(returns==1 and (pawn.PlayMode==0 and pawn.bVRMode),'late old-world ticks cannot repeat the return or re-enable controls')
instance.address=2; room_allowed=true; unsupported=false; active_tick()
check((pawn.PlayMode==0 and not pawn.bVRMode),'the new allowed world resumes headset-free controls')
instance.address=3; room_allowed=false; unsupported=true; online_member=true
for i=1,4 do active_tick() end
check(returns==2 and not online_member,'a later incompatible match also uses full session cleanup once')
os, io = native_os, native_io
print(tostring(count) .. ' camera/lease/restoration checks passed')
