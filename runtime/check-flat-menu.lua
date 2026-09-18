-- Lua 5.4; native Slate rendering and actual cursor hits also need a game test.
package.path='./?.lua;'..package.path
local now,count,next_id,unloaded=1,0,0,false
os.clock=function() return now end
local function check(value,label) assert(value,label);count=count+1 end
local function object(t)
    next_id=next_id+1;t.id=next_id
    t.IsValid=function(self) assert(not unloaded,'freed world was accessed');return not self.invalid end
    t.GetAddress=function(self) return self.id end
    t.GetFName=function(self) return {ToString=function() return self.name end} end
    t.GetFullName=function(self) return self.name or tostring(self.id) end
    return t
end
local function array(values)
    return {ForEach=function(_,fn) for i,v in ipairs(values) do fn(i,{get=function() return v end}) end end}
end
local input_modes,binds={},{}
RegisterKeyBind=function(code,fn) binds[code]=fn end
local viewport={X=1920,Y=1080}
local layout_api={GetViewportSize=function() return viewport end,GetViewportScale=function() return 1 end}
local widget_api={SetInputMode_GameOnly=function() input_modes[#input_modes+1]='game' end,
    SetInputMode_GameAndUIEx=function(_,pc,widget,lock,hide) assert(widget==nil and lock==2 and not hide);input_modes[#input_modes+1]='ui' end}
StaticFindObject=function(path)
    if path:find('Default__WidgetLayoutLibrary',1,true) then return layout_api end
    if path:find('Default__WidgetBlueprintLibrary',1,true) then return widget_api end
    return path
end
local function component(name,width,height,y)
    local w=object({RenderTransform={Scale={X=1,Y=1}},RenderTransformPivot={X=.5,Y=.5}})
    w.SetRenderScale=function(self,v) self.RenderTransform.Scale=v end
    w.SetRenderTransformPivot=function(self,v) self.RenderTransformPivot=v end
    w.ForceLayoutPrepass=function() end
    w.GetDesiredSize=function() return {X=width,Y=height} end
    local c=object({name=name,widget=w,RelativeLocation={X=200,Y=y or 0,Z=0},bDrawAtDesiredSize=true,
        bVisible=true,bHiddenInGame=false,bIsShowing=true,space=0,pivot={X=.5,Y=.5},collision=1,
        size={X=500,Y=500},AttachChildren=array({})})
    c.IsA=function(_,class) return class=='/Script/UMG.WidgetComponent' end
    c.GetUserWidgetObject=function(self) return self.widget end
    c.GetWidgetSpace=function(self) return self.space end
    c.SetWidgetSpace=function(self,v) self.space=v end
    c.GetPivot=function(self) return self.pivot end
    c.SetPivot=function(self,v) self.pivot=v end
    c.GetCollisionEnabled=function(self) return self.collision end
    c.SetCollisionEnabled=function(self,v) self.collision=v end
    c.GetDrawSize=function(self) return self.size end
    c.SetDrawSize=function(self,v) self.size=v end
    c.GetCurrentDrawSize=function() return {X=width,Y=height} end
    c.IsComponentTickEnabled=function(self) return self.ticking~=false end
    c.SetComponentTickEnabled=function(self,v) self.ticking=v end
    c.SetDrawAtDesiredSize=function(self,v) self.bDrawAtDesiredSize=v end
    c.SetVisibility=function(self,v) self.bVisible=v end
    c.SetWidget=function(self,v) self.widget=v end
    c.K2_SetRelativeLocation=function(self,v) self.RelativeLocation=v end
    c.K2_SetWorldLocation=function(self,v) self.world=v end
    return c,w
end
local nav=component('HUD_InGameNavigation',1000,170)
local map=component('MiniMap',900,1000,-90)
local score=component('Leaderboard',900,1000,90)
local children={nav,map,score}
local scans=0
local root=object({name='Root',IsA=function() return false end,AttachChildren={ForEach=function(_,fn)
    scans=scans+1;array(children):ForEach(fn)
end}})
local menu=object({RootComponent=root})
local pawn=object({InputMode=1,['Menu UI']=menu})
local pc=object({bShowMouseCursor=false,SetMouseLocation=function(self,x,y) self.mouse={x,y} end,
    DeprojectScreenPositionToWorld=function(_,x,y,p,d) p.X=x;p.Y=y;p.Z=0;d.X=0;d.Y=0;d.Z=1;return true end})
local flat=require('FlatMenu')
flat.bind('Tab')
check(binds[9] and binds[27],'Tab and Escape callbacks are available when UMG handles keyboard events')
check(flat.update(pawn,pc,true) and flat.active(),'local pause starts')
check(nav.space==1 and map.space==1 and score.space==1,'stock components use screen space')
check(map.collision==0 and map.widget~=nil,'screen pages keep their widgets and drop world pointer collision')
check(pc.bShowMouseCursor and input_modes[#input_modes]=='ui','native cursor input is enabled')
check(pc.mouse[1]==960 and pc.mouse[2]==540,'cursor starts in the viewport')
check(map.world.X<score.world.X and map.world.Y<nav.world.Y,'Match panels and navigation have separate fixed positions')
check(map.size.X==900 and map.size.Y==1000,'layout uses measured widget content instead of the 500x500 buffer')
binds[9]();check(not flat.take_close(),'opening key cannot immediately close the new menu')
now=1.3;binds[9]();check(flat.take_close() and not flat.take_close(),'close requests are consumed once')
flat.bind('P');now=1.4;binds[9]();check(not flat.take_close(),'retired custom close key does not close the menu')
binds[string.byte('P')]();check(flat.take_close(),'new custom pause key closes from a focused widget')
binds[27]();check(flat.take_close(),'Escape closes the flat pause menu')
flat.update(pawn,pc,true)
local before=scans
for i=1,30 do flat.update(pawn,pc,true) end
check(scans==before,'local tree discovery does not run every frame')
local social=component('Social',1300,900);social.bIsShowing=false;social.collision=0;children[#children+1]=social
now=1.7;flat.update(pawn,pc,true)
check(social.space==1,'late page creation joins the flat menu')
social.bIsShowing=true;social.collision=1;flat.update(pawn,pc,true)
score.bIsShowing=false;score.bHiddenInGame=true;score.collision=0
flat.update(pawn,pc,false)
check(not pc.bShowMouseCursor and input_modes[#input_modes]=='game','F9 can return to mouse look while gameplay remains menu-blocked')
flat.update(pawn,pc,true)
check(pc.bShowMouseCursor and input_modes[#input_modes]=='ui','F9 restores the pointer without rebuilding the menu')
pawn.InputMode=0;flat.update(pawn,pc,false)
check(not flat.active() and map.space==0 and map.widget~=nil,'closing returns the same page to its world component')
check(map.RelativeLocation.Y==-90 and map.pivot.X==.5 and map.bDrawAtDesiredSize,'original component layout is restored')
check(map.size.X==500 and map.size.Y==500,'original draw buffer size is restored')
check(map.widget.RenderTransform.Scale.X==1 and map.widget.RenderTransformPivot.X==.5,'widget scale and pivot are restored')
check(score.collision==0,'a hidden page cannot regain pointer collision during cleanup')
check(not pc.bShowMouseCursor and input_modes[#input_modes]=='game','cursor and game input restore on close')
pawn.InputMode=2;check(not flat.update(pawn,pc,true),'stationary loadout mode keeps the stock pointer')
pawn.InputMode=1;pawn.StationaryUI=object({bIsShowing=true})
check(not flat.update(pawn,pc,true),'a stationary overlay wins even if pause mode remains set')
pawn.StationaryUI=nil;pawn.bForcedUIInput=true
check(not flat.update(pawn,pc,true),'forced UI retains its stock input path')
pawn.bForcedUIInput=false;flat.update(pawn,pc,true)
flat.stop();check(not flat.active() and map.space==0,'helper/VR stop restores world widgets')
check(social.collision==1,'a page opened after discovery restores its active stock pointer collision')
flat.update(pawn,pc,true);unloaded=true
flat.stop(true);check(not flat.active(),'world replacement drops references without accessing freed UObjects')
unloaded=false;map.space=0;nav.space=0;score.space=0;social.space=0;pc.bShowMouseCursor=false
local sizes={{640,480},{1280,720},{1920,1080},{2560,1080},{3840,2160}}
for _,size in ipairs(sizes) do
    local items={{id=1,name='map',width=900,height=1000,order=0},{id=2,name='score',width=900,height=1000,order=1},
        {id=3,name='nav',width=1000,height=170,order=0,navigation=true}}
    local positions=flat.layout(items,size[1],size[2])
    for _,item in ipairs(items) do
        local p=positions[item.id]
        assert(p.x>=0 and p.y>=0 and p.x+item.width*p.scale<=size[1] and p.y+item.height*p.scale<=size[2])
    end
    check(true,'layout fits '..size[1]..'x'..size[2])
end
local original=pc.DeprojectScreenPositionToWorld
pc.DeprojectScreenPositionToWorld=function() error('native call unavailable') end
check(not flat.update(pawn,pc,true) and not flat.active(),'a native failure rolls back and preserves the stock menu')
check(map.space==0 and not pc.bShowMouseCursor,'failed setup restores components and cursor')
pc.DeprojectScreenPositionToWorld=original
check(not flat.update(pawn,pc,true),'a failed menu does not retry errors every tick')
pawn.InputMode=0;flat.update(pawn,pc,false);pawn.InputMode=1
check(flat.update(pawn,pc,true),'closing the failed menu permits a fresh attempt')
flat.stop()
local footer=flat.layout({{id=1,name='nav',width=839,height=100,order=0,navigation=true},
    {id=2,name='status',width=768,height=358,order=0,indicator=true}},1920,1080)
check(footer[1].scale>1 and footer[2].scale<.4,'connection icons do not shrink the navigation buttons')
local loadout_items={{id=1,name='ChooseLoadoutTypeInMain',width=3082,height=246,order=-100},
    {id=2,name='LoadoutMain',width=763.5,height=510.5,order=0},
    {id=3,name='AttachmentMain',width=322,height=418,order=100},
    {id=4,name='HUD_Navigation',width=839,height=100,order=0,navigation=true}}
for _,size in ipairs(sizes) do
    local p=flat.layout(loadout_items,size[1],size[2])
    check(p[1].y+246*p[1].scale<p[2].y and p[2].x+763.5*p[2].scale<p[3].x,'loadout selector sits above separate editor panels')
    for _,item in ipairs(loadout_items) do
        local slot=p[item.id]
        assert(slot.x>=0 and slot.y>=0 and slot.x+item.width*slot.scale<=size[1] and slot.y+item.height*slot.scale<=size[2])
    end
end
local loadout=flat.layout(loadout_items,1920,1080)
check(763.5*loadout[2].scale>900,'1080p loadout editor is readable instead of squeezed beside the wide selector')
print(count..' flat pause menu checks pass')
