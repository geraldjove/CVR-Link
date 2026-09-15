-- A local viewport widget. It never captures mouse input or appears in VR.
local ammo=require('Ammo')
local inventory=require('Inventory')
local M={}
local widget,last_update,last_item
local function valid(o) return o and o:IsValid() end
local function show(o,visible) o:SetVisibility(visible and 3 or 1) end
function M.stop()
    if valid(widget) then show(widget,false); widget:RemoveFromParent() end
    widget,last_update,last_item=nil,nil,nil
end
function M.update(next_widget,pawn,settings,aiming,reloading,ui_active)
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
        local loaded,reserve,magazines=ammo.counts(pawn,gun)
        widget.AmmoText:SetText(FText(tostring(loaded)..' / '..tostring(reserve)))
        widget.ReserveText:SetText(FText(tostring(magazines)..' CHEST MAGS'))
        widget.ActionText:SetText(FText(reloading and 'RELOADING' or reserve==0 and 'NO SPARE AMMO' or ''))
    else
        widget.AmmoText:SetText(FText('--'))
        widget.ReserveText:SetText(FText(''))
        widget.ActionText:SetText(FText(''))
    end
    M.stage='ready'
end
return M
