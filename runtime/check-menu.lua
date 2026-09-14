local S=require('Settings')
local desktop=S.defaults()
local native_time,now=os.time,0
os.time=function() return now end
S.load=function() return desktop and S.validate(desktop) or nil,'Settings file is not ready.' end
FName=function(v) return {ToString=function() return v end} end
FText=function(v) return v end
local count=0
local function check(v,label) assert(v,label); count=count+1 end
local function obj(v)
    v.IsValid=function() return true end
    v.GetAddress=function() return v.address or 1 end
    v.GetFullName=v.GetFullName or function() return 'MockWidget' end
    v.IsA=function() return true end
    return v
end
local function field(value)
    return obj({value=value,SetText=function(self,v) self.text=v end,SetIsEnabled=function(self,v) self.enabled=v end})
end
local widget=obj({ModeChoice=0,SetVisibility=function(self,v) self.visibility=v end})
for _,name in ipairs({'PlayFlatscreen','BridgeStatus'}) do widget[name]=field() end
local component=obj({GetUserWidgetObject=function() return widget end,SetVisibility=function(self,v) self.visible=v end,
    K2_SetWorldLocationAndRotation=function(self,p,r) self.position,self.rotation=p,r end})
local game_menu=obj({SetActorHiddenInGame=function(self,v) self.hidden=v end})
local pawn=obj({['Menu UI']=game_menu,InputMode=0,ShowMenuUI=function(self) self.InputMode=1 end,HideMenuUI=function(self) self.InputMode=0 end,
    PlayerCamera=obj({K2_GetComponentLocation=function() return {X=0,Y=0,Z=170} end,
        GetForwardVector=function() return {X=1,Y=0,Z=0} end,K2_GetComponentRotation=function() return {Pitch=0,Yaw=0,Roll=0} end})})
local holder=obj({MenuPlaced=true,CVRMenu=component,GetOwner=function() return pawn end})
local holder_end
RegisterHook=function(path,callback)
    assert(path=='/CVRFlatscreen/BP_CVRHolder0.BP_CVRHolder0_C:ReceiveEndPlay')
    holder_end=callback
end
FindAllOf=function(name) return name=='BP_CVRHolder0_C' and {holder} or {} end
local f8=false
local pc=obj({IsInputKeyDown=function() return f8 end})
local supported=true
local plan=obj({GetFullName=function() return supported and require('Room').plan or 'Standard' end})
local game=obj({GetLoadoutPlan=function() return plan end})
local M=require('Menu')
local function tick(ready) now=now+1; return M.update(pawn,pc,game,ready~=false) end
check(not tick(false) and pawn.InputMode==1 and component.visible,'first greeting stays in VR and enables menu input')
check(game_menu.hidden,'popup hides the overlapping game menu')
check(widget.PlayFlatscreen.enabled==false,'flatscreen choice disabled without helper')
check(not tick() and widget.PlayFlatscreen.enabled,'helper readiness alone cannot enable flatscreen')
widget.ModeChoice=1
check(tick() and pawn.InputMode==0 and not component.visible,'choice enables flatscreen and closes menu')
f8=true; tick(); f8=false; tick()
check(pawn.InputMode==1 and component.visible,'F8 reopens settings in the allowed room')
desktop.mouse=3; desktop.keys.E='F'
tick()
check(M.settings.mouse==3 and M.settings.keys.E=='F','desktop save imports mouse and key settings without restarting')
desktop.keys.G='F'; tick()
check(M.settings.keys.G=='G','invalid desktop settings keep the working values')
desktop=nil; tick()
check(M.settings.mouse==3,'a busy settings file keeps the last working values')
desktop=S.defaults(); tick()
check(M.settings.mouse==2.5 and M.settings.keys.E=='E','desktop defaults import automatically')
widget.ModeChoice=2
check(not tick() and pawn.InputMode==0,'VR choice closes the menu and disables flatscreen')
widget.PopupOpen=true; component.visible=true; pawn.InputMode=1
tick(); f8=true; tick(); f8=false; tick()
check(not component.visible and not game_menu.hidden,'a native menu-button opening can be closed and restores the game menu')
widget.ModeChoice=1; tick()
supported=false
check(not tick() and not component.visible,'unsupported loadout immediately disables flatscreen and hides menu')
supported=true
check(not tick(),'returning to the loadout requires a new choice')
widget.ModeChoice=1; tick()
check(not tick(false),'lost helper lease disables flatscreen')
check(not tick(),'renewed helper cannot restore an old choice')
M.on_exit=function() M.clear(pawn) end
holder_end({get=function() return holder end})
check(not tick(),'leaving the holder clears the prior play mode choice')
M.clear(pawn)
check(not component.visible and pawn.InputMode==0,'cleanup releases its menu')
os.time=native_time
print(count..' menu checks pass')
