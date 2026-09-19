local R=require('Room')
local count=0
local function check(v,message) assert(v,message); count=count+1 end
local function object(fields)
    fields.IsValid=function() return fields.valid~=false end
    fields.GetAddress=function() return fields.address or 1 end
    fields.GetFullName=fields.GetFullName or function() return fields.name or ('MockGameState '..(fields.address or 1)) end
    fields.IsA=function() return true end
    return fields
end
local plan=object({GetFullName=function() return R.plan end})
local game=object({GetLoadoutPlan=function() return plan end})
local pawn=object({})
local state=R.new()
check(not R.choose(state,1,true),'a key or menu cannot grant access without a room')
check(R.check(state,game,pawn),'actual loadout permits a choice')
check(not R.choose(state,0,true),'VR is default')
check(not R.choose(state,1,false),'helper must be ready')
check(R.choose(state,1,true),'player may choose flatscreen')
check(not R.choose(state,2,true),'VR choice disables flatscreen')
check(R.choose(state,1,true),'player may switch back inside the same room')
check(not R.choose(state,0,false) and state.choice==0,'helper expiry clears the choice')
R.choose(state,1,true)
game.address=2
check(R.check(state,game,pawn) and state.choice==0,'new game state resets the choice')
R.choose(state,1,true)
local real=R.plan
R.plan='a different plan'
plan.GetFullName=function() return real end
check(not R.check(state,game,pawn) and not R.choose(state,1,true),'changing to Standard revokes access')
R.plan=real
check(R.check(state,game,pawn),'reentering supported loadout permits a new choice')
plan.valid=false
check(not R.check(state,game,pawn),'missing or stale plan revokes access')
plan.valid=true
R.check(state,game,pawn)
R.choose(state,1,true)
check(not R.check(state,nil,pawn) and state.choice==0,'disconnect clears choice')
R.check(state,game,pawn)
local other=object({address=99})
state.widget=object({})
state.holder=object({GetOwner=function() return other end})
check(R.check(state,game,pawn) and not state.widget,'other player widget discarded')
R.choose(state,1,true)
state.widget=object({})
state.holder=object({GetOwner=function() return pawn end})
check(R.check(state,game,other) and not state.widget and R.choose(state,0,true),
    'a new pawn in the same match discards the old widget but keeps flatscreen')
state=R.new()
check(R.check(state,game,pawn,true,false) and R.choose(state,0,true,true),'Experimental selects flatscreen in the exact loadout on a server')
check(not R.choose(state,2,true,true) and not R.choose(state,0,true,true),'VR choice overrides Experimental for the match')
game.address=3
check(R.check(state,game,pawn,true,false) and R.choose(state,0,true,true),'Experimental selects flatscreen in a new supported match')
check(not R.choose(state,0,true,false),'turning Experimental off releases an automatic choice')
R.choose(state,1,true)
check(R.choose(state,0,true,false),'turning Experimental off keeps an explicit in-game Flatscreen choice')
check(not R.choose(state,0,false,true) and state.choice==0,'Experimental still expires with the helper lease')
check(R.choose(state,0,true,true),'Experimental can resume with a fresh helper in an allowed match')
local mode=object({GetFullName=function() return R.hub_mode end})
game.GameModeClass=mode
plan.GetFullName=function() return 'ZomboyLoadoutPlanInfo /Game/Core/Player/StandardLoadoutPlanAsset.StandardLoadoutPlanAsset' end
check(not R.check(state,game,pawn,false,true),'HQ does not unlock without Experimental opt-in')
check(R.check(state,game,pawn,true,true) and state.home and R.choose(state,0,true,true),'local stock HQ permits Experimental startup')
check(not R.check(state,game,pawn,true,false) and not R.choose(state,0,true,true),'a networked server using the HQ mode still requires CVRFlatscreen')
mode.GetFullName=function() return 'BlueprintGeneratedClass /OtherMod/HubGameMode.HubGameMode_C' end
check(not R.check(state,game,pawn,true,true),'a mod with the same short HQ name cannot unlock startup')
mode.GetFullName=function() return 'BlueprintGeneratedClass /Game/Blueprints/GameModes/Control/CS_ControlGamemode.CS_ControlGamemode_C' end
check(not R.check(state,game,pawn,true,true),'other offline game modes also return to VR')
plan.GetFullName=function() return R.plan end
check(R.check(state,game,pawn,true,false) and R.choose(state,0,true,true),'custom maps and game modes can use the exact CVRFlatscreen loadout')
check(not R.check(state,nil,pawn,true,true) and not R.choose(state,0,true,true),'missing game state cannot unlock Experimental')
R.check(state,game,pawn,true,false)
state.departing=state.world_name; R.reset(state)
check(not R.check(state,game,pawn,true,false) and not R.choose(state,0,true,true),'a late departing-world tick cannot auto-enable flatscreen')
check(not R.check(state,nil,pawn,true,false) and not R.check(state,game,pawn,true,false),'an empty travel gap keeps the departure guard')
game.name='MockGameState new instance at reused address'
check(R.check(state,game,pawn,true,false) and R.choose(state,0,true,true),'a new game state at a reused address can enable Experimental')
plan.valid=false
local allowed,unsupported=R.check(state,game,pawn,true,false)
check(not allowed and not unsupported,'an unreplicated plan is locked without an early return to HQ')
plan.valid=true; plan.GetFullName=function() return 'Standard' end
allowed,unsupported=R.check(state,game,pawn,true,false)
check(not allowed and unsupported,'a known non-CVR plan requests a headset-free return')
game.GameModeClass=nil
allowed,unsupported=R.check(state,game,pawn,true,false)
check(not allowed and not unsupported,'an unknown game mode waits for replication before returning')
game.GameModeClass=object({GetFullName=function() return R.hub_mode end})
allowed,unsupported=R.check(state,game,pawn,false,true)
check(not allowed and not unsupported,'turning Experimental off at HQ cannot start an HQ return loop')
-- Appended to the public room suite; exercise every new exact identity.
for name,root in pairs(R.plans) do
    R.reset(state);plan.GetFullName=function() return name end
    check(R.check(state,game,pawn) and state.root==root,'exact '..root..' plan permits choice')
    check(not R.choose(state,0,true),'new loadout remains VR by default')
    check(not R.choose(state,1,false),'new loadout still requires a live helper')
    check(R.choose(state,1,true),'local choice and helper enable the supported loadout')
    plan.GetFullName=function() return name..'_Fake' end
    check(not R.check(state,game,pawn) and not R.choose(state,1,true),'similar loadout names cannot bypass the gate')
    plan.GetFullName=function() return name end;R.check(state,game,pawn);R.choose(state,1,true)
    plan.GetFullName=function() return R.plan end
    check(R.check(state,game,pawn) and state.choice==0,'changing accepted identities resets local choice')
end

print(count..' room checks pass')
