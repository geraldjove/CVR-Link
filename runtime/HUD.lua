-- A local viewport widget. It never captures mouse input or appears in VR.
local ammo=require('Ammo')
local inventory=require('Inventory')
local M={}
local widget,last_update,last_item
local function valid(o) return o and o:IsValid() end
local function show(o,visible) o:SetVisibility(visible and 3 or 1) end
function M.stop(unloaded)
    if not unloaded and valid(widget) then show(widget,false); widget:RemoveFromParent() end
    widget,last_update,last_item=nil,nil,nil
end
function M.update(next_widget,pawn,settings,aiming,reloading,ui_active,recoil)
    if not valid(next_widget) then M.stop(); return end
    if not valid(widget) or widget:GetAddress()~=next_widget:GetAddress() then
        M.stop()
        widget=next_widget
        widget:RemoveFromParent()
        widget:AddToViewport(20)
        -- Keep the asset's center anchors. This loader zeroes nested FAnchors tables.
        widget.Crosshair.Slot:SetPosition({X=-20,Y=-20})
        widget.Crosshair:SetRenderTransformPivot({X=.5,Y=.5})
        widget.StancePanel:SetRenderTransformPivot({X=0,Y=1})
        widget.AmmoPanel:SetRenderTransformPivot({X=1,Y=1})
    end
    local visible=pawn.InputMode==0 and not ui_active
    show(widget,visible)
    if not visible then return end
    local scale=settings.ui_scale
    widget:SetRenderOpacity(settings.ui_opacity)
    for _,part in ipairs({widget.Crosshair,widget.StancePanel,widget.AmmoPanel}) do part:SetRenderScale({X=scale,Y=scale}) end
    local gun=pawn:GetHandHoldingGun(true)
    show(widget.Crosshair,not aiming and not reloading)
    M.animate_crosshair(widget,valid(gun) and recoil or 0)
    local sliding=pawn:GetIsSliding()
    local crouching=pawn:IsCrouching()
    show(widget.StandingIcon,not crouching and not sliding)
    show(widget.CrouchingIcon,crouching or sliding)
    widget.StanceText:SetText(FText(sliding and 'SLIDING' or crouching and 'CROUCHING' or 'STANDING'))
    if last_update and os.clock()-last_update<.1 then return end
    last_update=os.clock()
    local item=inventory.held(pawn.RightMotionController)
    local address=valid(item) and item:GetAddress() or 0
    if last_item~=address then
        M.stage='read held item icon'
        local brush=valid(item) and item.Brush
        local has_icon=brush and valid(brush.ResourceObject)
        if has_icon then
            M.stage='set held item icon'
            -- Copy the resource and size, avoiding the loader's full SlateBrush conversion.
            widget.WeaponIcon:SetBrushResourceObject(brush.ResourceObject)
            local resource=brush.ResourceObject
            local texture=resource
            if resource:IsA('/Script/Engine.MaterialInstanceConstant') or resource:IsA('/Script/Engine.MaterialInstanceDynamic') then
                texture=resource:K2_GetTextureParameterValue(FName('IconTexture'))
            end
            local size={X=brush.ImageSize.X,Y=brush.ImageSize.Y}
            if valid(texture) and texture:IsA('/Script/Engine.Texture2D') then
                size={X=texture:Blueprint_GetSizeX(),Y=texture:Blueprint_GetSizeY()}
            end
            widget.WeaponIcon:SetBrushSize(size)
        end
        show(widget.WeaponIcon,has_icon)
        M.stage='set held item name'
        widget.ItemName:SetText(FText(valid(item) and item.DisplayName:ToString() or 'EMPTY HAND'))
        last_item=address
    end
    M.stage='read ammo counts'
    if valid(gun) then
        local loaded,reserve,magazines,label=ammo.counts(pawn,gun)
        widget.AmmoText:SetText(FText(tostring(loaded)..' / '..tostring(reserve)))
        widget.ReserveText:SetText(FText(tostring(magazines)..' '..(label or 'CHEST MAGS')))
        widget.ActionText:SetText(FText(reloading and 'RELOADING' or reserve==0 and 'NO SPARE AMMO' or ''))
    else
        widget.AmmoText:SetText(FText('--'))
        widget.ReserveText:SetText(FText(''))
        widget.ActionText:SetText(FText(''))
    end
    M.stage='ready'
end
-- Local HUD creation and centered recoil spread.
-- Viewport lifetime stays in HUD.update/stop; this only supplies the widget.
local owned,owner,next_try,source_error
local spread,last_frame,last_crosshair=0,nil,nil
local hud_roots={'/CVRFlatscreen','/CVRFlatscreenWW2','/CVRFlatscreenNinja'}
function M.hide()
    if valid(widget) then show(widget,false) end
end
function M.clear_source()
    owned,owner,next_try,source_error=nil,nil,nil,nil
    spread,last_frame,last_crosshair=0,nil,nil
end
function M.resolve(stock,pawn,pc)
    if valid(stock) then owned=nil;source_error=nil;return stock end
    if owner~=pc:GetAddress() then M.clear_source();owner=pc:GetAddress() end
    if valid(owned) then return owned end
    local now=os.clock()
    if next_try and now<next_try then return nil end
    next_try=now+5
    local ok,result=pcall(function()
        -- Load the class instead of finding a potentially unloaded generated
        -- class after GC. Keep the hidden viewport widget during freecam.
        -- Omit the broken nested FString setter's empty SubPathString field.
        local system=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
        for _,root in ipairs(hud_roots) do
            local reference=system:Conv_SoftClassPathToSoftClassRef({AssetPathName=FName(root..'/WBP_CVRHUD.WBP_CVRHUD_C')})
            local cls=system:LoadClassAsset_Blocking(reference)
            if valid(cls) then return StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary'):Create(pawn,cls,pc) end
        end
    end)
    if ok and valid(result) then
        owned=result;source_error=nil
        print('[HUD] created local HUD without a loadout holder\n')
        return owned
    end
    local reason=ok and 'CVR Link HUD asset is not available' or tostring(result):gsub('[\r\n|]',' ')
    if reason~=source_error then print('[HUD] '..reason..'\n');source_error=reason end
end
function M.source_status()
    return '|hud_source='..(owned and 'local' or 'loadout')..'|hud_error='..tostring(source_error or '')
end
function M.animate_crosshair(w,recoil)
    local now=os.clock()
    if last_crosshair~=w:GetAddress() then spread=0;last_frame=nil;last_crosshair=w:GetAddress() end
    local dt=last_frame and math.max(0,math.min(.1,now-last_frame)) or 0
    last_frame=now
    local target=math.min(28,math.max(0,recoil or 0)*6)
    spread=spread+(target-spread)*(1-math.exp(-dt/(target>spread and .05 or .12)))
    for _,arm in ipairs({{'Left',-1,0},{'Right',1,0},{'Up',0,-1},{'Down',0,1}}) do
        for _,prefix in ipairs({'Crosshair','CrosshairShadow'}) do
            local part=w[prefix..arm[1]]
            if valid(part) then part:SetRenderTranslation({X=arm[2]*spread,Y=arm[3]*spread}) end
        end
    end
    return spread
end

return M
