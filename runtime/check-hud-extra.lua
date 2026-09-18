-- Run against a generated runtime folder; the stock HUD suite covers display data.
package.path=assert(arg[1],'Pass the runtime folder')..'/?.lua;'..package.path
package.loaded.Ammo={};package.loaded.Inventory={}
local now,count,id,loads,creates=0,0,0,0,0
local missing,fail_create,unloaded=false,false,false
os.clock=function() return now end
local function check(value,label) assert(value,label);count=count+1 end
local function object(value)
    id=id+1;value=value or {};value.id=id
    value.IsValid=function() assert(not unloaded,'old world object accessed');return true end
    value.GetAddress=function(self) return self.id end
    return value
end
local cls,pc,pawn=object(),object(),object()
local function widget()
    local w=object()
    for _,name in ipairs({'Left','Right','Up','Down'}) do
        for _,prefix in ipairs({'Crosshair','CrosshairShadow'}) do
            w[prefix..name]=object({SetRenderTranslation=function(self,p) self.translation=p end})
        end
    end
    return w
end
local api=object({Create=function(_,context,class,owner)
    assert(context==pawn and class==cls and owner==pc,'HUD needs the local pawn/controller')
    creates=creates+1;if fail_create then error('creation failed') end
    return widget()
end})
FName=function(name) return name end
local system={Conv_SoftClassPathToSoftClassRef=function(_,path) assert(path.SubPathString==nil,'leave nested FString at its native empty default');return path.AssetPathName end,
LoadClassAsset_Blocking=function(_,path) assert(path=='/CVRFlatscreen/WBP_CVRHUD.WBP_CVRHUD_C');loads=loads+1;return not missing and cls or nil end}
StaticFindObject=function(path)
    if path=='/Script/UMG.Default__WidgetBlueprintLibrary' then return api end
    if path=='/Script/Engine.Default__KismetSystemLibrary' then return system end
    error('Do not find a generated HUD class through StaticFindObject')
end
local hud=require('HUD')
local first=hud.resolve(nil,pawn,pc)
check(first and creates==1 and hud.source_status():find('hud_source=local',1,true),'creates local HUD with no loadout holder')
-- The freecam branch must hide the viewport widget without losing its class
-- or rebuilding it after garbage collection.
local main=assert(io.open(arg[1]..'/main.lua')):read('*a')
check(main:find('hud.resolve(menu.hud(),pawn,pc)',1,true)~=nil,'runtime uses the local HUD resolver')
local reused=true
for _=1,100 do reused=reused and hud.resolve(nil,pawn,pc)==first end
check(reused and creates==1,'reuse viewport HUD without per-frame creation')
local stock=widget()
check(hud.resolve(stock,pawn,pc)==stock and creates==1,'prefer existing loadout HUD without duplication')
hud.clear_source();missing=true
check(hud.resolve(nil,pawn,pc)==nil and loads==2,'missing asset does not stop controls')
for _=1,100 do now=now+.01;hud.resolve(nil,pawn,pc) end
check(loads==2,'asset retries are bounded')
now=6;missing=false
check(hud.resolve(nil,pawn,pc)~=nil and creates==2,'late asset becomes available')
hud.clear_source();fail_create=true
check(hud.resolve(nil,pawn,pc)==nil and hud.source_status():find('creation failed',1,true),'native creation error is contained')
hud.clear_source();fail_create=false
local w=hud.resolve(nil,pawn,pc)
check(w~=first,'stop and re-enable creates a fresh local HUD')
check(hud.animate_crosshair(w,0)==0,'resting arms stay at authored positions')
now=now+.05;local low=hud.animate_crosshair(w,1)
check(low>0 and low<6,'recoil smoothly opens the crosshair')
now=now+.05;local high=hud.animate_crosshair(w,3)
check(high>low,'more recoil opens it farther')
check(w.CrosshairLeft.translation.X==-w.CrosshairRight.translation.X and w.CrosshairUp.translation.Y==-w.CrosshairDown.translation.Y,'crosshair center stays fixed')
check(w.CrosshairShadowLeft.translation.X==w.CrosshairLeft.translation.X,'shadows follow their arms')
now=now+.05;local recovering=hud.animate_crosshair(w,0)
check(recovering>0 and recovering<high,'crosshair recovers smoothly')
for _=1,100 do now=now+.02;hud.animate_crosshair(w,100) end
check(w.CrosshairRight.translation.X<=28,'large custom recoil stays bounded')
for _=1,100 do now=now+.02;hud.animate_crosshair(w,0) end
check(w.CrosshairRight.translation.X<.001,'crosshair settles back to rest')
unloaded=true;hud.clear_source();unloaded=false
check(hud.resolve(nil,pawn,pc)~=w,'world cleanup drops all old references without touching them')
print(count..' HUD creation and recoil animation checks pass')
