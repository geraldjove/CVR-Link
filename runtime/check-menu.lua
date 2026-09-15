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
    v.IsValid=function() return v.valid~=false end
    v.GetAddress=function() return v.address or 1 end
    v.GetFullName=v.GetFullName or function() return 'MockObject '..(v.address or 1) end
    v.IsA=function() return true end
    return v
end
local function field(value)
    return obj({value=value,SetText=function(self,v) self.text=v end,SetIsEnabled=function(self,v) self.enabled=v end})
end
local component
local path_lookup_ready=true
local function new_widget()
    local cls=obj({name='WBP_CVRFlatscreen_C',GetFName=function(self) return FName(self.name) end,
        GetFullName=function(self) return 'WidgetBlueprintGeneratedClass /CVRFlatscreen/WBP_CVRFlatscreen.'..self.name end})
    local widget=obj({ModeChoice=0,SetVisibility=function(self,v) self.visibility=v end})
    widget.GetClass=function() return cls end
    widget.IsA=function(_,wanted)
        return wanted==cls or (path_lookup_ready and wanted=='/CVRFlatscreen/WBP_CVRFlatscreen.WBP_CVRFlatscreen_C')
    end
    for _,name in ipairs({'PlayFlatscreen','PlayVR','BridgeStatus'}) do widget[name]=field() end
    widget.PlayFlatscreen.enabled=false
    widget.FlatHUD=obj({})
    if component then component.WidgetClass=cls end
    return widget
end
local widget=new_widget()
component=obj({WidgetClass=widget:GetClass(),GetUserWidgetObject=function() return widget end,SetVisibility=function(self,v) self.visible=v end,
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
local holders_ready=true
FindAllOf=function(name) return holders_ready and name=='BP_CVRHolder0_C' and {holder} or {} end
local f8=false
local pc=obj({IsInputKeyDown=function() return f8 end})
local supported=true
local plan=obj({GetFullName=function() return supported and require('Room').plan or 'Standard' end})
local game=obj({GetLoadoutPlan=function() return plan end})
local M=require('Menu')
local standalone,headset_free=false,false
local function tick(ready) now=now+1; return M.update(pawn,pc,game,ready~=false,standalone,headset_free) end
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
local function ending(actor,reason)
    holder_end({get=function() return actor end},{get=function() return reason end})
end
widget.ModeChoice=1; tick()
local other=obj({address=99})
ending(other,0)
check(tick() and M.hud()==widget.FlatHUD,'another player death cannot change the local choice or HUD')
ending(other,1)
check(tick(),'another player unload cannot clear the local choice')
for death=1,3 do
    local old_holder,old_widget=holder,widget
    f8=true; tick(); f8=false; tick()
    ending(holder,0)
    check(not component.visible and pawn.InputMode==0 and not game_menu.hidden,
        'death closes the old popup and restores the game menu')
    holders_ready=false; old_widget.valid=false
    check(tick() and not M.hud(),'flatscreen survives the respawn gap without the old HUD')
    pawn=obj({address=death+10,InputMode=0,['Menu UI']=game_menu,PlayerCamera=pawn.PlayerCamera,
        ShowMenuUI=pawn.ShowMenuUI,HideMenuUI=pawn.HideMenuUI})
    check(tick(),'the replacement pawn keeps the match choice before a holder exists')
    widget=new_widget()
    holder=obj({address=death+20,MenuPlaced=false,CVRMenu=component,GetOwner=function() return pawn end})
    holders_ready=true
    check(tick() and M.hud()==widget.FlatHUD and not component.visible,'respawn binds the new local HUD without asking again')
    -- The stock holder opens its popup after its one-second spawn delay.
    holder.MenuPlaced=true; widget.PopupOpen=true; component.visible=true; pawn.InputMode=1; game_menu.hidden=true
    check(tick() and not component.visible and pawn.InputMode==0 and not game_menu.hidden,
        'the delayed Blueprint greeting closes while flatscreen continues')
    ending(old_holder,1)
    check(tick(),'a late exit from the old holder cannot clear the respawn choice')
end
ending(holder,0)
widget=new_widget(); widget.PopupOpen=true; component.visible=true; pawn.InputMode=1; game_menu.hidden=true
check(tick() and pawn.InputMode==0 and not component.visible and not game_menu.hidden,
    'a replacement popup already opened by Blueprint closes without trapping menu input')
widget.ModeChoice=2; tick()
ending(holder,0); holders_ready=false
check(not tick(),'a VR choice also persists through death')
holders_ready=true; widget=new_widget(); tick()
check(not tick() and not component.visible,'respawn does not reopen the prompt after a VR choice')
widget.ModeChoice=1; tick()
ending(holder,0); holders_ready=false
check(not tick(false),'link loss clears the choice even while the respawn widget is absent')
check(not tick(),'reopening the link during respawn cannot reuse an expired choice')
holders_ready=true; widget=new_widget(); tick()
widget.ModeChoice=1; tick()
ending(holder,0); holders_ready=false; supported=false
check(not tick(),'changing loadouts during respawn revokes flatscreen')
supported=true; holders_ready=true; widget=new_widget()
check(not tick(),'returning to the loadout after death requires a new choice')
widget.ModeChoice=1; tick(); game.address=200
check(not tick(),'a new match clears the choice even with a live helper')
for reason=1,4 do
    widget.ModeChoice=1; tick()
    ending(holder,reason)
    check(not tick(),'world unload reason '..reason..' clears the prior play mode choice')
end
M.clear(pawn)
check(not component.visible and pawn.InputMode==0,'cleanup releases its menu')
-- The live rejoin finds our widget but its global string IsA lookup fails.
path_lookup_ready=false
for match=1,3 do
    game.address=300+match
    widget=new_widget()
    check(not tick() and widget.PlayFlatscreen.enabled and M.hud()==widget.FlatHUD,
        'rejoining match '..match..' enables the current popup with a live link despite failed path lookup')
    widget.ModeChoice=1
    check(tick() and pawn.InputMode==0,'the new match can select flatscreen')
    widget.ModeChoice=2
    check(not tick() and pawn.InputMode==0,'the new match can return to VR')
    widget.ModeChoice=1; tick()
    ending(holder,1)
    check(not M.hud(),'leaving flatscreen releases the old match widget')
end
widget=new_widget()
check(not tick(false) and not widget.PlayFlatscreen.enabled,'rejoin cannot enable the button without a live link')
check(not tick() and widget.PlayFlatscreen.enabled,'link recovery enables the new match button without choosing for the player')
M.clear(pawn); widget=new_widget(); widget:GetClass().name='UnrelatedMenu_C'
check(not tick() and not M.hud() and not widget.PlayFlatscreen.enabled,'unrelated configured widget classes are rejected')
widget=new_widget()
component.WidgetClass=obj({GetFName=function() return FName('WBP_CVRFlatscreen_C') end})
check(not tick() and not M.hud(),'an instance that does not match the configured component class is rejected')
widget=new_widget(); supported=false
check(not tick() and not M.hud() and not widget.PlayFlatscreen.enabled,'direct widget class matching cannot bypass the exact loadout plan')
desktop.experimental_start=true; standalone=true
game.GameModeClass=obj({GetFullName=function() return require('Room').hub_mode end})
holders_ready=false
check(tick() and not M.hud() and M.status():find('|experimental_hq=true',1,true),'saved Experimental starts flatscreen in the local HQ without a loadout widget')
check(not tick(false),'HQ flatscreen still needs a live link')
check(tick(),'Experimental HQ resumes when the link returns')
standalone=false
check(not tick(),'joining a non-CVR server returns Experimental HQ to VR')
supported=true; holders_ready=true; widget=new_widget(); game.address=500
check(tick() and not component.visible and pawn.InputMode==0,'Experimental continues into CVRFlatscreen without another mode prompt')
widget.ModeChoice=2
check(not tick() and not tick(),'Play in VR stays selected while Experimental is enabled')
widget.ModeChoice=1; tick()
M.clear(pawn,true); M.clear(pawn,true)
check(not tick(),'repeated travel cleanup still blocks late old-world ticks')
game.address=501; widget=new_widget()
check(tick(),'Experimental auto-selects in the next CVRFlatscreen match')
desktop.experimental_start=false
check(not tick(),'saving Experimental off releases the automatic match choice')
headset_free=true; desktop.experimental_start=true; game.address=502; widget=new_widget()
check(tick() and widget.PlayVR.enabled==false and widget.PlayFlatscreen.enabled,'headset-free start offers the usable flatscreen choice')
check(widget.BridgeStatus.text:find('Restart the game for VR',1,true),'headset-free popup explains how to return to VR')
widget.ModeChoice=2
check(tick(),'a stale VR click cannot strand a headset-free player')
check(not tick(false) and not widget.PlayVR.enabled,'headset-free start still stops when its link expires')
headset_free=false; game.address=503; widget=new_widget()
check(tick() and widget.PlayVR.enabled,'normal startup still offers VR')
supported=false
local enabled,unsupported=tick()
check(not enabled and unsupported,'menu forwards a confirmed incompatible loadout to the headset-free exit check')
plan.valid=false
enabled,unsupported=tick()
check(not enabled and not unsupported,'menu keeps unknown loadouts locked while replication finishes')
-- The announcement follows actual controls and the exact match choice. It
-- expires on the server if this client stops sending its one-second heartbeat.
local heartbeats,stops=0,0
holder.ServerFlatscreenHeartbeat=function() heartbeats=heartbeats+1 end
holder.ServerFlatscreenStopped=function() stops=stops+1 end
M.report_flatscreen(true)
check(heartbeats==0,'an unknown loadout cannot announce flatscreen')
plan.valid=true; supported=true; game.address=600; widget=new_widget(); tick()
M.report_flatscreen(false)
check(heartbeats==0,'waiting or inactive controls never announce flatscreen')
M.report_flatscreen(true); M.report_flatscreen(true)
check(heartbeats==1,'the active local holder sends at most one heartbeat per second')
tick(); M.report_flatscreen(true)
check(heartbeats==2,'active controls renew the server announcement')
M.report_flatscreen(false); M.report_flatscreen(false)
check(stops==1,'stopping controls removes the announcement once')
M.report_flatscreen(true); M.clear(pawn,true)
check(stops==2,'travel cleanup removes the announcement before releasing the holder')
game.address=601; widget=new_widget(); tick()
holder.ServerFlatscreenHeartbeat=nil
check(M.report_flatscreen(true)==false and tick(),'older loadout packages do not break flatscreen controls')
os.time=native_time
print(count..' menu checks pass')
