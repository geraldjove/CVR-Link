-- Flat local menu pages. Keep stock component/widget ownership and actions.
-- Only the existing local game-thread tick may touch UObjects.
local M={}
local state,blocked,close_request
local registered={}
local function valid(o) return o and o:IsValid() end
local function same(a,b) return valid(a) and valid(b) and a:GetAddress()==b:GetAddress() end
local function xy(v) return {X=v.X,Y=v.Y} end
local function xyz(v) return {X=v.X,Y=v.Y,Z=v.Z} end
local function api(name) return assert(StaticFindObject('/Script/UMG.Default__'..name)) end
local function key_code(name)
    if #name==1 then return string.byte(name:upper()) end
    local f=tonumber(name:match('^F(%d+)$'))
    if f and f>=1 and f<=12 then return 111+f end
    return ({Tab=9,Escape=27,SpaceBar=32,Enter=13,BackSpace=8,Insert=45,Delete=46,
        Home=36,End=35,PageUp=33,PageDown=34,Up=38,Down=40,Left=37,Right=39,
        LeftMouseButton=1,RightMouseButton=2,MiddleMouseButton=4,ThumbMouseButton=5,ThumbMouseButton2=6,
        LeftShift=160,RightShift=161,LeftControl=162,RightControl=163,LeftAlt=164,RightAlt=165,
        Zero=48,One=49,Two=50,Three=51,Four=52,Five=53,Six=54,Seven=55,Eight=56,Nine=57})[name]
end
function M.bind(name)
    -- UMG can consume Tab before PlayerController sees it. Queue only a flag;
    -- the callback never accesses game objects. Ignore the opening key edge.
    for _,key in ipairs({name or 'Tab','Escape'}) do
        local code=key_code(key)
        if code and not registered[code] and RegisterKeyBind then
            RegisterKeyBind(code,function()
                if state and not state.stationary and (key=='Escape' or key==state.close_key) and os.clock()-state.started>.25 then close_request=true end
            end)
            registered[code]=true
        end
    end
    if state then state.close_key=name or 'Tab' end
    M.close_key=name or 'Tab'
end
function M.take_close()
    local requested=state~=nil and not state.stationary and close_request
    close_request=nil
    return requested
end
local function redraw(component)
    local visible=component.bVisible
    component:SetVisibility(not visible,false)
    component:SetVisibility(visible,false)
end
local function restore(entry)
    local c,w=entry.component,entry.widget
    if not valid(c) then return end
    local ticking=c:IsComponentTickEnabled()
    if valid(w) then
        w:SetRenderScale(entry.scale)
        w:SetRenderTransformPivot(entry.render_pivot)
        -- Remove the screen-layer entry and rebuild the stock world window's
        -- Slate parent with the same widget instance and all its bindings.
        local current=c:GetUserWidgetObject()
        if not valid(current) or same(current,w) then
            c:SetWidget(nil)
            c:SetWidgetSpace(entry.space)
            c:SetWidget(w)
        end
    end
    c:SetWidgetSpace(entry.space)
    c:SetPivot(entry.pivot)
    c:SetDrawAtDesiredSize(entry.auto_size)
    c:SetDrawSize(entry.draw_size)
    c:K2_SetRelativeLocation(entry.position,false,{},true)
    c:SetCollisionEnabled(c.bIsShowing and entry.collision or 0)
    redraw(c)
    c:SetComponentTickEnabled(ticking)
end
function M.stop(unloaded)
    local old=state
    state,close_request=nil,nil
    if not old or unloaded then return end
    for _,entry in pairs(old.entries) do restore(entry) end
    if valid(old.pc) then
        api('WidgetBlueprintLibrary'):SetInputMode_GameOnly(old.pc)
        old.pc.bShowMouseCursor=old.cursor
    end
end
function M.active() return state~=nil end
function M.status()
    return '|flat_menu='..tostring(state~=nil)..'|flat_panels='..tostring(state and state.visible or 0)
        ..'|flat_kind='..(state and (state.stationary and 'stationary' or 'pause') or 'none')
        ..'|flat_menu_error='..tostring(blocked or '')..'|loadout_save='..tostring(M.loadout_save_status or 'ready')
end

-- Keep aspect ratios. Navigation sits below the active stock page(s).
function M.layout(items,width,height)
    local margin,gap=math.min(width,height)*.025,16
    local content,nav,header={},{},{}
    for _,item in ipairs(items) do
        if item.navigation or item.indicator then nav[#nav+1]=item
        elseif item.name=='ChooseLoadoutTypeInMain' then header[#header+1]=item
        else content[#content+1]=item end
    end
    table.sort(content,function(a,b) return a.order==b.order and a.name<b.name or a.order<b.order end)
    local result={}
    local function row(values,top,available_height)
        if #values==0 then return end
        local total,maxheight=0,1
        for _,v in ipairs(values) do total=total+v.width;maxheight=math.max(maxheight,v.height) end
        local scale=math.min((width-2*margin-gap*(#values-1))/math.max(1,total),available_height/maxheight,1.5)
        scale=math.max(.05,scale)
        local x=(width-total*scale-gap*(#values-1))/2
        for _,v in ipairs(values) do
            result[v.id]={x=x,y=top+(available_height-v.height*scale)/2,scale=scale}
            x=x+v.width*scale+gap
        end
    end
    local navheight=#nav>0 and height*.18 or 0
    local contentheight=height-2*margin-navheight
    local headerheight=#header>0 and contentheight*.18 or 0
    row(header,margin,headerheight)
    local separation=#header>0 and gap or 0
    row(content,margin+headerheight+separation,contentheight-headerheight-separation)
    -- Connection icons must not force the much shorter navigation bar to
    -- share their scale. Size each footer widget before fitting the row.
    table.sort(nav,function(a,b) return (a.indicator and 1 or 0)<(b.indicator and 1 or 0) end)
    local total=gap*math.max(0,#nav-1)
    local scales={}
    for _,item in ipairs(nav) do
        local scale=math.min(navheight*(item.indicator and .5 or .85)/item.height,item.indicator and .4 or 1.5)
        scales[item.id]=scale;total=total+item.width*scale
    end
    local fit=math.min(1,(width-2*margin)/math.max(1,total))
    local x=(width-total*fit)/2
    for _,item in ipairs(nav) do
        local scale=scales[item.id]*fit
        result[item.id]={x=x,y=height-margin-navheight/2-item.height*scale/2,scale=scale}
        x=x+item.width*scale+gap*fit
    end
    return result
end
-- Native GetLoadoutTag depends on the process's plan-to-tag registry. A
-- replicated CVR plan can exist without that entry on a remote client.
-- These are the inspected mod-data GetTag results, including loadout index 0.
local loadout_tags={
    ['ZomboyLoadoutPlanInfo /CVRFlatscreen/CVRFlatscreenPlan.CVRFlatscreenPlan']='6383627+0',
    ['ZomboyLoadoutPlanInfo /CVRFlatscreenWW2/CVRFlatscreenPlan.CVRFlatscreenPlan']='6391827+0',
    ['ZomboyLoadoutPlanInfo /CVRFlatscreenNinja/CVRFlatscreenPlan.CVRFlatscreenPlan']='6391829+0',
}
local loadout_save_hooked,loadout_tag_hooked,loadout_save_override
local loadout_tags_reported={}
function M.install_save_tag()
    if loadout_tag_hooked then return end
    RegisterHook('/Script/ZomboyVR.ZomboyGameState:GetLoadoutTag',function() end,function(context,result)
        if result:get():ToString()~='None' then return end
        local game=context:get()
        if not valid(game) then return end
        local plan=game:GetLoadoutPlan()
        local tag=valid(plan) and loadout_tags[plan:GetFullName()]
        if tag then
            if not loadout_tags_reported[tag] then
                loadout_tags_reported[tag]=true
                print('[LoadoutSave] using native mod tag '..tag..' for '..plan:GetFullName()..'\n')
            end
            return FName(tag)
        end
        local target=loadout_save_override
        if target and same(game,target.game) then return target.tag end
    end)
    loadout_tag_hooked=true
end
-- Retain the earlier map fallback for other untagged private/local loadouts.

local function save_map_loadout(w)
    if not state or not valid(w) then return 'no active editor' end
    local owned=false
    for _,entry in pairs(state.entries) do
        if same(entry.widget,w) and valid(entry.component) and entry.component.bIsShowing
            and same(entry.component:GetUserWidgetObject(),w) then owned=true;break end
    end
    if not owned then return 'editor not current/visible' end
    local gameplay=assert(StaticFindObject('/Script/Engine.Default__GameplayStatics'))
    local game=gameplay:GetGameState(w)
    if not valid(game) then return 'no game state' end
    if game:GetLoadoutTag():ToString()~='None' then return 'native tag '..game:GetLoadoutTag():ToString() end
    local mode=gameplay:GetGameMode(w)
    if not valid(mode) then return 'no game mode' end
    local cls=mode:GetClass()
    while valid(cls) and cls:GetFullName()~='BlueprintGeneratedClass /Game/Core/GameMode/CS_GameMode.CS_GameMode_C' do cls=cls:GetSuperStruct() end
    if not valid(cls) then return 'different game mode' end
    -- Match the kit's ParseOption rules without a temporary returned FString.
    local options,tag=mode.OptionsString:ToString(),''
    if options:sub(1,1)~='?' then return 'no options' end
    for pair in options:gmatch('%?([^?]*)') do
        local key,value=pair:match('^([^=]*)=(.*)$')
        if (key or pair):lower()=='maptag' then tag=value or '';break end
    end
    if tag=='' then return 'no map tag' end
    local helper=StaticFindObject('/Game/Core/SaveGames/LoadoutSaveHelper.Default__LoadoutSaveHelper_C')
    if not valid(helper) then error('Stock loadout save helper is missing') end
    -- Re-run the stock save with its own current settings, never a stale None file.
    -- The override lasts only for this synchronous call, on this GameState.
    loadout_save_override={game=game,tag=FName(tag)}
    local ok,reason=pcall(function() helper:SaveLoadouts(w.TmpChooseLoadoutIndex,w) end)
    loadout_save_override=nil
    if not ok then error(reason) end
    M.loadout_save_status=tag..tostring(w.TmpChooseLoadoutIndex)
    print('[Flatscreen] loadout Save routed to '..M.loadout_save_status..'\n')
    return 'saved '..M.loadout_save_status
end
local function register_loadout_save(w,c)
    local cls=c.WidgetClass
    if loadout_save_hooked or not valid(cls) or cls:GetFName():ToString()~='NewLoadout_UI_Main_C' or not w:IsA(cls) then return end
    M.install_save_tag()
    -- UE4SS Blueprint hooks run AFTER the function, following stock budget/save checks.
    RegisterHook('/Game/Core/UI/Loadout/NewUI/NewLoadout_UI_Main.NewLoadout_UI_Main_C:SaveLoadout',function(context)
        local ok,reason=pcall(save_map_loadout,context:get())

        if not ok then
            M.loadout_save_status='error'
            print('[Flatscreen] loadout Save fallback error: '..tostring(reason)..'\n')
        end
    end)
    loadout_save_hooked=true
end

local function discover(root,entries)
    local visited,count={},0
    local widget_class=StaticFindObject('/Script/UMG.WidgetComponent')
    local function walk(c)
        if not valid(c) then return end
        local id=c:GetAddress()
        if visited[id] then return end
        visited[id]=true;count=count+1
        M.stage='inspect '..c:GetFName():ToString()
        assert(count<=256,'Local menu tree is too large')
        if c:IsA(widget_class) and c:GetWidgetSpace()==0 and not entries[id] then
            local w=c:GetUserWidgetObject()
            if valid(w) then
                entries[id]={component=c,widget=w,name=c:GetFName():ToString(),position=xyz(c.RelativeLocation),
                    scale=xy(w.RenderTransform.Scale),render_pivot=xy(w.RenderTransformPivot),
                    space=c:GetWidgetSpace(),pivot=xy(c:GetPivot()),auto_size=c.bDrawAtDesiredSize,
                    draw_size=xy(c:GetDrawSize()),collision=c:GetCollisionEnabled()}
                if entries[id].name=='LoadoutMain' then register_loadout_save(w,c) end
                w:ForceLayoutPrepass()
            end
        end
        M.stage='children '..c:GetFName():ToString()
        c.AttachChildren:ForEach(function(_,child) walk(child:get()) end)
    end
    walk(root)
end
local function update(pawn,pc,pointer_mode,menu,stationary)
    M.stage='get local menu'
    -- The Blueprint GetMenuUI has an object OUT parameter, not a native
    -- return value. ShowMenuUI already resolved it into this local cache.
    if state and (not same(state.pawn,pawn) or not same(state.pc,pc) or not same(state.menu,menu)) then M.stop() end
    if not valid(menu) or not valid(menu.RootComponent) then return false end
    if not state then
        state={pawn=pawn,pc=pc,menu=menu,stationary=stationary,entries={},cursor=pc.bShowMouseCursor,started=os.clock(),close_key=M.close_key}
    end
    local s=state
    local now=os.clock()
    if not s.scan or now<s.scan or now-s.scan>=.2 then
        M.stage='discover '..menu:GetFullName()
        discover(menu.RootComponent,s.entries)
        s.scan=now
    end
    M.stage='read viewport'
    local layout_api=api('WidgetLayoutLibrary')
    local viewport=layout_api:GetViewportSize(pawn)
    local dpi=layout_api:GetViewportScale(pawn)
    if viewport.X<1 or viewport.Y<1 or dpi<=0 then return true end
    local items={}
    for id,entry in pairs(s.entries) do
        M.stage='screen state '..entry.name
        local c,w=entry.component,entry.widget
        if not valid(c) or not valid(w) then s.entries[id]=nil
        elseif not same(c:GetUserWidgetObject(),w) then restore(entry);s.entries[id]=nil;s.scan=nil
        else
            if c:GetWidgetSpace()~=1 then
                local ticking=c:IsComponentTickEnabled()
                -- Clear the old virtual-window Slate parent before the screen
                -- layer takes the same widget. Its UObject bindings stay intact.
                c:SetWidget(nil);c:SetWidgetSpace(1);c:SetWidget(w)
                redraw(c);c:SetComponentTickEnabled(ticking)
            end
            local collision=c:GetCollisionEnabled()
            if collision~=0 then entry.collision=collision end
            c:SetCollisionEnabled(0)
            if c.bIsShowing and c.bVisible and not c.bHiddenInGame then
                local size=w:GetDesiredSize()
                if size.X<1 or size.Y<1 then size=c:GetCurrentDrawSize() end
                if size.X>0 and size.Y>0 then
                    local draw=c:GetDrawSize()
                    if draw.X~=size.X or draw.Y~=size.Y then c:SetDrawSize(xy(size)) end
                    items[#items+1]={id=id,name=entry.name,width=size.X,height=size.Y,
                        order=entry.position.Y,navigation=entry.name:find('Navigation',1,true)~=nil
                            ,indicator=entry.name:find('Connectivity',1,true)~=nil}
                end
            end
        end
    end
    local layout=M.layout(items,viewport.X/dpi,viewport.Y/dpi)
    for id,position in pairs(layout) do
        local entry=s.entries[id]
        local c,w=entry.component,entry.widget
        M.stage='position '..entry.name
        c:SetPivot({X=0,Y=0});c:SetDrawAtDesiredSize(false)
        w:SetRenderTransformPivot({X=0,Y=0})
        w:SetRenderScale({X=entry.scale.X*position.scale,Y=entry.scale.Y*position.scale})
        local origin,direction={},{}
        if pc:DeprojectScreenPositionToWorld(position.x*dpi,position.y*dpi,origin,direction) then
            c:K2_SetWorldLocation({X=origin.X+direction.X*150,Y=origin.Y+direction.Y*150,Z=origin.Z+direction.Z*150},false,{},true)
        end
    end
    s.visible=#items
    local descriptions={}
    for _,item in ipairs(items) do descriptions[#descriptions+1]=item.name..':'..item.width..'x'..item.height end
    table.sort(descriptions)
    local signature=table.concat(descriptions,',')
    if signature~=s.signature then print('[FlatMenu] pages='..signature..'\n');s.signature=signature end
    if s.pointer_mode~=pointer_mode then
        M.stage='cursor input'
        if pointer_mode then
            api('WidgetBlueprintLibrary'):SetInputMode_GameAndUIEx(pc,nil,2,false)
            pc.bShowMouseCursor=true
            if s.pointer_mode==nil then pc:SetMouseLocation(math.floor(viewport.X/2),math.floor(viewport.Y/2)) end
        else
            api('WidgetBlueprintLibrary'):SetInputMode_GameOnly(pc)
            pc.bShowMouseCursor=false
        end
        s.pointer_mode=pointer_mode
    end
    return true
end
function M.update(pawn,pc,pointer_mode)
    -- Join/loadout and respawn live in the stationary tree, not the pause
    -- tree. Keep their stock mode and buttons; Tab/Escape must not dismiss it.
    local stationary=pawn.InputMode==2 or valid(pawn.StationaryUI) and pawn.StationaryUI.bIsShowing or false
    if not stationary and (pawn.InputMode~=1 or pawn.bForcedUIInput) then
        M.stop();blocked=nil;return false
    end
    if blocked then return false end
    local menu=pawn['Menu UI']
    if stationary then menu=pawn.StationaryUI end
    local ok,result=xpcall(function() return update(pawn,pc,pointer_mode,menu,stationary) end,function(reason)
        return debug.traceback(tostring(M.stage)..': '..tostring(reason),2)
    end)
    if ok then return result end
    blocked=(tostring(M.stage)..': '..tostring(result)):gsub('[\r\n|]',' ')
    local restored,reason=pcall(M.stop)
    if not restored then blocked=blocked..'; restore: '..tostring(reason) end
    print('[FlatMenu] '..blocked..'\n')
    return false
end
return M
