-- Private desktop display controls. Called only by the existing game-thread tick.
local M={}
local fields={'token','until','action','vsync','fps','mode','width','height'}
local bounds={token={1,9000000000000000},['until']={0,4102444800},vsync={0,1},
    fps={0,500},mode={1,2},width={640,7680},height={480,4320}}
function M.parse(text)
    if type(text)~='string' or #text>1024 then return nil,'Display request is too large.' end
    local result={}
    for line in text:gmatch('[^\r\n]+') do
        local key,value=line:match('^([a-z]+)=([a-z0-9]+)$')
        if not key or result[key]~=nil then return nil,'Bad or repeated display entry.' end
        if key=='action' then
            if value~='apply' and value~='keep' and value~='revert' then return nil,'Bad display action.' end
            result[key]=value
        elseif bounds[key] then
            local n=tonumber(value)
            if not n or n%1~=0 or n<bounds[key][1] or n>bounds[key][2] then return nil,'Bad display value: '..key end
            result[key]=n
        else return nil,'Unknown display entry.' end
    end
    for _,key in ipairs(fields) do if result[key]==nil then return nil,'Missing display entry: '..key end end
    if result.fps>0 and result.fps<20 then return nil,'FPS must be Unlimited or 20 to 500.' end
    return result
end
function M.encode(value)
    local lines={}
    for _,key in ipairs(fields) do lines[#lines+1]=key..'='..tostring(value[key]) end
    local text=table.concat(lines,'\n')..'\n'
    local checked,message=M.parse(text)
    return checked and text or nil,message
end
local folder,last_poll,base,pending,last_token,profile_tried
local state,token,detail='ready',0,'Choose display settings in CVR Link Dev.'
local function read_file(name)
    local file=io.open(folder..name,'r')
    if not file then return end
    local text=file:read(1025);file:close()
    return M.parse(text)
end
local function api()
    local class=StaticFindObject('/Script/Engine.Default__GameUserSettings')
    assert(class and class:IsValid(),'Game display settings are unavailable.')
    local settings=class:GetGameUserSettings()
    assert(settings and settings:IsValid(),'Game display settings are not ready.')
    return settings,StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
end
local function read()
    local settings,system=api()
    local size=settings:GetScreenResolution()
    return {vsync=settings:IsVSyncEnabled() and 1 or 0,fps=settings:GetFrameRateLimit(),
        mode=settings:GetFullscreenMode(),width=size.X,height=size.Y,
        actual_vsync=system:GetConsoleVariableIntValue('r.VSync'),
        actual_fps=system:GetConsoleVariableFloatValue('t.MaxFPS')}
end
local function write(value)
    local settings=api()
    local size=settings:GetScreenResolution()
    local resize=size.X~=value.width or size.Y~=value.height or settings:GetFullscreenMode()~=value.mode
    settings:SetVSyncEnabled(value.vsync==1)
    settings:SetFrameRateLimit(value.fps)
    settings:ApplyNonResolutionSettings()
    if resize then
        settings:SetScreenResolution({X=value.width,Y=value.height})
        settings:SetFullscreenMode(value.mode)
        settings:ApplyResolutionSettings(false) -- Explicit UI choice overrides the launch's -windowed.
    end
    -- CVR Link owns the confirmed profile. Never save temporary modes into the game's INI.
end
local function restore(value)
    write(value)
end
local function publish(now)
    if not folder then return end
    local ok,value=pcall(read)
    local text=now..'|state='..state..'|token='..token..'|deadline='..(pending and pending.deadline or 0)
    if ok then
        for _,key in ipairs({'vsync','fps','mode','width','height','actual_vsync','actual_fps'}) do
            text=text..'|'..key..'='..tostring(value[key])
        end
    end
    text=text..'|message='..detail:gsub('[|\r\n]',' ')..'\n'
    local file=io.open(folder..'display-status.txt','w')
    if file then file:write(text);file:close() end
end
local function revert(message)
    if pending then restore(pending.previous);pending=nil end
    state,detail='reverted',message
end
function M.stop()
    local ok,message=pcall(function()
        if base then restore(base);base=nil end
        pending=nil
    end)
    profile_tried=false
    state,detail=ok and 'paused' or 'error',ok and 'Display settings paused; original game values restored.' or tostring(message)
    publish(os.time())
end
local function apply(request,now,saved)
    token=request.token
    local previous=read()
    local settings=api()
    local desktop=settings:GetDesktopResolution()
    if request.mode==1 then request.width,request.height=desktop.X,desktop.Y end
    assert(request.width<=desktop.X and request.height<=desktop.Y,'Choose a resolution that fits this monitor.')
    if request.mode==2 then
        assert(request.width<=desktop.X-16 and request.height<=desktop.Y-64,'Choose a smaller window or use Borderless.')
    end
    base=base or previous
    local ok,message=pcall(function()
        write(request)
        local current=read()
        assert(current.actual_vsync==request.vsync,'V-Sync is overridden by another game setting.')
        assert(math.abs(current.actual_fps-request.fps)<.01,'FPS limit is overridden by another game setting.')
    end)
    if not ok then restore(previous);error(message) end
    token=request.token
    if not saved and (previous.mode~=request.mode or previous.width~=request.width or previous.height~=request.height) then
        pending={previous=previous,deadline=now+15}
        state,detail='confirm','Keep this display mode? It will revert in 15 seconds.'
    else
        state,detail='applied','Display settings applied.'
    end
end
function M.tick(path,ready,headset_free)
    folder=path
    local now=os.time()
    if last_poll==now then return end
    last_poll=now
    local ok,message=pcall(function()
        if not ready or not headset_free then
            if base then M.stop() end
            profile_tried=false
            state,detail='paused',headset_free and 'Enable CVR Link to apply PC display settings.' or 'PC display settings need a headset-free start.'
            return
        end
        if pending and now>=pending.deadline then revert('Display change timed out. Previous settings restored.') end
        local request,parse_error=read_file('display-request.ini')
        if parse_error then state,detail='error',parse_error end
        if request and (request['until']==0 or request['until']>=now and request['until']<=now+60) then
            if request.action=='apply' and request.token~=last_token then
                if pending then revert('Previous preview cancelled.') end
                last_token=request.token
                profile_tried=true
                apply(request,now,false)
            elseif pending and request.token==token and request.action=='keep' then
                pending=nil;state,detail='applied','Display settings applied.'
            elseif pending and request.token==token and request.action=='revert' then
                revert('Previous display settings restored.')
            end
        end
        if not profile_tried then
            profile_tried=true
            local profile=read_file('display.ini')
            if profile then apply(profile,now,true) end
        end
    end)
    if not ok then
        if pending then pcall(revert,'Display preview failed; previous settings restored.') end
        state,detail='error',tostring(message)
        print('[CVRDisplay] '..detail..'\n')
    end
    publish(now)
end
return M
