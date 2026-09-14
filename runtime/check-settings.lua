local S=require('Settings')
local count=0
local function check(v,message) assert(v,message); count=count+1 end
local defaults=S.defaults()
check(S.validate(defaults),'defaults are valid')
local text=assert(S.encode(defaults))
check(assert(S.encode(assert(S.parse(text))))==text,'settings round trip')
defaults.keys.E='F'
defaults.mouse=4
check(assert(S.parse(assert(S.encode(defaults)))).keys.E=='F','rebind saved')
defaults.keys.G='F'
check(not S.validate(defaults),'duplicate key rejected')
for _,bad in ipairs({'F7','F8','Escape','Gamepad_FaceButton_Bottom','None','../x',''}) do
    local v=S.defaults(); v.keys.E=bad
    check(not S.validate(v),'bad key rejected: '..bad)
end
for _,bad in ipairs({0,11,-1,math.huge,0/0}) do
    local v=S.defaults(); v.mouse=bad
    check(not S.validate(v),'invalid mouse speed rejected')
end
for _,bad in ipairs({'mouse=2\nmouse=3','unknown=W','mouse=nope','E=os.execute(x)',string.rep('x',8193)}) do
    check(not S.parse(bad),'bad settings text rejected')
end
check(S.defaults().keys.E=='E','defaults do not share key tables')
local old=assert(S.parse('mouse=0.8\naim=1\n'))
check(old.mouse==.8 and old.ui_scale==1 and old.ui_opacity==1,'old files retain mouse speed and get default HUD settings')
local ui=S.defaults(); ui.ui_scale=.75; ui.ui_opacity=.6
local saved=assert(S.parse(assert(S.encode(ui))))
check(saved.ui_scale==.75 and saved.ui_opacity==.6,'HUD size and opacity round trip')
for _,bad in ipairs({'ui_scale=nope','ui_opacity=nope','ui_scale=0.49','ui_scale=1.51','ui_opacity=0.09','ui_opacity=1.01','ui_scale=1\nui_scale=1'}) do
    check(not S.parse(bad),'bad HUD setting rejected: '..bad)
end
if arg[1] then
    local file=assert(io.open(arg[1],'r'))
    local gui=file:read('*a'); file:close()
    check(S.encode(assert(S.parse(gui)))==gui,'CVR Link writes exactly the format the game imports')
end
print(count..' settings checks pass')
