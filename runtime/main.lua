-- Startup-only experimental bridge. All UObject access stays on the game thread.
local folder = assert(os.getenv('LOCALAPPDATA')) .. '/ContractorsFlatscreen/'
local gameplay = StaticFindObject('/Script/Engine.Default__GameplayStatics')
local system = StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
local hmd = StaticFindObject('/Script/HeadMountedDisplay.Default__HeadMountedDisplayFunctionLibrary')
local controls = require('Controls')
local menu = require('Menu')
local hud = require('HUD')
local snapshot, hooked, last_poll, last_report = nil, false, -1, 0
local failed = false
local active_pawn, view, original_pose
local previous_hmd
local headset_free,denied_world,denied_since,returned_world
local lease_deadline, read_misses, activations, restorations = 0, 0, 0, 0
local function valid(o) return o and o:IsValid() end
local function vector(v) return {X=v.X,Y=v.Y,Z=v.Z} end
local function rotation(v) return {Pitch=v.Pitch,Yaw=v.Yaw,Roll=v.Roll} end
local function axis(pc, name) return pc:GetInputAnalogKeyState({KeyName=FName(name)}) end
local function report(message)
    local file = io.open(folder .. 'status.txt', 'w')
    if file then file:write(tostring(os.time()), '|', message, '\n'); file:close() end
end
local function restore(reason)
    hud.stop()
    if not snapshot then return end
    local controls_ok, controls_error = pcall(controls.stop)
    if original_pose and valid(original_pose.camera) then
        original_pose.camera:K2_SetRelativeLocationAndRotation(original_pose.position, original_pose.rotation, false, {}, true)
    end
    for i = #snapshot, 1, -1 do
        local item = snapshot[i]
        if valid(item[1]) then item[1][item[2]] = item[3] end
    end
    if previous_hmd~=nil and valid(hmd) then hmd:EnableHMD(previous_hmd) end
    previous_hmd=nil
    snapshot = nil
    active_pawn, view, original_pose = nil, nil, nil
    restorations = restorations + 1
    print('[Flatscreen] restored original properties: ' .. tostring(reason) .. '\n')
    if not controls_ok then error('input restoration error: '..tostring(controls_error)) end
end
local function set(o, name, value)
    assert(valid(o), 'missing object for ' .. name)
    local previous = o[name]
    assert(previous ~= nil, 'missing property ' .. name)
    snapshot[#snapshot+1] = {o, name, previous}
    o[name] = value
    assert(o[name] == value, 'property readback failed: ' .. name)
end
local function activate(pawn)
    snapshot = {}
    if not controls.start(pawn) then snapshot=nil; return end
    local camera = pawn.PlayerCamera
    active_pawn = pawn
    view = rotation(camera:K2_GetComponentRotation())
    view.Roll = 0
    original_pose = {camera=camera,position=vector(camera.RelativeLocation),rotation=rotation(camera.RelativeRotation)}
    assert(valid(hmd), 'HMD function library unavailable')
    previous_hmd=hmd:IsHeadMountedDisplayEnabled()
    if previous_hmd then
        assert(hmd:EnableHMD(false), 'could not disable stereo rendering')
        assert(not hmd:IsHeadMountedDisplayEnabled(), 'HMD disable readback failed')
    end
    local instance = gameplay:GetGameInstance(pawn)
    set(instance, 'PlayMode', 1)
    set(pawn, 'PlayMode', 1)
    set(pawn, 'bVRMode', false)
    set(camera, 'bAutoSetLockToHmd', false)
    set(camera, 'bLockToHmd', false)
    set(camera, 'bUsePawnControlRotation', false)
    activations = activations + 1
    print('[Flatscreen] experimental pancake camera ON; original settings captured\n')
end
local function tick(context)
    if failed then return end
    local ok, reason = xpcall(function()
        local pawn = context:get()
        if not valid(pawn) or not pawn:IsLocallyControlled() then return end
        local now = os.clock()
        if snapshot and (not valid(active_pawn) or active_pawn:GetAddress() ~= pawn:GetAddress()) then restore('pawn changed') end
        if now < last_poll or now - last_poll >= .1 then
            last_poll = now
            local wall_time = os.time()
            local file = io.open(folder .. 'control.txt', 'r')
            if file then
                local content, read_error = file:read(32)
                file:close()
                if read_error then
                    read_misses = read_misses + 1
                else
                    local deadline = tonumber(content) or 0
                    lease_deadline = deadline > wall_time and deadline <= wall_time+3 and deadline or 0
                end
            else
                read_misses = read_misses + 1
            end
            -- Atomic Windows replacement can briefly deny reads. Keep only the last
            -- validated lease, without extending it; explicit off still clears it.
        end
        local pc = gameplay:GetPlayerController(pawn, 0)
        local camera = pawn.PlayerCamera
        local ready=lease_deadline>os.time() and lease_deadline<=os.time()+3
        local game=gameplay:GetGameState(pawn)
        local standalone=system:IsStandalone(pawn)
        if headset_free==nil then
            -- Capture before our first EnableHMD(false). The shipping game's
            -- GetCommandLine no longer contains the original Steam launch flags.
            headset_free=not hmd:IsHeadMountedDisplayConnected()
        end
        local enabled,unsupported=menu.update(pawn,pc,game,ready,standalone,headset_free)
        if enabled and not snapshot then activate(pawn) end
        if not enabled and snapshot then restore('VR selected, unsupported room, or helper off') end
        local world=valid(game) and game:GetFullName() or nil
        if world and returned_world~=world then returned_world=nil end
        if headset_free and unsupported then
            if denied_world~=world then denied_world,denied_since=world,os.time() end
            -- Keep controls off while replication settles. Use Contractors' own
            -- Leave Match action once per world: the engine's generic return
            -- changes maps without clearing the game's online lobby membership.
            if returned_world~=world and os.time()-denied_since>=3 then
                returned_world=world
                report('RETURNING|headset_free=true|reason=This match needs the CVRFlatscreen loadout')
                print('[Flatscreen] unsupported loadout; returning headset-free player to HQ\n')
                pc:ClientLeaveGame()
                return -- Travel may invalidate every object captured above.
            end
        else denied_world,denied_since=nil,nil end
        if returned_world then return end
        if snapshot then
            controls.configure(menu.settings.keys,menu.settings.fov)
            local sensitivity=menu.settings.mouse
            if pc:IsInputKeyDown({KeyName=FName(menu.settings.keys.RightMouseButton)}) and pawn.InputMode==0 then
                sensitivity=sensitivity*menu.settings.aim
            end
            local dx,dy=axis(pc,'MouseX')*sensitivity,axis(pc,'MouseY')*sensitivity
            if controls.wants_look(pawn) then
                view.Yaw = (view.Yaw + dx + 180) % 360 - 180
                view.Pitch = math.max(-85,math.min(85,view.Pitch + dy))
            end
            pc:SetControlRotation(view)
            camera:K2_SetRelativeLocation(original_pose.position,false,{},true)
            camera:K2_SetWorldRotation(view,false,{},true)
            controls.tick(pawn,pc,camera,view,dx,dy)
            hud.update(menu.hud(),pawn,menu.settings,controls.hud_state())
        end
        if last_report ~= os.time() then
            last_report = os.time()
            local rot = camera:K2_GetComponentRotation()
            report((snapshot and 'ON' or enabled and 'WAITING' or 'OFF') .. '|pawn=' .. pawn:GetFName():ToString()
                .. '|mode=' .. tostring(pawn.PlayMode) .. '|hmd=' .. tostring(camera.bLockToHmd)
                .. '|xr=' .. tostring(hmd:IsHeadMountedDisplayEnabled())
                .. '|headset_free=' .. tostring(headset_free)
                .. '|rotation=' .. tostring(rot.Pitch) .. ',' .. tostring(rot.Yaw) .. ',' .. tostring(rot.Roll)
                .. '|mouse=' .. tostring(axis(pc,'MouseX'))
                .. '|activations=' .. activations .. '|restorations=' .. restorations .. '|read_misses=' .. read_misses
                .. '|standalone=' .. tostring(standalone)
                .. '|game_mode=' .. (valid(game) and valid(game.GameModeClass) and game.GameModeClass:GetFullName() or 'unknown')
                .. menu.status() .. controls.status())
        end
    end,function(reason) return debug.traceback(tostring(reason),2) end)
    if not ok then
        failed = true
        local restored, restore_error = pcall(restore, 'error')
        local message = 'ERROR|' .. tostring(reason) .. '|hud=' .. tostring(hud.stage) .. (restored and '' or '|restore=' .. tostring(restore_error))
        report(message)
        print('[Flatscreen] ' .. message .. '\n')
    end
end
-- UE4SS 3.0.1's LoadMap pre-wrapper pushes five arguments but calls with four.
-- Use controller travel entry points; the broken wrapper crashes before our Lua runs.
-- Do not hook GameplayStatics.OpenLevel: 3.0.1 also breaks static library hooks
-- (UE4SS issue #467), crashing when the Free Roam start button calls it.
local function before_travel()
    local ok,reason=pcall(function()
        menu.clear(active_pawn,true)
        restore('map travel')
        lease_deadline=0
    end)
    if not ok then failed=true; report('ERROR|map restoration: '..tostring(reason)) end
end
-- Non-destruction holder exits cover unloads outside controller travel calls.
-- Death/replacement keeps the match choice; menu.update still checks the plan.
menu.on_exit=before_travel
for _,name in ipairs({'ClientTravel','ClientTravelInternal','ClientReturnToMainMenu','ClientReturnToMainMenuWithTextReason'}) do
    RegisterHook('/Script/Engine.PlayerController:'..name,function(context)
        local pc=context:get()
        if valid(pc) and pc:IsLocalController() then before_travel() end
    end)
end
-- Contractors has its own leave-session RPC as well as the engine travel calls.
-- Restore while its current pawn, HUD and controls still exist.
RegisterHook('/Script/ZomboyVR.ZomboyPlayerController:ClientLeaveGame',function(context)
    local pc=context:get()
    if valid(pc) and pc:IsLocalController() then before_travel() end
end)
local function capture_recoil(context,...)
    if failed or not snapshot or lease_deadline<=os.time() then return end
    local args=table.pack(...)
    local ok,reason=pcall(function()
        local modifier=context:get()
        if not valid(modifier) or not modifier:IsA('/Script/ZomboyVR.ZomboyGunRecoilTransformModifier') then return end
        assert(args.n==5,'unexpected native recoil arguments')
        controls.capture_recoil(args[4]:get(),args[5]:get(),args[1]:get())
    end)
    if not ok then
        failed=true
        local restored,restore_error=pcall(restore,'weapon pose error')
        report('ERROR|'..tostring(reason)..(restored and '' or '|restore='..tostring(restore_error)))
        print('[Flatscreen] weapon pose error: '..tostring(reason)..'\n')
    end
end
RegisterBeginPlayPostHook(function(context)
    local pawn = context:get()
    if hooked or not valid(pawn) or not pawn:IsA('/Script/ZomboyVR.ZomboyVRCharacter') then return end
    local ok, reason = pcall(function()
        -- Blueprint hooks use argument two as the post callback; argument three is ignored.
        RegisterHook('/Game/Core/Player/CS_Character.CS_Character_C:ReceiveTick', tick)
        RegisterHook('/Script/ZomboyVR.ZomboyTransformModifier:ModifyInteractableTransform',function() end,capture_recoil)
        RegisterHook('/Script/ZomboyVR.ZomboyInteractableActor:ModifyGrabTransform',function() end,function(context,...)
            if failed or not snapshot or lease_deadline<=os.time() then return end
            local args=table.pack(...)
            local ok,reason=pcall(function()
                assert(args.n==2,'unexpected native grab-transform arguments')
                controls.apply_utility_grab(context:get(),args[1]:get())
            end)
            if not ok then
                failed=true
                pcall(restore,'utility pose error')
                report('ERROR|'..tostring(reason))
                print('[Flatscreen] utility pose error: '..tostring(reason)..'\n')
            end
        end)
        hooked = true
        print('[Flatscreen] character tick hook ready\n')
    end)
    if not ok then failed=true; hooked=true; report('ERROR|' .. tostring(reason)); print('[Flatscreen] ' .. tostring(reason) .. '\n') end
end)
report('LOADED|waiting for local character')
print('[Flatscreen] loaded; exact CVRFlatscreen loadout required in matches; Experimental permits local HQ\n')
