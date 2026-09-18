-- Per-player scope target. UObject calls run only from the existing local tick.
local M={stage='idle',background_percent=80}
local state,last_error,next_try,diagnostic
local restores=0
local overlay,overlay_error
local previous_scale,applied_scale
local libraries={}
local function valid(o) return o and o:IsValid() end
local function same(a,b) return valid(a) and valid(b) and a:GetAddress()==b:GetAddress() end
local function engine(name)
    libraries[name]=libraries[name] or StaticFindObject('/Script/Engine.Default__'..name)
    return libraries[name]
end
local function scene_scale(value)
    if value and applied_scale then return end
    local system=engine('KismetSystemLibrary')
    local current=system:GetConsoleVariableFloatValue('r.ScreenPercentage')
    if value then
        local requested=math.min(current>0 and current or 100,value)
        if requested==current then return end
        previous_scale,applied_scale=current,requested
        M.stage='apply background scale'
        system:ExecuteConsoleCommand(system,'r.ScreenPercentage '..requested,nil)
        assert(math.abs(system:GetConsoleVariableFloatValue('r.ScreenPercentage')-requested)<.01,'Background render scale did not apply')
    elseif previous_scale then
        -- Keep a newer external setting if another system changed it meanwhile.
        if math.abs(current-applied_scale)<.01 then
            system:ExecuteConsoleCommand(system,'r.ScreenPercentage '..previous_scale,nil)
            assert(math.abs(system:GetConsoleVariableFloatValue('r.ScreenPercentage')-previous_scale)<.01,'Background render scale did not restore')
        end
        previous_scale,applied_scale=nil,nil
    end
end
local function describe(o) return valid(o) and o:GetFullName() or 'none' end
local function texture_names(material)
    local names={SceneCaptureTexture=true}
    local parent=material
    for _=1,8 do
        if not valid(parent) or not parent:IsA('/Script/Engine.MaterialInstance') then break end
        M.stage='read texture parameter list'
        parent.TextureParameterValues:ForEach(function(_,entry)
            local parameter=entry:get()
            names[parameter.ParameterInfo.Name:ToString()]=true
        end)
        parent=parent.Parent
    end
    return names
end
local function lens_binding(sight,target)
    local found,ambiguous
    local mesh_class=StaticFindObject('/Script/Engine.MeshComponent')
    local visited,count={},0
    local function walk(mesh)
        if not valid(mesh) or visited[mesh:GetAddress()] then return end
        visited[mesh:GetAddress()]=true;count=count+1
        assert(count<=64,'Too many scope components')
        if mesh:IsA(mesh_class) then
            M.stage='read mesh slots'
            for index=0,math.min(mesh:GetNumMaterials(),8)-1 do
                M.stage='read material '..index
                local material=mesh:GetMaterial(index)
                if valid(material) and (material:IsA('/Script/Engine.MaterialInstanceConstant') or material:IsA('/Script/Engine.MaterialInstanceDynamic')) then
                    for name in pairs(texture_names(material)) do
                        M.stage='read lens texture '..name
                        local texture=material:K2_GetTextureParameterValue(FName(name))
                        if same(texture,target) then
                            if found then ambiguous=true else found={mesh=mesh,index=index,material=material,parameter=name} end
                        end
                    end
                end
            end
        end
        M.stage='read scope children'
        mesh.AttachChildren:ForEach(function(_,child) walk(child:get()) end)
    end
    walk(sight.RootComponent)
    if not ambiguous then return found end
end
function M.magnified(sight)
    return valid(sight) and (sight:IsA('/Game/Core/VRInteractables/ZomboyGunSystem/Attachments/Sights/ZomboyZoomSightBase.ZomboyZoomSightBase_C')
        or sight:IsA('/Game/Core/VRInteractables/ZomboyGunSystem/Attachments/Sights/ZomboyZoomSightBaseNew.ZomboyZoomSightBaseNew_C')) or false
end
function M.fov(baseline,blend,sight)
    return baseline*(1-(M.magnified(sight) and 0 or .1)*math.max(0,math.min(1,blend or 0)))
end
local function hide_overlay(unloaded)
    if previous_scale then scene_scale() end
    if unloaded then overlay=nil;return end
    if overlay and valid(overlay.widget) then
        overlay.widget:SetVisibility(1)
        overlay.visible=false
        overlay.target=nil
        if valid(overlay.material) and state and valid(state.previous_target) then
            overlay.material:SetTextureParameterValue(FName('Scene'),state.previous_target)
        end
    end
end
local function show_overlay(s)
    -- Only this shipping sight's textures have been inspected. Other scopes
    -- keep their stock view with the larger target until separately checked.
    if s.overlay_supported==false then return end
    if not s.reticle then
        s.reticle=s.material:K2_GetTextureParameterValue(FName('Reticle Design'))
        s.overlay_supported=valid(s.reticle) and s.reticle:GetFullName()=='Texture2D /Game/ThirdPartyResources/Models/Sights/Textures/Scope_Power__1_.Scope_Power__1_'
        if not s.overlay_supported then return end
    end
    local reticle=s.reticle
    if not overlay or not valid(overlay.widget) then
        local system=engine('KismetSystemLibrary')
        local ref=system:Conv_SoftClassPathToSoftClassRef({AssetPathName=FName('/CVRScope/WBP_Scope.WBP_Scope_C')})
        local cls=system:LoadClassAsset_Blocking(ref)
        assert(valid(cls),'Scope UI did not load')
        libraries.widget=libraries.widget or StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')
        local w=libraries.widget:Create(s.pawn,cls,s.pawn.Controller)
        assert(valid(w),'Scope UI did not initialize')
        overlay={widget=w}
        w:SetVisibility(1);w:AddToViewport(19)
        overlay.material=w.Lens:GetDynamicMaterial()
        assert(valid(overlay.material),'Scope UI material did not initialize')
    end
    local w,material=overlay.widget,overlay.material
    if overlay.target~=s.target:GetAddress() then
        material:SetTextureParameterValue(FName('Scene'),s.target)
        material:SetTextureParameterValue(FName('Reticle'),reticle)
        local center=s.material:K2_GetTextureParameterValue(FName('crosshairsight'))
        assert(valid(center),'Scope center texture is missing')
        material:SetTextureParameterValue(FName('Center'),center)
        overlay.target=s.target:GetAddress()
    end
    libraries.layout=libraries.layout or StaticFindObject('/Script/UMG.Default__WidgetLayoutLibrary')
    local layout=libraries.layout
    local size=layout:GetViewportSize(s.pawn)
    local dpi=layout:GetViewportScale(s.pawn)
    assert(dpi>0 and size.X>0 and size.Y>0,'Scope viewport is not ready')
    local origin,forward=s.capture:K2_GetComponentLocation(),s.capture:GetForwardVector()
    local position={X=0,Y=0}
    local projected=layout:ProjectWorldLocationToWidgetPosition(s.pawn.Controller,
        {X=origin.X+forward.X*100000,Y=origin.Y+forward.Y*100000,Z=origin.Z+forward.Z*100000},position,true)
    if not projected or position.X<0 or position.Y<0 or position.X>size.X/dpi or position.Y>size.Y/dpi then
        hide_overlay();return
    end
    local diameter=.8*math.min(size.X,size.Y)/dpi
    w.Lens.Slot:SetPosition({X=position.X-diameter/2,Y=position.Y-diameter/2})
    w.Lens.Slot:SetSize({X=diameter,Y=diameter})
    w:SetVisibility(3)
    overlay.visible=true
    if M.background_percent<100 then scene_scale(M.background_percent) end
end
function M.stop(unloaded)
    next_try=nil
    hide_overlay(unloaded)
    if overlay then overlay.visible=false;overlay.target=nil end
    local s=state
    state=nil
    if not s or unloaded then return end
    if valid(s.capture) and same(s.capture.TextureTarget,s.target) then
        s.capture.TextureTarget=s.previous_target
        assert(same(s.capture.TextureTarget,s.previous_target),'Original capture target did not restore')
    end
    if valid(s.material) and same(s.material:K2_GetTextureParameterValue(FName(s.parameter or 'SceneCaptureTexture')),s.target) then
        s.material:SetTextureParameterValue(FName(s.parameter or 'SceneCaptureTexture'),s.previous_texture)
    end
    if s.binding and valid(s.binding.mesh) and same(s.binding.mesh:GetMaterial(s.binding.index),s.material) then
        s.binding.mesh:SetMaterial(s.binding.index,s.binding.material)
        assert(same(s.binding.mesh:GetMaterial(s.binding.index),s.binding.material),'Original lens material did not restore')
    end
    if valid(s.target) then engine('KismetRenderingLibrary'):ReleaseRenderTarget2D(s.target) end
    restores=restores+1
end
function M.shutdown(unloaded)
    M.stop(unloaded)
    if overlay and valid(overlay.widget) then overlay.widget:RemoveFromParent() end
    overlay,overlay_error=nil,nil
end
local function update(pawn,gun,sight,blend,enabled)
    local reason=not enabled and 'idle' or not M.magnified(sight) and 'unmagnified'
        or not same(sight:GetOwner(),gun) and 'sight owner'
        or not same(gun:GetOwner(),pawn) and 'gun owner' or blend<.99 and 'ADS transition'
    if reason then
        M.stage=reason
        M.stop();last_error=nil;next_try=nil;return
    end
    local capture,material=sight.CachedSceneCapture,sight.ScopeMaterialDynamicInstance
    if state and state.binding then
        material=valid(state.binding.mesh) and state.binding.mesh:GetMaterial(state.binding.index) or nil
    end
    if state and (not same(state.capture,capture) or not same(state.material,material)) then M.stop() end
    if state then
        if not same(capture.TextureTarget,state.target) or not same(material:K2_GetTextureParameterValue(FName(state.parameter)),state.target) then
            M.stop();M.stage='native target changed';next_try=os.clock()+5;return
        end
        M.stage='ready'
        if not overlay_error then
            local shown,why=pcall(show_overlay,state)
            if not shown then
                local stage=M.stage
                hide_overlay();overlay_error=stage..': '..tostring(why)
                print('[Scope] overlay '..overlay_error..'\n')
            else M.stage='ready' end
        end
        if M.readback then
            local ok,reason=pcall(M.readback,pawn,material,state.target)
            if not ok then print('[ScopeReadback] '..tostring(reason)..'\n') end
        end
        return
    end
    if next_try and os.clock()<next_try then return end
    if not valid(capture) then
        M.stage='waiting capture'
        local detail=describe(sight)..' capture='..describe(capture)..' material='..describe(material)
        if detail~=diagnostic then print('[Scope] waiting '..detail..'\n');diagnostic=detail end
        return
    end
    local original=capture.TextureTarget
    if not valid(original) then M.stage='waiting target';return end
    local binding
    if not valid(material) then
        M.stage='find lens';next_try=os.clock()+5
        binding=lens_binding(sight,original)
        if not binding then M.stage='no matching lens';return end
        material=binding.mesh:CreateDynamicMaterialInstance(binding.index,binding.material,FName('None'))
        assert(valid(material),'Private scope lens creation failed')
        -- Keep enough state to restore the mesh even if target creation fails.
        state={capture=capture,material=material,binding=binding,parameter=binding.parameter,previous_target=original,previous_texture=original}
    end
    local parameter=binding and binding.parameter or 'SceneCaptureTexture'
    local texture=material:K2_GetTextureParameterValue(FName(parameter))
    if not valid(original) or not same(original,texture) then
        M.stage='target mismatch'
        local detail=describe(sight)..' target='..describe(original)..' texture='..describe(texture)..' material='..describe(material)
        if detail~=diagnostic then print('[Scope] target mismatch '..detail..'\n');diagnostic=detail end
        M.stop()
        return
    end
    M.stage='creating target'
    local target=engine('KismetRenderingLibrary'):CreateRenderTarget2D(pawn,1024,1024,original.RenderTargetFormat,{R=0,G=0,B=0,A=1},false)
    assert(valid(target),'Private scope target creation failed')
    state={pawn=pawn,gun=gun,sight=sight,capture=capture,material=material,target=target,binding=binding,parameter=parameter,
        previous_target=original,previous_texture=texture}
    target.TargetGamma=original.TargetGamma
    capture.TextureTarget=target
    material:SetTextureParameterValue(FName(parameter),target)
    assert(same(capture.TextureTarget,target),'Scope capture target did not update')
    assert(same(material:K2_GetTextureParameterValue(FName(parameter)),target),'Scope lens target did not update')
    local reticle=material:K2_GetTextureParameterValue(FName('CrossTexture'))
    print('[Scope] '..sight:GetFullName()..' target='..original.SizeX..'x'..original.SizeY..' -> '..target.SizeX..'x'..target.SizeY
        ..' fov='..capture.FOVAngle..' gamma='..target.TargetGamma..' linear='..tostring(target.bForceLinearGamma)
        ..' material='..material:GetFullName()..' reticle='..(valid(reticle) and reticle:GetFullName() or 'none')..'\n')
    last_error=nil;M.stage='ready'
    if M.begin_trial then
        local ok,reason=pcall(M.begin_trial,pawn,gun,capture)
        if not ok then print('[ScopeReadback] '..tostring(reason)..'\n') end
    end
    if M.readback then
        local ok,reason=pcall(M.readback,pawn,material,target)
        if not ok then print('[ScopeReadback] '..tostring(reason)..'\n') end
    end
end
function M.update(pawn,gun,sight,blend,enabled)
    local ok,message=pcall(update,pawn,gun,sight,blend,enabled)
    if ok then return end
    local stage=M.stage
    local restored,reason=pcall(M.stop)
    local detail=stage..': '..tostring(message)..(restored and '' or '; restore '..tostring(reason))
    if detail~=last_error then print('[Scope] '..detail..'\n') end
    last_error=detail;next_try=os.clock()+5;M.stage='error'
end
function M.status()
    return '|scope_hd='..tostring(state~=nil)..'|scope_stage='..M.stage..'|scope_restores='..restores
        ..'|scope_overlay='..tostring(overlay and overlay.visible or false)..'|scope_overlay_error='..tostring(overlay_error or ''):gsub('[|\r\n]',' ')
        ..'|scope_background='..tostring(applied_scale or 'original')
        ..'|scope_error='..tostring(last_error or ''):gsub('[|\r\n]',' ')
end
return M
