local M=dofile('Display.lua')
local count=0
local function check(value,message) assert(value,message);count=count+1 end
local request={token=123,['until']=0,action='apply',vsync=1,fps=60,mode=1,width=1920,height=1080}
local encoded=assert(M.encode(request))
check(M.parse(encoded).fps==60,'display settings round trip')
for _,bad in ipairs({encoded..'fps=60\n',encoded..'code=run\n',encoded:gsub('fps=60','fps=19'),
    encoded:gsub('fps=60','fps=501'),encoded:gsub('mode=1','mode=0'),encoded:gsub('vsync=1','vsync=2'),
    encoded:gsub('width=1920','width=10'),encoded:gsub('height=1080','height=99999'),
    encoded:gsub('token=123','token=0'),encoded:gsub('action=apply','action=execute'),
    encoded:gsub('until=0','until=9999999999999999'),encoded:gsub('vsync=1','vsync=1.0'),
    encoded:gsub('fps=60\n',''),string.rep('a',1025)}) do check(not M.parse(bad),'reject invalid display request') end
if arg[1] then
    local f=assert(io.open(arg[1],'r'));local value=assert(M.parse(f:read('*a')));f:close()
    check(value.fps==60 and value.width==1280,'native GUI settings accepted by runtime')
end
local native={vsync=false,fps=0,mode=2,width=1280,height=720}
local actual={vsync=0,fps=0}
local writes,override=0,false
local settings={IsValid=function() return true end,
    GetScreenResolution=function() return {X=native.width,Y=native.height} end,
    GetDesktopResolution=function() return {X=1920,Y=1080} end,
    GetFullscreenMode=function() return native.mode end,IsVSyncEnabled=function() return native.vsync end,
    GetFrameRateLimit=function() return native.fps end,
    SetVSyncEnabled=function(_,v) native.vsync=v;writes=writes+1 end,
    SetFrameRateLimit=function(_,v) native.fps=v end,
    SetScreenResolution=function(_,v) native.width,native.height=v.X,v.Y end,
    SetFullscreenMode=function(_,v) native.mode=v end,
    ApplyNonResolutionSettings=function() actual.fps=native.fps;if not override then actual.vsync=native.vsync and 1 or 0 end end,
    ApplyResolutionSettings=function(_,cmd) assert(cmd==false,'launch flags must not override explicit UI mode') end}
StaticFindObject=function(path)
    if path:find('KismetSystemLibrary',1,true) then return {
        GetConsoleVariableIntValue=function() return actual.vsync end,GetConsoleVariableFloatValue=function() return actual.fps end} end
    return {IsValid=function() return true end,GetGameUserSettings=function() return settings end}
end
local files,now={},100
local real_open,real_time=io.open,os.time
os.time=function() return now end
io.open=function(path,mode)
    if mode=='r' then
        if not files[path] then return nil end
        return {read=function(_,n) return files[path]:sub(1,n) end,close=function() end}
    end
    return {write=function(_,text) files[path]=text end,close=function() end}
end
local function status(s) return files['test/display-status.txt']:find('|state='..s..'|',1,true) end
local function tick(ready,headset) now=now+1;M.tick('test/',ready~=false,headset~=false) end
local function send(changes)
    for key,value in pairs(changes or {}) do request[key]=value end
    files['test/display-request.ini']=assert(M.encode(request))
end
send();tick(false);check(writes==0,'disabled link cannot apply')
tick(true,false);check(writes==0,'normal VR start cannot apply desktop settings')
tick();check(native.mode==1 and actual.vsync==1 and actual.fps==60 and status('confirm'),'live desktop settings apply with confirmation')
send({token=124,action='keep'});tick();check(status('confirm'),'wrong confirmation token ignored')
send({token=123,action='keep'});tick();check(status('applied'),'matching confirmation accepted')
files['test/display.ini']=encoded;files['test/display-request.ini']=nil
tick(false);check(native.mode==2 and not native.vsync and actual.fps==0,'helper loss restores baseline')
tick();check(native.mode==1 and native.fps==60 and status('applied'),'confirmed profile reapplies on enable')
send({token=125,action='apply',mode=2,width=1280,height=720,fps=30});tick()
check(status('confirm') and native.fps==30,'new window previews')
now=now+15;tick();check(status('reverted') and native.mode==1 and native.fps==60,'timeout restores complete prior profile')
local before=writes;tick();check(writes==before,'timed-out request cannot replay')
send({token=126});tick();send({action='revert'});tick()
check(status('reverted') and native.mode==1,'explicit revert restores previous mode')
send({token=127,action='apply'});tick();tick(false)
check(native.mode==2 and native.fps==0,'helper loss during preview restores original baseline')
files['test/display-request.ini']=nil;tick()
send({token=128,action='apply',['until']=now-1});before=writes;tick();check(writes==before,'expired request ignored')
send({token=129,['until']=now+999});tick();check(writes==before,'far-future live request ignored')
send({token=130,['until']=0,width=7680,height=4320});tick()
check(status('error') and native.mode==1,'oversized window rejected before mutation')
send({token=131,width=1280,height=720,mode=1,vsync=0});override=true;tick()
check(status('error') and native.vsync and native.fps==60,'override failure rolls back all settings')
override=false;send({token=132,mode=1,vsync=1,fps=90});tick()
check(status('applied') and actual.fps==90,'FPS-only change applies without a resolution prompt')
M.stop();check(native.fps==0 and native.mode==2,'stop restores original settings')
io.open,os.time=real_open,real_time
print('Display: '..count..' checks passed.')
