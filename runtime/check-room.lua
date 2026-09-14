local R=require('Room')
local count=0
local function check(v,message) assert(v,message); count=count+1 end
local function object(fields)
    fields.IsValid=function() return fields.valid~=false end
    fields.GetAddress=function() return fields.address or 1 end
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
print(count..' room checks pass')
