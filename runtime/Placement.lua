-- Mouse-directed Claymore preview; the stock preview still decides whether placement is clear.
local M,state={},nil
local function valid(o) return o and o:IsValid() end
local function same(a,b) return valid(a) and valid(b) and a:GetAddress()==b:GetAddress() end
local function copy(v,fields)
    local t={}; for _,k in ipairs(fields) do t[k]=v[k] end; return t
end
local function multiply(a,b)
    return {X=a.W*b.X+a.X*b.W+a.Y*b.Z-a.Z*b.Y,Y=a.W*b.Y-a.X*b.Z+a.Y*b.W+a.Z*b.X,
        Z=a.W*b.Z+a.X*b.Y-a.Y*b.X+a.Z*b.W,W=a.W*b.W-a.X*b.X-a.Y*b.Y-a.Z*b.Z}
end
local function rotator(q)
    local s=q.Z*q.X-q.W*q.Y
    local yaw=math.deg(math.atan(2*(q.W*q.Z+q.X*q.Y),1-2*(q.Y*q.Y+q.Z*q.Z)))
    if math.abs(s)>.4999995 then
        local sign=s<0 and -1 or 1
        return {Pitch=sign*90,Yaw=yaw,Roll=(sign*yaw-2*math.deg(math.atan(q.X,q.W))+180)%360-180}
    end
    return {Pitch=math.deg(math.asin(2*s)),Yaw=yaw,
        Roll=math.deg(math.atan(-2*(q.W*q.X+q.Y*q.Z),1-2*(q.X*q.X+q.Y*q.Y)))}
end
function M.can_rotate(pawn,item)
    return valid(item) and same(item:GetOwner(),pawn) and pawn.InputMode==0 and not item.bIsPlanted
        and item:IsA('/Game/Core/VRInteractables/Throwables/Grenades/Claymore/ZomboyClaymoreBP.ZomboyClaymoreBP_C')
end
local function dot(a,b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end
local function cross(a,b) return {X=a.Y*b.Z-a.Z*b.Y,Y=a.Z*b.X-a.X*b.Z,Z=a.X*b.Y-a.Y*b.X} end
local function unit(v)
    local length=math.sqrt(dot(v,v)); if length<.0001 then return nil end
    return {X=v.X/length,Y=v.Y/length,Z=v.Z/length}
end
local function projected(v,n)
    local d=dot(v,n); return unit({X=v.X-n.X*d,Y=v.Y-n.Y*d,Z=v.Z-n.Z*d})
end
function M.surface_rotation(normal,forward)
    local n=unit(normal); if not n then return nil end
    local x,z
    if math.abs(n.Z)>.65 then
        z=n; x=projected(forward,z) or projected({X=1,Y=0,Z=0},z)
    else
        x=n; z=projected({X=0,Y=0,Z=1},x)
    end
    local y=unit(cross(z,x)); z=cross(x,y)
    -- Rotation matrix columns are the actor's forward/right/up axes.
    local q,trace={},x.X+y.Y+z.Z
    if trace>0 then
        local s=math.sqrt(trace+1)*2
        q={W=s/4,X=(y.Z-z.Y)/s,Y=(z.X-x.Z)/s,Z=(x.Y-y.X)/s}
    elseif x.X>y.Y and x.X>z.Z then
        local s=math.sqrt(1+x.X-y.Y-z.Z)*2
        q={W=(y.Z-z.Y)/s,X=s/4,Y=(y.X+x.Y)/s,Z=(z.X+x.Z)/s}
    elseif y.Y>z.Z then
        local s=math.sqrt(1+y.Y-x.X-z.Z)*2
        q={W=(z.X-x.Z)/s,X=(y.X+x.Y)/s,Y=s/4,Z=(z.Y+y.Z)/s}
    else
        local s=math.sqrt(1+z.Z-x.X-y.Y)*2
        q={W=(x.Y-y.X)/s,X=(z.X+x.Z)/s,Y=(z.Y+y.Z)/s,Z=s/4}
    end
    local pitch=math.atan(x.Z,math.sqrt(x.X*x.X+x.Y*x.Y))
    return q,{Pitch=math.deg(pitch),Yaw=math.deg(math.atan(x.Y,x.X)),Roll=math.deg(math.atan(-y.Z,z.Z))}
end
function M.stop()
    if not state then return end
    if valid(state.item) then state.item.PlaceDistance=state.distance end
    local a=state.arrow
    if valid(a) then
        a:SetAbsolute(state.absolute_location,state.absolute_rotation,state.absolute_scale)
        a:K2_SetRelativeLocationAndRotation(state.position,state.rotation,false,{},true)
    end
    state=nil
end
function M.follow(pawn,item,camera,rotation,rotating,dx,dy)
    if not M.can_rotate(pawn,item) then M.stop(); return end
    if state and not same(state.item,item) then M.stop() end
    if not state then
        local a=item.LinetraceArrow
        assert(valid(a),'Claymore trace arrow unavailable')
        state={item=item,pawn=pawn,camera=camera,arrow=a,distance=item.PlaceDistance,
            position=copy(a.RelativeLocation,{'X','Y','Z'}),rotation=copy(a.RelativeRotation,{'Pitch','Yaw','Roll'}),
            absolute_location=a.bAbsoluteLocation,absolute_rotation=a.bAbsoluteRotation,absolute_scale=a.bAbsoluteScale}
        a:SetAbsolute(true,true,a.bAbsoluteScale)
        item.PlaceDistance=200 -- The game's existing distance-placement reach.
    end
    state.arrow:K2_SetWorldLocationAndRotation(copy(camera:K2_GetComponentLocation(),{'X','Y','Z'}),rotation,false,{},true)
    state.rotating=rotating or false
    if rotating then
        if not state.manual then state.manual=state.orientation or copy(item:GetTransform().Rotation,{'X','Y','Z','W'}) end
        local yaw,pitch=math.rad(dx or 0)*.5,math.rad(dy or 0)*.5
        local u,r=camera:GetUpVector(),camera:GetRightVector()
        local turn={X=u.X*math.sin(yaw),Y=u.Y*math.sin(yaw),Z=u.Z*math.sin(yaw),W=math.cos(yaw)}
        local tilt={X=-r.X*math.sin(pitch),Y=-r.Y*math.sin(pitch),Z=-r.Z*math.sin(pitch),W=math.cos(pitch)}
        state.manual=multiply(turn,multiply(tilt,state.manual))
    end
end
function M.after_preview(item)
    if not state or not same(state.item,item) then return end
    state.updates=(state.updates or 0)+1
    state.orientation=state.manual
    state.surface_aligned=false
    local preview=item.DeployPreviewActorRef
    if not item.bCanBePlanted or not valid(preview) then return end
    local p,f=state.camera:K2_GetComponentLocation(),state.camera:GetForwardVector()
    local finish={X=p.X+f.X*200,Y=p.Y+f.Y*200,Z=p.Z+f.Z*200}
    local hit,color={}, {R=0,G=0,B=0,A=0}
    local system=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
    if not system:LineTraceSingle(item,copy(p,{'X','Y','Z'}),finish,0,false,{state.pawn,item,preview},0,hit,true,color,color,0) then return end
    if hit.bStartPenetrating then return end
    local q,r=M.surface_rotation(hit.ImpactNormal,f)
    if not q then return end
    if state.manual then q,r=state.manual,rotator(state.manual) end
    preview:K2_SetActorLocationAndRotation(copy(hit.ImpactPoint,{'X','Y','Z'}),r,false,{},true)
    item.TargetTransform=preview.PlantTransform:K2_GetComponentToWorld()
    state.orientation=q
    state.surface_aligned=true
end
function M.update()
    if not state then return end
    state.item:DeployPreviewTick(0) -- Delta is the only parameter; bIsPlacable is a Blueprint local.
    M.after_preview(state.item)
end
function M.status()
    return '|placement_updates='..tostring(state and state.updates or 0)
        ..'|surface_aligned='..tostring(state and state.surface_aligned or false)
        ..'|placement_rotating='..tostring(state and state.rotating or false)
        ..'|placement_manual='..tostring(state and state.manual~=nil or false)
end
function M.orientation(item) return state and same(item,state.item) and state.orientation or nil end
return M
