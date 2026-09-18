-- Counts public Menu.update discovery calls while preserving every access check.
package.loaded.Controls={}
local now,scans,count=0,0,0
os.clock=function() return now end
local function check(value,label) assert(value,label);count=count+1 end
local id=0
local function object(value)
    id=id+1;value.address=id
    value.IsValid=function(self) return not self.invalid end
    value.GetAddress=function(self) return self.address end
    value.GetFullName=function(self) return self.name or tostring(self.address) end
    value.IsA=function() return true end
    return value
end
FName=function(value) return {ToString=function() return value end} end
FText=function(value) return value end
local settings=require('Settings');settings.load=function() local s=settings.defaults();s.experimental_start=true;return s end
local room=require('Room')
local mode=object({name=room.hub_mode})
local supported=true
local plan=object({name=room.plan})
local game=object({GameModeClass=mode,GetLoadoutPlan=function() if mode.name==room.hub_mode then return nil end;return supported and plan or object({name='Standard'}) end})
local pawn=object({InputMode=0})
local pc=object({IsInputKeyDown=function() return false end})
local holders={}
FindAllOf=function(name) scans=scans+1;return name=='BP_CVRHolder0_C' and holders or {} end
RegisterHook=function() end
local menu=require('Menu')
local function tick(ready) return menu.update(pawn,pc,game,ready~=false,true,true) end
for i=1,1200 do now=i/120;assert(tick()) end
check(scans==0,'stock HQ never scans for CVR loadout actors')
check(not tick(false),'HQ helper loss still stops controls immediately')
check(tick(),'HQ resumes with a fresh helper')
mode.name='OtherGameMode';game.address=100
check(tick() and scans==3,'new allowed world scans all three holders once')
for i=1,100 do now=10+i/120;assert(tick()) end
check(scans==3,'missing menus do not rescan every frame')
supported=false;check(not tick(),'unsupported loadout stops controls during discovery backoff');supported=true
check(tick(),'exact plan may resume only with saved Experimental choice and live helper')
local baseline=scans
check(not tick(false) and scans==baseline,'helper loss is enforced during discovery backoff')
game.address=101
check(tick() and scans==baseline+3,'world changes retry immediately despite the previous backoff')
local cls=object({GetFName=function() return FName('WBP_CVRFlatscreen_C') end})
local function field() return object({SetText=function() end,SetIsEnabled=function() end}) end
local widget=object({ModeChoice=0,PlayFlatscreen=field(),PlayVR=field(),BridgeStatus=field(),FlatHUD={}})
widget.GetClass=function() return cls end
widget.IsA=function(_,wanted) return wanted==cls end
local component=object({WidgetClass=cls,GetUserWidgetObject=function() return widget end,
    SetVisibility=function() end,SetCollisionEnabled=function() end})
local holder=object({CVRMenu=component,GetOwner=function() return pawn end})
holders={holder};now=now+.5;tick()
check(menu.hud()==nil and scans==baseline+3,'late replication waits only for the bounded retry')
now=now+.51;tick()
check(menu.hud()==widget.FlatHUD and scans==baseline+4,'late local widget is discovered and validated on retry')
for i=1,200 do now=now+.01;assert(tick()) end
check(scans==baseline+4,'a valid menu uses its existing component without global scans')
check(not tick(false),'helper loss also stops controls after discovery')
widget.ModeChoice=2;menu.update(pawn,pc,game,true,true,false)
check(not menu.update(pawn,pc,game,true,true,false),'explicit VR choice remains off')
print(count..' public menu performance checks pass')
