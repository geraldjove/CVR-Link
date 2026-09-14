local R=require('Room')
local S=require('Settings')
local M={settings=S.defaults()}
local state=R.new()
local folder=assert(os.getenv('LOCALAPPDATA'))..'/ContractorsFlatscreen/'
local loaded,load_error=S.load(folder)
M.settings=loaded or S.defaults()
local last_load=-1
local exit_hooks={}
local function valid(o) return o and o:IsValid() end
local function same(a,b) return valid(a) and valid(b) and a:GetAddress()==b:GetAddress() end
local function text(widget,name,value) widget[name]:SetText(FText(value)) end
local function close(pawn)
    if valid(state.widget) then state.widget.PopupOpen=false; state.widget:SetVisibility(1) end
    if valid(state.holder) and valid(state.holder.CVRMenu) then state.holder.CVRMenu:SetVisibility(false,false) end
    if state.opened and valid(pawn) then
        if valid(pawn['Menu UI']) then pawn['Menu UI']:SetActorHiddenInGame(false) end
        if pawn.InputMode==1 then pawn:HideMenuUI() end
    end
    state.opened=false
end
function M.clear(pawn)
    close(pawn)
    R.reset(state)
end
local function show(pawn)
    local component=state.holder.CVRMenu
    local camera=pawn.PlayerCamera
    local pos,forward=camera:K2_GetComponentLocation(),camera:GetForwardVector()
    local rot=camera:K2_GetComponentRotation()
    component:K2_SetWorldLocationAndRotation({X=pos.X+forward.X*160,Y=pos.Y+forward.Y*160,Z=pos.Z+forward.Z*160},
        {Pitch=-rot.Pitch,Yaw=rot.Yaw+180,Roll=0},false,{},true)
    state.widget.ModeChoice=0
    state.widget.PopupOpen=true
    state.widget:SetVisibility(0)
    component:SetVisibility(true,false)
    pawn:ShowMenuUI(true,FName('None'))
    if valid(pawn['Menu UI']) then pawn['Menu UI']:SetActorHiddenInGame(true) end
    state.opened=true
end
function M.update(pawn,pc,game,ready)
    if last_load~=os.time() then
        last_load=os.time()
        local changed,message=S.load(folder,true)
        if changed then M.settings=changed; load_error=nil else load_error=message end
    end
    local old_holder,old_widget=state.holder,state.widget
    if not R.check(state,game,pawn) then
        if valid(old_widget) then old_widget.PopupOpen=false; old_widget:SetVisibility(1) end
        if valid(old_holder) and valid(old_holder.CVRMenu) then old_holder.CVRMenu:SetVisibility(false,false) end
        close(pawn)
        return false
    end
    if not valid(state.widget) then
        state.discovery='no holder'
        for index=0,2 do
            for _,holder in ipairs(FindAllOf('BP_CVRHolder'..index..'_C') or {}) do
                state.discovery='holder owner mismatch'
                if same(holder:GetOwner(),pawn) and valid(holder.CVRMenu) then
                    state.discovery='widget not ready'
                    local widget=holder.CVRMenu:GetUserWidgetObject()
                    if valid(widget) then state.discovery='widget class mismatch: '..widget:GetFullName() end
                    if valid(widget) and widget:IsA('/CVRFlatscreen/WBP_CVRFlatscreen.WBP_CVRFlatscreen_C') then
                        if not exit_hooks[index] then
                            RegisterHook('/CVRFlatscreen/BP_CVRHolder'..index..'.BP_CVRHolder'..index..'_C:ReceiveEndPlay',function(context)
                                if same(context:get(),state.holder) and M.on_exit then M.on_exit() end
                            end)
                            exit_hooks[index]=true
                        end
                        state.discovery='ready'
                        state.holder,state.widget=holder,widget
                        state.ready,state.greeted=nil,false
                        if state.choice~=0 then widget.ModeChoice=0; close(pawn)
                        end
                        break
                    end
                end
            end
            if valid(state.widget) then break end
        end
    end
    local widget=state.widget
    if not valid(widget) then return false end
    if widget.PopupOpen then state.opened=true end
    if state.opened and pawn.InputMode~=1 then close(pawn) end
    if not state.greeted and state.holder.MenuPlaced then
        if state.choice==0 then show(pawn) else close(pawn) end
        state.greeted=true
    end
    if state.ready~=ready then
        widget.PlayFlatscreen:SetIsEnabled(ready)
        text(widget,'BridgeStatus',ready and 'CVR Link is ready. Choose VR or Flatscreen.' or 'Start CVR Link on your PC to use Flatscreen. VR is ready.')
        state.ready=ready
    end
    local f8=pc:IsInputKeyDown({KeyName=FName('F8')})
    if f8 and not state.f8 then if state.opened then close(pawn) else show(pawn) end end
    state.f8=f8
    local choice=widget.ModeChoice
    if choice==1 or choice==2 then
        R.choose(state,choice,ready)
        widget.ModeChoice=0
        close(pawn)
    end
    return R.choose(state,0,ready)
end
function M.hud() return valid(state.widget) and state.widget.FlatHUD or nil end
function M.status()
    return '|cvr_room='..tostring(state.world~=nil)..'|choice='..state.choice
        ..'|widget='..tostring(valid(state.widget) or false)..'|popup='..tostring(state.opened or false)
        ..'|menu_lookup='..tostring(state.discovery or 'waiting')
        ..'|settings='..S.encode(M.settings):gsub('\n',',')
        ..'|settings_error='..tostring(load_error or '')
end
return M
