local placement=dofile('Placement.lua')
local count,id=0,0
local function check(value,message) assert(value,message); count=count+1 end
local function close(a,b) return math.abs(a-b)<.00001 end
local function axis(q,v)
    local x=2*(q.Y*v.Z-q.Z*v.Y); local y=2*(q.Z*v.X-q.X*v.Z); local z=2*(q.X*v.Y-q.Y*v.X)
    return {X=v.X+q.W*x+q.Y*z-q.Z*y,Y=v.Y+q.W*y+q.Z*x-q.X*z,Z=v.Z+q.W*z+q.X*y-q.Y*x}
end
local forward,up={X=1,Y=0,Z=0},{X=0,Y=0,Z=1}
local floor=placement.surface_rotation(up,{X=0,Y=1,Z=-1})
check(close(axis(floor,up).Z,1) and close(axis(floor,forward).Y,1),'floor placement stands upright and follows projected aim')
local wall=placement.surface_rotation({X=-1,Y=0,Z=0},forward)
check(close(axis(wall,forward).X,-1) and close(axis(wall,up).Z,1),'wall placement faces outward and stays upright')
local slope=placement.surface_rotation({X=0,Y=-.6,Z=.8},forward)
check(close(axis(slope,up).Y,-.6) and close(axis(slope,up).Z,.8),'sloped support follows its surface normal')
local vertical=placement.surface_rotation(up,{X=0,Y=0,Z=-1})
check(close(axis(vertical,up).Z,1),'looking straight down has a stable floor orientation')
check(placement.surface_rotation({X=0,Y=0,Z=0},forward)==nil,'invalid surface normals are rejected')
local function object(t)
    id=id+1; local address=id
    t.IsValid=function() return true end; t.GetAddress=function() return address end; return t
end
local arrow=object({RelativeLocation={X=1,Y=2,Z=3},RelativeRotation={Pitch=-90,Yaw=0,Roll=-180},
    bAbsoluteLocation=false,bAbsoluteRotation=false,bAbsoluteScale=false,
    SetAbsolute=function(self,a,b,c) self.bAbsoluteLocation,self.bAbsoluteRotation,self.bAbsoluteScale=a,b,c end,
    K2_SetWorldLocationAndRotation=function(self,p,r) self.world,self.world_rotation=p,r end,
    K2_SetRelativeLocationAndRotation=function(self,p,r) self.RelativeLocation,self.RelativeRotation=p,r end})
local pawn=object({InputMode=0})
local camera=object({K2_GetComponentLocation=function() return {X=10,Y=20,Z=170} end,GetForwardVector=function() return forward end,
    GetUpVector=function() return up end,GetRightVector=function() return {X=0,Y=1,Z=0} end})
local item=object({PlaceDistance=30,LinetraceArrow=arrow,bCanBePlanted=true,bIsAbleToPlace=false,
    DeployPreviewTick=function(self,delta,...) assert(delta==0 and select('#',...)==0,'native preview takes only Delta'); self.preview_ticks=(self.preview_ticks or 0)+1 end,
    GetOwner=function() return pawn end,IsA=function() return true end,
    GetTransform=function() return {Rotation={X=0,Y=0,Z=0,W=1}} end})
local target={marker='native plant transform'}
local preview=object({bIsValidPlacement=false,PlantTransform={K2_GetComponentToWorld=function() return target end},
    K2_SetActorLocationAndRotation=function(self,p,r) self.position,self.rotation=p,r end})
item.DeployPreviewActorRef=preview
local hit_success=true
StaticFindObject=function() return {LineTraceSingle=function(_,context,start,finish,channel,complex,ignore,draw,hit)
    assert(context==item and ignore[1]==pawn and ignore[2]==item and ignore[3]==preview)
    assert(close(finish.X-start.X,200) and channel==0 and draw==0)
    hit.ImpactPoint={X=40,Y=20,Z=170}; hit.ImpactNormal={X=-1,Y=0,Z=0}
    return hit_success
end} end
placement.follow(pawn,item,camera,{Pitch=0,Yaw=0,Roll=0})
check(arrow.bAbsoluteLocation and arrow.bAbsoluteRotation and item.PlaceDistance==200,'mouse trace uses stock distance reach independently of item rotation')
placement.update()
check(item.preview_ticks==1 and placement.status():find('placement_updates=1',1,true),'game-thread update runs native preview and alignment directly')
check(preview.position.X==40 and close(math.abs(preview.rotation.Yaw),180),'preview aligns to the hit wall')
check(item.TargetTransform==target,'planting uses the aligned native PlantTransform component')
check(not item.bIsAbleToPlace and not preview.bIsValidPlacement,'surface alignment never overrides native clearance validation')
check(placement.orientation(item)~=nil,'held claymore can follow surface orientation')
hit_success=false; placement.after_preview(item)
check(not placement.orientation(item),'leaving the surface returns to the normal hold')
placement.follow(pawn,item,camera,{Pitch=0,Yaw=0,Roll=0},true,30,20)
placement.update()
local manual=placement.orientation(item)
check(manual and math.abs(manual.Y)>.1 and math.abs(manual.Z)>.1,'middle drag rotates the held Claymore on both mouse axes without a surface')
placement.follow(pawn,item,camera,{Pitch=0,Yaw=0,Roll=0},false,40,40)
placement.update()
check(placement.orientation(item)==manual,'releasing middle mouse retains the chosen orientation and ignores mouse movement')
hit_success=true; placement.update()
check(placement.orientation(item)==manual and math.abs(preview.rotation.Pitch)>1,'surface preview uses the manual orientation after release')
check(not item.bIsAbleToPlace and not preview.bIsValidPlacement,'manual rotation also preserves native placement rejection')
check(placement.can_rotate(pawn,item),'owned held Claymore can enter rotation mode')
item.bIsPlanted=true; check(not placement.can_rotate(pawn,item),'planted Claymores cannot enter held rotation mode'); item.bIsPlanted=false
placement.stop()
check(item.PlaceDistance==30 and not arrow.bAbsoluteLocation and not arrow.bAbsoluteRotation,'stop restores native reach and trace attachment flags')
check(arrow.RelativeLocation.X==1 and arrow.RelativeRotation.Pitch==-90,'stop restores original trace pose')
placement.follow(pawn,item,camera,{Pitch=0,Yaw=0,Roll=0}); pawn.InputMode=1
placement.follow(pawn,item,camera,{Pitch=0,Yaw=0,Roll=0})
check(item.PlaceDistance==30,'opening menu restores native placement control')
pawn.InputMode=0; placement.follow(pawn,item,camera,{Pitch=0,Yaw=0,Roll=0})
item.IsValid=function() error('old Claymore touched after world unload') end
arrow.IsValid=function() error('old arrow touched after world unload') end
placement.stop(true)
check(placement.orientation(item)==nil,'world unload forgets Claymore references without touching freed objects')
print(count..' Claymore placement checks passed; native surface clearance needs game verification')
