-- Run with Lua 5.4. Tests the lease and restoration behavior without a game.
local now, lease, begin_play, post_tick, travel = 100, 0
local unreadable, read_error = false, false
local mouse_x, mouse_y = 0, 0
local camera_rotation = {Pitch=10,Yaw=179,Roll=25}
local restored_pose, written_location, controller_rotation
local function copy(v)
    local result = {}
    for k,value in pairs(v) do result[k]=value end
    return result
end
local count = 0
local function object(values)
    values.IsValid = function() return true end
    values.IsLocallyControlled = function() return true end
    values.IsA = function() return true end
    values.GetFName = function() return {ToString=function() return 'MockPawn' end} end
    values.GetAddress = function() return 1 end
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
local hmd=object({IsHeadMountedDisplayEnabled=function() return xr_enabled end,
    EnableHMD=function(_,value) xr_enabled=value; return true end})
local pawn = object({PlayerCamera=camera,PlayMode=0,bVRMode=true})
local pc = object({
    IsLocalController=function() return true end,
    GetInputAnalogKeyState=function(_,key) return key.KeyName=='MouseX' and mouse_x or mouse_y end,
    IsInputKeyDown=function() return false end,
    SetControlRotation=function(_,rotation) controller_rotation=copy(rotation) end})
StaticFindObject = function(path)
    if path:find('HeadMountedDisplay') then return hmd end
    return object({
    GetGameInstance=function() return instance end,GetGameState=function() return instance end,
    GetPlayerController=function() return pc end}) end
FName = function(value) return value end
RegisterBeginPlayPostHook = function(callback) begin_play=callback end
RegisterHook = function(path,callback,third)
    assert(not path:find('GameplayStatics:',1,true),'UE4SS 3.0.1 cannot hook static Blueprint libraries')
    if path:find('PlayerController:',1,true) then
        if path:find(':ClientTravelInternal',1,true) then travel=function() callback({get=function() return pc end}) end end
        assert(third==nil,'travel restoration must run before travel')
        return
    end
    if path:sub(1,8)=='/Script/' then assert(third,'native hook requires a post callback'); return end
    assert(path:sub(1,6)=='/Game/' and third==nil, 'Blueprint hook callback must be argument two')
    if path:find('CS_Character') then post_tick=callback end
end
local native_os, native_io = os, io
package.loaded.Controls={start=function() end,stop=function() end,tick=function() end,status=function() return '' end,configure=function() end,
    hud_state=function() return false,false end,
    wants_look=function() return pawn.InputMode~=1 end}
local room_allowed=true
package.loaded.Menu={settings={mouse=2.5,aim=1,keys={RightMouseButton='RightMouseButton'}},
    hud=function() return nil end,
    update=function(_,_,_,ready) return ready and room_allowed end,
    clear=function() room_allowed=false end,status=function() return '' end}
os = {getenv=function() return 'mock' end, time=function() return now end, clock=function() return now end}
io = {open=function(path, mode)
    if mode=='r' and unreadable then return nil,'busy' end
    return {read=function()
        if read_error then return nil,'read failed' end
        return lease and tostring(lease) or nil
    end,write=function() end,close=function() end}
end}
dofile('main.lua')
begin_play({get=function() return pawn end})
assert(post_tick, 'character tick must be registered')
local function tick() now=now+1; post_tick({get=function() return pawn end}) end
local function check(condition, label) assert(condition,label); count=count+1 end
tick()
check(pawn.PlayMode==0 and camera.bLockToHmd, 'inactive startup preserves VR')
lease=now+3
tick()
check(pawn.PlayMode==1 and instance.PlayMode==1, 'valid lease activates native pancake mode')
check(not camera.bLockToHmd and not camera.bAutoSetLockToHmd, 'active camera ignores HMD')
check(not camera.bUsePawnControlRotation, 'camera excludes headset-derived controller rotation')
check(not xr_enabled, 'activation disables native HMD/stereo rendering')
check(camera_rotation.Roll==0, 'activation levels a tilted horizon')
check(written_location.X==10 and written_location.Y==2 and written_location.Z==170, 'activation retains camera position')
unreadable=true
tick()
check(pawn.PlayMode==1, 'transient open failure keeps the unexpired lease')
tick()
check(pawn.PlayMode==0 and instance.PlayMode==0, 'continued read failures cannot extend expiry')
check(camera.bLockToHmd and camera.bAutoSetLockToHmd and not camera.bUsePawnControlRotation, 'expiry restores camera flags')
check(restored_pose.position.X==10 and restored_pose.rotation.Roll==3, 'expiry restores original camera pose')
check(xr_enabled, 'expiry restores previously-enabled native HMD')
unreadable=false
lease=now+100
tick()
check(pawn.PlayMode==0, 'far-future lease cannot latch activation')
lease=now+3
tick()
check(pawn.PlayMode==1, 'fresh lease can reactivate')
read_error=true
tick()
check(pawn.PlayMode==1, 'transient read error retains the original deadline')
read_error=false
lease=0
tick()
check(pawn.PlayMode==0 and camera.bLockToHmd, 'explicit off restores original settings')
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
check(pawn.PlayMode==0, 'malformed readable lease clears active mode immediately')
active_tick()
lease=nil
tick()
check(pawn.PlayMode==0, 'empty readable file clears active mode immediately')
active_tick()
lease=now+100
tick()
check(pawn.PlayMode==0, 'far-future value clears an already-active lease')
-- An incompatible property fails activation, restores partial changes, and stays off.
active_tick()
room_allowed=false
active_tick()
check(pawn.PlayMode==0 and xr_enabled,'a valid lease cannot keep flatscreen active outside the loadout')
room_allowed=true
active_tick()
travel()
check(pawn.PlayMode==0 and xr_enabled,'map travel restores VR before leaving the old world')
active_tick()
check(pawn.PlayMode==0,'map travel clears the previous room choice')
room_allowed=true
camera.bAutoSetLockToHmd=nil
lease=now+3
tick()
check(pawn.PlayMode==0 and instance.PlayMode==0, 'partial activation failure restores already-written fields')
camera.bAutoSetLockToHmd=true
lease=now+3
tick()
check(pawn.PlayMode==0, 'error latches off until restart')
os, io = native_os, native_io
print(tostring(count) .. ' camera/lease/restoration checks passed')
