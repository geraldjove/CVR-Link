local count,id,now=0,0,0
local function check(v,label) assert(v,label); count=count+1 end
local function object(t)
    id=id+1; local address=id
    t.IsValid=function() return true end; t.GetAddress=function() return address end
    return t
end
StaticFindObject=function(name) return name end
local actual_clock=os.clock; os.clock=function() return now end
local held,left_grip,releases=nil,nil,0
local right=object({GetCurrentInteraction=function() return {InteractionComponent={Get=function() return held and held.grip end}} end,
    OnButtonBPressed=function(self) self.button=true end,OnButtonBReleased=function(self) self.button=false end})
local left=object({K2_SetWorldLocationAndRotation=function(self,p) self.position=p end,
    TryBeginInteractWith=function(_,_,grip) left_grip=grip; return true end})
local pc={RequestEndInteraction=function(_,controller)
    releases=releases+1
    if controller==right then held=nil else left_grip=nil end
    return true
end}
local camera={GetForwardVector=function() return {X=1,Y=0,Z=0} end}
local function item(class)
    local value=object({IsA=function(_,name) return name:find(class,1,true)~=nil end})
    value.grip=object({GetOwner=function() return value end})
    return value
end
local actions=dofile('ItemActions.lua')
local state=actions.new()
held=item('CS_MeleeWeapon.CS_MeleeWeapon_C')
check(actions.press(state,held,pc,left,right),'melee click starts a swing')
now=.16; check(math.abs(actions.offset(state)-45)<.001,'melee swing reaches forward')
now=.33; actions.tick(state,false,true,pc,left,right,camera)
check(not state.item and actions.offset(state)==0,'melee swing returns to rest')
held=item('ZomboyGrenadeBP.ZomboyGrenadeBP_C'); local grenade=held
grenade.HandInteraction1=object({DefaultInteractionButton=1,K2_GetComponentLocation=function() return {X=1,Y=2,Z=3} end,
    K2_GetComponentRotation=function() return {} end})
grenade.SafetyPinArrow=object({K2_GetComponentLocation=function() return {X=1,Y=2,Z=3} end,
    GetForwardVector=function() return {X=0,Y=1,Z=0} end,K2_GetComponentRotation=function() return {} end})
grenade.SafetyPullDistance=2; grenade.ProjectileMovement={}
check(actions.press(state,held,pc,left,right) and left_grip==grenade.HandInteraction1,'grenade click grips its own safety pin')
actions.tick(state,false,true,pc,left,right,camera)
check(held==grenade and left.position.Y==19,'early release waits for native pin readback and moves support hand along pin axis')
grenade.bSafetyPinPull=true; actions.tick(state,true,true,pc,left,right,camera)
check(held==grenade and not left_grip and state.message=='grenade-ready','holding click retains primed grenade')
actions.tick(state,false,true,pc,left,right,camera)
check(not held and grenade.ProjectileMovement.Velocity.X==1400 and grenade.ProjectileMovement.Velocity.Z==180,'release throws with camera-directed velocity')
local previous=releases; actions.tick(state,false,true,pc,left,right,camera)
check(releases==previous,'throw is not repeated')
held=grenade; grenade.bSafetyPinPull=false; actions.press(state,held,pc,left,right)
now=2; actions.tick(state,false,true,pc,left,right,camera)
check(held==grenade and not left_grip and state.message=='pin-pull-timeout','failed pin pull retains grenade and releases synthetic left grip')
actions.press(state,held,pc,left,right); actions.tick(state,false,false,pc,left,right,camera)
check(held==grenade and not left_grip and not state.item,'menu cancels an action without throwing')
held=item('ZomboyClaymoreBP.ZomboyClaymoreBP_C'); actions.press(state,held,pc,left,right)
check(held and state.message=='invalid-placement','claymore remains held without a valid surface')
held.bCanBePlanted=true; held.bIsAbleToPlace=true
held.DeployPreviewActorRef=object({bIsValidPlacement=false})
actions.press(state,held,pc,left,right)
check(held and state.message=='invalid-placement','blocked native preview cannot be planted')
held.DeployPreviewActorRef.bIsValidPlacement=true; actions.press(state,held,pc,left,right)
check(not held and state.message=='claymore-placement-requested','valid claymore preview uses native release and planting')
held=item('Unsupported'); check(not actions.press(state,held,pc,left,right),'unknown item does not receive a guessed action')
os.clock=actual_clock
print(count..' melee/utility action checks passed; native hits and flight require game verification')
