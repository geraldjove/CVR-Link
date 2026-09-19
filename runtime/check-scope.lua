package.path='./?.lua;'..package.path
local count,id,allocations,releases,now,unloaded=0,0,0,0,0,false
os.clock=function() return now end
FName=function(name) return name end
local function check(value,label) assert(value,label);count=count+1 end
local function obj(t)
    id=id+1;t=t or {};t.id=id
    t.IsValid=function(self) assert(not unloaded,'unloaded UObject accessed');return not self.invalid end
    t.GetAddress=function(self) return self.id end
    t.GetFullName=function(self) return 'test_'..self.id end
    return t
end
local pawn,gun=obj(),obj()
gun.GetOwner=function() return pawn end
local original=obj({SizeX=512,SizeY=512,RenderTargetFormat=2,TargetGamma=0,bForceLinearGamma=true})
local capture=obj({TextureTarget=original,FOVAngle=15})
local reticle=obj()
local material=obj({texture=original})
local capture_parameter='SceneCaptureTexture'
material.K2_GetTextureParameterValue=function(self,name) return name=='CrossTexture' and reticle or name==capture_parameter and self.texture or nil end
material.SetTextureParameterValue=function(self,name,value) assert(name==capture_parameter);self.texture=value end
local sight=obj({CachedSceneCapture=capture,ScopeMaterialDynamicInstance=material})
sight.IsA=function(_,path) return path:find('ZomboyZoomSightBaseNew',1,true)~=nil end
sight.GetOwner=function() return gun end
local holo=obj({IsA=function() return false end})
local fail=false
StaticFindObject=function(path)
    assert(path=='/Script/Engine.Default__KismetRenderingLibrary')
    return {CreateRenderTarget2D=function(_,context,w,h,format,color,mips)
        assert(context==pawn and w==1024 and h==1024 and format==2 and not mips)
        allocations=allocations+1
        if fail then error('native target failed') end
        return obj({SizeX=w,SizeY=h,RenderTargetFormat=format,TargetGamma=0,bForceLinearGamma=true})
    end,ReleaseRenderTarget2D=function(_,target) releases=releases+1;target.invalid=true end}
end
local scope=require('Scope')
check(scope.fov(90,0,nil)==90 and scope.fov(90,1,nil)==81,'iron zoom follows the saved baseline')
check(scope.fov(80,.5,holo)==76 and scope.fov(120,1,holo)==108,'hologram zoom blends and respects wider FOV')
check(scope.fov(90,1,sight)==90,'magnified sights do not get an extra iron zoom')
scope.update(pawn,gun,sight,.5,true)
check(allocations==0,'wait for settled scope ADS')
scope.update(pawn,gun,sight,1,true)
local private=capture.TextureTarget
check(private~=original and material.texture==private,'capture and lens use the same private 1024 target')
check(original.SizeX==512 and original.SizeY==512,'shared stock render target is untouched')
for _=1,100 do scope.update(pawn,gun,sight,1,true) end
check(allocations==1,'steady ADS does not allocate per frame')
scope.update(pawn,gun,sight,1,false)
check(capture.TextureTarget==original and material.texture==original and releases==1,'ADS exit/menu/reload/freecam restores both resources')
scope.update(pawn,gun,sight,1,true)
scope.stop()
check(capture.TextureTarget==original and material.texture==original and releases==2,'controls stop restores scope resources')
local foreign=obj({GetOwner=function() return obj() end})
scope.update(pawn,foreign,sight,1,true)
check(allocations==2,'another gun cannot receive the local scope target')
fail=true;scope.update(pawn,gun,sight,1,true)
check(capture.TextureTarget==original and scope.status():find('native target failed',1,true),'creation failure leaves the stock scope usable')
for _=1,100 do scope.update(pawn,gun,sight,1,true) end
check(allocations==3,'native failures have a bounded retry')
now=6;fail=false;scope.update(pawn,gun,sight,1,true)
check(allocations==4 and capture.TextureTarget~=original,'a later native retry can recover')
unloaded=true;scope.stop(true);unloaded=false
check(scope.status():find('scope_hd=false',1,true),'travel discards old UObject references without accessing them')
capture.TextureTarget=original;material.texture=original
sight.ScopeMaterialDynamicInstance=nil
material.IsA=function() return true end
material.TextureParameterValues={ForEach=function() end}
local mesh=obj({material=material})
mesh.GetNumMaterials=function() return 1 end
mesh.GetMaterial=function(self) return self.material end
mesh.SetMaterial=function(self,index,value) assert(index==0);self.material=value end
mesh.CreateDynamicMaterialInstance=function(self,index,parent)
    assert(index==0 and parent==material)
    self.material=obj({texture=parent.texture,K2_GetTextureParameterValue=parent.K2_GetTextureParameterValue,
        SetTextureParameterValue=parent.SetTextureParameterValue})
    return self.material
end
local scans,ambiguous=0,false
local find=StaticFindObject
StaticFindObject=function(path) return path=='/Script/Engine.MeshComponent' and 'mesh class' or find(path) end
mesh.IsA=function(_,cls) assert(cls=='mesh class');scans=scans+1;return true end
mesh.AttachChildren={ForEach=function(_,callback)
    if ambiguous then
        callback(1,{get=function() return obj({IsA=function() return true end,
            GetNumMaterials=mesh.GetNumMaterials,GetMaterial=function() return material end,
            AttachChildren={ForEach=function() end}}) end})
    end
end}
sight.RootComponent=mesh
scope.update(pawn,gun,sight,1,true)
check(capture.TextureTarget~=original and mesh.material~=material and mesh.material.texture==capture.TextureTarget,
    'missing native cache uses a private instance of the one matching lens')
for _=1,100 do scope.update(pawn,gun,sight,1,true) end
check(scans==1,'fallback binding is retained without rescanning each frame')
scope.update(pawn,gun,sight,1,false)
check(mesh.material==material and material.texture==original and capture.TextureTarget==original,'fallback restores original material slot and capture')
fail=true;scope.update(pawn,gun,sight,1,true)
check(mesh.material==material and capture.TextureTarget==original,'target creation failure also restores a newly created lens instance')
scope.update(pawn,gun,sight,1,false);fail=false;ambiguous=true
scope.update(pawn,gun,sight,1,true)
check(mesh.material==material and capture.TextureTarget==original and scope.stage=='no matching lens','ambiguous lens bindings are left unchanged')
scope.update(pawn,gun,sight,1,false);ambiguous=false
scope.update(pawn,gun,sight,1,true)
local other=obj({SizeX=256,SizeY=256})
capture.TextureTarget=other
scope.update(pawn,gun,sight,1,true)
check(capture.TextureTarget==other and mesh.material==material and scope.stage=='native target changed','native target replacement is preserved while the private lens is removed')
scope.update(pawn,gun,sight,1,false);capture.TextureTarget=original
capture_parameter='Texture'
material.TextureParameterValues={ForEach=function(_,callback)
    callback(1,{get=function() return {ParameterInfo={Name={ToString=function() return 'Texture' end}}} end})
end}
scope.update(pawn,gun,sight,1,true)
check(capture.TextureTarget~=original and mesh.material.texture==capture.TextureTarget,'shipping Texture parameter is discovered from the material')
scope.stop()
check(capture.TextureTarget==original and mesh.material==material,'shipping parameter and mesh slot restore together')
local previous_find=StaticFindObject
local reticle_texture=obj()
reticle_texture.GetFullName=function() return 'Texture2D /Game/ThirdPartyResources/Models/Sights/Textures/Scope_Power__1_.Scope_Power__1_' end
local getter=material.K2_GetTextureParameterValue
material.K2_GetTextureParameterValue=function(self,name)
    if name=='Reticle Design' or name=='crosshairsight' then return reticle_texture end
    return getter(self,name)
end
local parameters={}
local ui_material=obj({SetTextureParameterValue=function(_,name,value) parameters[name]=value end,
    SetScalarParameterValue=function(_,name,value) parameters[name]=value end,
    SetVectorParameterValue=function(_,name,value) parameters[name]=value end})
local size,position,widgets,scale=nil,nil,0,93.5
local slot=obj({SetPosition=function(_,p) position=p end,SetSize=function(_,s) size=s end})
local removed=0
local widget=obj({Lens=obj({Slot=slot,GetDynamicMaterial=function() return ui_material end}),RemoveFromParent=function() removed=removed+1 end,
    SetVisibility=function(self,value) self.visibility=value end,AddToViewport=function() end})
local system={Conv_SoftClassPathToSoftClassRef=function(_,p) return p end,LoadClassAsset_Blocking=function() return obj() end,
    GetConsoleVariableFloatValue=function(_,name) assert(name=='r.ScreenPercentage');return scale end,
    ExecuteConsoleCommand=function(self,context,command,pc) assert(context==self and pc==nil);scale=assert(tonumber(command:match('^r.ScreenPercentage (.+)$'))) end}
local layout={GetViewportSize=function() return {X=1920,Y=1080} end,GetViewportScale=function() return 1.5 end,
    ProjectWorldLocationToWidgetPosition=function(_,pc,world,out,relative)
        assert(world.X==100000 and relative);out.X=500;out.Y=350;return true
    end}
StaticFindObject=function(path)
    if path=='/Script/Engine.Default__KismetSystemLibrary' then return system end
    if path=='/Script/UMG.Default__WidgetBlueprintLibrary' then return {Create=function() widgets=widgets+1;return widget end} end
    if path=='/Script/UMG.Default__WidgetLayoutLibrary' then return layout end
    return previous_find(path)
end
capture.K2_GetComponentLocation=function() return {X=0,Y=0,Z=0} end
capture.GetForwardVector=function() return {X=1,Y=0,Z=0} end
scope.background_percent=80
scope.update(pawn,gun,sight,1,true);scope.update(pawn,gun,sight,1,true)
check(scope.status():find('scope_overlay=true',1,true) and parameters.Scene==capture.TextureTarget and scale==80,
    'known scope gets a separate UI image before the background resolution is lowered')
check(size.X==576 and size.Y==576 and position.X==212 and position.Y==62 and widget.visibility==3,
    'circle follows projected aim at 80 percent of output height, compensates DPI and cannot catch mouse hits')
scope.stop()
check(scale==93.5 and widget.visibility==1 and parameters.Scene==original,'ADS exit restores exact fractional scale and releases the UI texture reference')
scope.update(pawn,gun,sight,1,true);scope.update(pawn,gun,sight,1,true)
check(widgets==1,'same-world ADS reuses the existing viewport widget')
scale=55;scope.stop()
check(scale==55,'stop preserves a newer external render-scale change')
scope.update(pawn,gun,sight,1,true);scope.update(pawn,gun,sight,1,true)
check(scale==55,'scope never raises an already lower background scale')
scope.shutdown()
check(removed==1 and widget.visibility==1,'controls stop removes its scope widget from the viewport')
scale=100
scope.update(pawn,gun,sight,1,true);scope.update(pawn,gun,sight,1,true)
unloaded=true;scope.shutdown(true);unloaded=false
check(scale==100 and scope.status():find('scope_overlay=false',1,true),'travel restores the global scale without touching unloaded game objects')
print(count..' scope and ADS FOV checks pass')
