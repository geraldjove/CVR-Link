local count,id,now=0,0,0
local real_clock=os.clock
os.clock=function() return now end
local function check(v,name) assert(v,name); count=count+1 end
local function object(t)
    id=id+1; local address=id
    t.IsValid=function(self) return not self.invalid end
    t.GetAddress=function() return address end
    t.IsA=t.IsA or function() return false end
    return t
end
local pawn,foreign=object({}),object({})
local holsters,grips={},{}
local function slot(tag,owner,placeholder)
    local h=object({HolsterTag={ToString=function() return tag end},RootComp=object({}),GetOwner=function() return owner or pawn end})
    local item=object({attached=h,GetOwner=function() return owner or pawn end,
        GetFName=function() return {ToString=function() return placeholder and 'NoneInteractableActor_C_1' or tag end} end,
        RootComponent={AttachSocketName='None',GetRelativeTransform=function() return {saved=true} end},
        GetActorAttachingTo=function(self) return self.attached end,CanAttachTo=function() return true end})
    h.GetHolsterInteractable=function() return item end
    item.grip=object({GetOwner=function() return item end,DefaultGripType=1,bAssistGrip=false,DefaultInteractionButton=0})
    holsters[#holsters+1]=h; grips[#grips+1]=item.grip
    return item,h
end
local primary,home=slot('Primary')
local alternate=slot('Alt-Primary')
local sidearm=slot('Sidearm')
local utility1=slot('Gadget1')
local utility2=slot('Gadget2')
local utility3=slot('Gadget3')
local melee=slot('Melee')
slot('Primary',foreign)
FindAllOf=function(name) return name=='ZomboyInteractableHolster' and holsters or grips end
local held,requests,grabs,before=nil,0,0,0
local reject,delayed,reject_release=false,false,false
local attachment_intent,releases,unassigned_releases=nil,0,0
local right={GetCurrentInteraction=function() return {InteractionComponent={Get=function() return held and held.grip end}} end,
    TryBeginInteractWith=function(_,button,grip) assert(button==0); grabs=grabs+1; held=grip:GetOwner(); held.attached=nil; return true end}
local pc={RequestEndInteraction=function()
    releases=releases+1
    if reject_release then return false end
    if attachment_intent then
        if not delayed then attachment_intent.item.attached=attachment_intent.holster end
    else unassigned_releases=unassigned_releases+1 end
    attachment_intent=nil; held=nil; return true
end,
RequestSetInteractableAttachment=function(_,item,root,socket,t)
    requests=requests+1; assert(socket=='None' and t.saved)
    if not root then attachment_intent=nil; return true end
    if reject then return false end
    for _,h in ipairs(holsters) do
        if h.RootComp==root then
            if held==item then attachment_intent={item=item,holster=h}
            elseif not delayed then item.attached=h end
        end
    end
    return true
end}
local inventory=dofile('Inventory.lua')
local state=inventory.new(pawn)
local function begin(key)
    inventory.select(state,key,pc,right,function() before=before+1 end)
    inventory.tick(state,right); inventory.tick(state,right)
end
local function select(key)
    begin(key)
    if state.pending then now=state.pending.equip_after; inventory.tick(state,right); inventory.tick(state,right) end
    if state.pending and state.pending.raise_started then now=now+.251; inventory.tick(state,right) end
end
select('One'); check(held==primary and requests==0,'1 selects own primary without an initial drop')
select('One'); check(held==alternate and primary.attached==home,'repeated 1 holsters primary and selects alternate')
check(unassigned_releases==0,'the stock holster destination is set before releasing the gun')
select('One'); check(held==primary,'primary cycle wraps')
local started=now
begin('Two'); check(held==primary and state.pending,'primary stays held while lowering')
now=started+.125; inventory.tick(state,right)
check(math.abs(inventory.lowering(state,primary)-.5)<.00001,'old weapon lowers smoothly before holstering')
local old_pending=state.pending; begin('V'); check(state.pending==old_pending,'repeat selection cannot interrupt a switch')
now=started+.251; inventory.tick(state,right); check(not held and primary.attached==home,'lowered weapon holsters before sidearm pickup')
now=started+.999; inventory.tick(state,right); check(not held,'sidearm cannot equip before one second')
now=started+1; inventory.tick(state,right); inventory.tick(state,right)
check(held==sidearm,'2 selects sidearm after the one-second delay')
check(inventory.lowering(state,sidearm)==1 and state.pending,'new weapon starts fully lowered and remains busy while raising')
now=now+.125; check(math.abs(inventory.lowering(state,sidearm)-.5)<.00001,'new weapon rises smoothly')
now=now+.126; inventory.tick(state,right); check(not state.pending and inventory.lowering(state,sidearm)==0,'raising completes at the ready pose')
started=now; begin('One'); check(held==sidearm and state.pending,'sidearm also lowers before the reverse switch')
now=started+.999; inventory.tick(state,right); check(not held,'reverse switch cannot equip before one second')
now=started+1; inventory.tick(state,right); inventory.tick(state,right); check(held==primary,'primary returns after the reverse delay')
now=now+.251; inventory.tick(state,right)
select('Two')
local previous=grabs; select('Two'); check(grabs==previous and held==sidearm,'same single slot does not release or regrab')
select('Three'); check(held==utility1,'3 selects first utility')
previous=grabs; select('Three'); check(held==utility1 and grabs==previous,'3 keeps the first gadget selected instead of cycling')
select('Four'); check(held==utility2,'4 selects the second gadget')
select('Five'); check(held==utility3,'5 selects the third gadget when present')
select('V'); check(held==melee,'V selects melee')
local old_releases=releases
reject=true; select('One'); check(held==melee and state.message=='holster-rejected','rejected holster retains held item and does not grab target')
check(releases==old_releases,'a rejected attachment never drops the item')
reject=false; reject_release=true; previous=grabs; select('One')
check(held==melee and grabs==previous and state.message=='release-rejected','a rejected release keeps the old item without taking the next one')
check(not attachment_intent,'a rejected release cancels the pending holster destination')
reject_release=false
reject=false; delayed=true; previous=grabs; select('One')
check(held==nil and grabs==previous and state.pending,'delayed holstering waits for readback before taking the next item')
local actual_clock=os.clock; os.clock=function() return actual_clock()+2 end
inventory.tick(state,right); os.clock=actual_clock
check(not state.pending and held==melee and grabs==previous+1 and state.message=='switch-timeout','failed holster readback regrabs the original item')
held=melee; delayed=false; select('One'); check(held==primary,'retry after timeout works')
sidearm.invalid=true; previous=before; select('Two')
check(held==primary and before==previous,'missing slot retains current weapon')
alternate.invalid=true; previous=grabs; select('One')
check(held==primary and grabs==previous,'one remaining primary does not drop on repeat')
local unknown=slot('Unknown'); held=unknown
select('V'); check(held==unknown and state.message=='cannot-holster','unassigned held item is retained instead of silently dropped')
held=nil; select('V'); check(held==melee,'slot equips after explicit drop of an unassigned item')
local camera={K2_GetComponentLocation=function() return {X=0,Y=0,Z=170} end,
    GetForwardVector=function() return {X=1,Y=0,Z=0} end}
local dropped=slot('Dropped')
dropped.attached=nil
local grip=dropped.grip
grips={grip}
local point={X=100,Y=0,Z=170}
local busy,allowed,blocked=false,true,false
grip.GetInteractable=function() return dropped end
grip.K2_GetComponentLocation=function() return point end
grip.IsInteracting=function() return busy end
grip.CanBeginInteraction=function(_,controller) assert(controller==right); return allowed end
local traces=0
local obstruction,crate,wall_behind
StaticFindObject=function(path)
    assert(path=='/Script/Engine.Default__KismetSystemLibrary')
    return {LineTraceSingle=function(_,world,start,finish,channel,complex,ignore,draw,hit,ignore_self)
        assert((world==pawn or world==crate) and start.Z==170 and finish.X==point.X and channel==0 and not complex)
        assert(ignore_self and #ignore==0)
        traces=traces+1
        if obstruction then
            -- UE4SS 3.0.1 discards Lua array input; only native ignore-self works.
            if world==crate then return wall_behind end
            hit.Component={Get=function() return obstruction end}
        end
        return blocked
    end}
end
held=nil; inventory.interact(state,right,camera)
check(held==dropped and state.interaction=='accepted-Dropped' and traces==1,'E reaches an aimed dropped gun outside the fixed hand position')
previous=grabs; inventory.interact(state,right,camera)
check(held==dropped and grabs==previous and state.interaction=='hand-full','E does not drop or replace a held item')
held=nil; blocked=true; inventory.interact(state,right,camera)
check(not held and state.interaction=='blocked','a wall blocks pickup')
blocked=false; allowed=false; inventory.interact(state,right,camera)
check(not held and grabs==previous,'native interaction rejection prevents pickup')
allowed=true; busy=true; inventory.interact(state,right,camera)
check(not held,'another active grip prevents pickup')
busy=false; dropped.attached=home; inventory.interact(state,right,camera)
check(not held,'holstered and attached items are excluded')
dropped.attached=nil; grip.bAssistGrip=true; inventory.interact(state,right,camera)
check(not held,'support grips are excluded')
grip.bAssistGrip=false; grip.DefaultInteractionButton=1; inventory.interact(state,right,camera)
check(not held,'E cannot pull a magazine or trigger component')
grip.DefaultInteractionButton=0
for _,case in ipairs({{201,0,170,'beyond two metres'},{-50,0,170,'behind the camera'},
    {100,21,170,'away from the aim'}, {0,0,170,'at the camera origin'}}) do
    point={X=case[1],Y=case[2],Z=case[3]}; inventory.interact(state,right,camera)
    check(not held,'pickup excludes a target '..case[4])
end
point={X=200,Y=0,Z=170}; inventory.interact(state,right,camera)
check(held==dropped,'the exact two-metre reach is included')
held=nil; state.pending={}; previous=grabs; inventory.interact(state,right,camera)
check(not held and grabs==previous,'pickup cannot interrupt a gear switch')
state.pending=nil
local ammo=require('Ammo')
local refill=ammo.refill
local supplied=0
ammo.refill=function(player,station) assert(player==pawn and station==dropped); supplied=supplied+1; return 2,'chest-refilled' end
dropped.IsA=function(_,path) return path:find('/AmmoSupply.',1,true)~=nil end
grip.DefaultInteractionButton=1; allowed=false; held=melee
local handled=inventory.interact(state,right,camera)
check(handled and supplied==1 and held==melee and state.interaction=='chest-refilled-2',
    'E refills a trigger-configured ammo station while keeping the held item')
blocked=true; inventory.interact(state,right,camera)
check(supplied==1 and state.interaction=='blocked','a wall blocks station refill')
blocked=false; point.X=201; inventory.interact(state,right,camera)
check(supplied==1,'a station beyond reach cannot refill ammo')
point.X=100; held=nil; inventory.interact(state,right,camera)
check(supplied==2 and not held,'station refill also works with an empty hand')
local stock_mesh='StaticMesh /Game/Maps/Scene_RES/MilitaryBase/Meshes/SM_MERGED_SupplyPack_01_Single_Can.SM_MERGED_SupplyPack_01_Single_Can'
local mesh_name,inside_distance=stock_mesh,0
crate=object({})
obstruction=object({GetOwner=function() return crate end,
    IsA=function(_,path) return path=='/Script/Engine.StaticMeshComponent' end,
    StaticMesh=object({GetFullName=function() return mesh_name end}),
    GetClosestPointOnCollision=function(_,target,out,bone)
        assert(target.X==point.X and target.Z==point.Z and bone=='None')
        return inside_distance
    end})
FName=function(name) return name end
blocked=true; wall_behind=false; held=melee; previous=traces
inventory.interact(state,right,camera)
check(supplied==3 and held==melee and traces==previous+2,'native ignore-self skips the containing stock can even when Lua ignore arrays are discarded')
wall_behind=true; inventory.interact(state,right,camera)
check(supplied==3 and state.interaction=='blocked','a real wall behind the stock ammo can still blocks refill')
wall_behind=false; mesh_name='StaticMesh /Game/Wall.Wall'; previous=traces
inventory.interact(state,right,camera)
check(supplied==3 and traces==previous+1 and state.interaction=='blocked','ordinary map geometry is never ignored')
mesh_name=stock_mesh; inside_distance=25; inventory.interact(state,right,camera)
check(supplied==3 and state.interaction=='blocked','an ammo prop with the supply point outside its collision still blocks the path')
inside_distance=-1; inventory.interact(state,right,camera)
check(supplied==3,'missing stock ammo-can collision cannot grant ammo')
inside_distance=0; obstruction.StaticMesh.invalid=true; inventory.interact(state,right,camera)
check(supplied==3,'an unavailable ammo-can mesh cannot grant ammo')
obstruction.StaticMesh.invalid=false; crate.invalid=true; inventory.interact(state,right,camera)
check(supplied==3 and state.interaction=='blocked','an invalid prop owner cannot turn a failed world lookup into a clear ray')
crate.invalid=false; dropped.IsA=function() return false end
held=nil; grip.DefaultInteractionButton=0; allowed=true; inventory.interact(state,right,camera)
check(not held and state.interaction=='blocked','a stock ammo prop does not permit picking up unrelated items through it')
ammo.refill=refill
print(count..' inventory and interaction checks passed')
os.clock=real_clock
