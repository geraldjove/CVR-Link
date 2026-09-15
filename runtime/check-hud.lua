local now,count,id=0,0,0
local function check(value,label) assert(value,label); count=count+1 end
local function object(values)
    id=id+1; local address=id
    values=values or {}
    values.IsValid=function(self) return not self.invalid end
    values.GetAddress=function() return address end
    values.IsA=values.IsA or function() return false end
    values.SetVisibility=function(self,v) self.visibility=v end
    values.SetText=function(self,t) self.text=t end
    values.SetBrush=function() error('do not pass a full stock SlateBrush through the loader') end
    values.SetBrushResourceObject=function(self,b) self.resource=b end
    values.SetBrushSize=function(self,s) self.size=s end
    values.SetRenderTransformPivot=function(self,p) self.pivot=p end
    values.SetRenderScale=function(self,s) self.scale=s end
    values.SetRenderOpacity=function(self,a) self.opacity=a end
    return values
end
local function widget()
    local w=object({RemoveFromParent=function(self) self.removes=(self.removes or 0)+1 end,
        AddToViewport=function(self,z) assert(z==20); self.adds=(self.adds or 0)+1 end})
    for _,name in ipairs({'Crosshair','StandingIcon','CrouchingIcon','StanceText','AmmoText','ReserveText',
        'ActionText','WeaponIcon','ItemName','StancePanel','AmmoPanel'}) do w[name]=object() end
    w.Crosshair.Slot=object({anchors={Minimum={X=.5,Y=.5},Maximum={X=.5,Y=.5}},
        SetAnchors=function() error('keep native asset anchors; nested table marshalling zeroes them') end,
        SetPosition=function(self,p) self.position=p end})
    return w
end
local function item(name,icon)
    return object({Brush={ResourceObject=icon,ImageSize={X=128,Y=64}},DisplayName={ToString=function() return name end},
        GetGunFiringTransform=function() error('fixed crosshair must not read the recoiling muzzle') end})
end
local held,gun=item('MK18',object()),true
local loaded,reserve,mags=31,60,2
package.loaded.Ammo={counts=function() return loaded,reserve,mags end}
package.loaded.Inventory={held=function() return held end}
FText=function(t) return t end
FName=function(t) return t end
local real_clock=os.clock
os.clock=function() return now end
local hud=dofile('HUD.lua')
local pawn=object({InputMode=0,GetIsSliding=function(self) return self.sliding end,
    IsCrouching=function(self) return self.crouching end,GetHandHoldingGun=function() return gun and held end,
    PlayerCamera=object({K2_GetComponentLocation=function() return {X=0,Y=0,Z=170} end,GetForwardVector=function() return {X=1,Y=0,Z=0} end})})
local w=widget()
local settings={ui_scale=1,ui_opacity=1}
local function tick(aiming,reloading) now=now+.11; hud.update(w,pawn,settings,aiming,reloading) end
tick()
check(w.adds==1 and w.visibility==3,'HUD joins viewport without capturing any mouse hits')
check(w.Crosshair.visibility==3 and w.StandingIcon.visibility==3 and w.CrouchingIcon.visibility==1,'standing crosshair and pose are shown')
check(w.AmmoText.text=='31 / 60' and w.ReserveText.text=='2 CHEST MAGS','HUD shows loaded rounds and chest reserves separately')
check(w.WeaponIcon.resource==held.Brush.ResourceObject and w.WeaponIcon.size.X==128 and w.ItemName.text=='MK18','HUD uses the stock icon resource, size, and display name')
check(w.Crosshair.Slot.anchors.Minimum.X==.5 and w.Crosshair.Slot.anchors.Maximum.Y==.5
    and w.Crosshair.Slot.position.X==-20 and w.Crosshair.Slot.position.Y==-20,'crosshair stays centered independently of muzzle movement')
settings.ui_scale,settings.ui_opacity=.75,.6; tick()
check(w.opacity==.6 and w.AmmoPanel.scale.X==.75 and w.Crosshair.scale.X==.75,'saved size and transparency apply to the HUD')
check(w.AmmoPanel.pivot.X==1 and w.StancePanel.pivot.X==0 and w.Crosshair.pivot.X==.5,'resizing keeps panels at their screen corners and crosshair on its aim point')
local texture=object({IsA=function(_,path) return path=='/Script/Engine.Texture2D' end,
    Blueprint_GetSizeX=function() return 512 end,Blueprint_GetSizeY=function() return 128 end})
held=item('Wide rifle',object({IsA=function(_,path) return path=='/Script/Engine.MaterialInstanceConstant' end,
    K2_GetTextureParameterValue=function(_,name) assert(name=='IconTexture'); return texture end})); tick()
check(w.WeaponIcon.size.X==512 and w.WeaponIcon.size.Y==128,'stock material uses its texture aspect ratio so rifles are not squashed')
tick(true,true)
check(w.Crosshair.visibility==1 and w.ActionText.text=='RELOADING','ADS hides the crosshair and reload state is visible')
pawn.crouching=true; tick()
check(w.StanceText.text=='CROUCHING' and w.CrouchingIcon.visibility==3 and w.StandingIcon.visibility==1,'pose follows actual crouch state')
pawn.sliding=true; tick()
check(w.StanceText.text=='SLIDING','native slide has its own label')
reserve,mags=0,0; tick()
check(w.ActionText.text=='NO SPARE AMMO','empty chest reserve is clear')
pawn.InputMode=1; tick()
check(w.visibility==1,'game menu hides the entire HUD')
pawn.InputMode=0; gun=false; held=item('Smoke',object()); tick()
check(w.AmmoText.text=='--' and w.ItemName.text=='Smoke' and w.WeaponIcon.resource==held.Brush.ResourceObject,'gadget swap updates the icon and clears gun ammo')
hud.update(w,pawn,settings,false,false,true)
check(w.visibility==1,'stationary, forced, or manual pointer UI hides the gameplay HUD with input mode zero')
tick()
check(w.visibility==3,'leaving pointer UI restores the gameplay HUD')
held=item('Custom item'); tick()
check(w.ItemName.text=='Custom item' and w.WeaponIcon.visibility==1,'missing icon falls back to the item name')
held=nil; tick()
check(w.ItemName.text=='EMPTY HAND' and w.WeaponIcon.visibility==1 and w.ReserveText.text=='','drop removes stale weapon info')
local old=w; w=widget(); tick()
check(old.visibility==1 and old.removes==2 and w.adds==1,'new room widget removes the previous viewport HUD')
hud.stop()
check(w.visibility==1 and w.removes==2,'return to VR removes the HUD')
hud.update(nil,pawn,settings,false,false); hud.stop()
check(w.removes==2,'missing or already stopped HUD is harmless')
os.clock=real_clock
print(count..' flatscreen HUD checks passed')
