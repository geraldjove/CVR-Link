-- Only the actual loadout plan grants access. Names typed by a host do not.
local M={}
M.plan='ZomboyLoadoutPlanInfo /CVRFlatscreen/CVRFlatscreenPlan.CVRFlatscreenPlan'
local function valid(o) return o and o:IsValid() end
local function same(a,b) return valid(a) and valid(b) and a:GetAddress()==b:GetAddress() end
function M.new() return {choice=0} end
function M.reset(state)
    state.world,state.choice,state.widget,state.holder=nil,0,nil,nil
end
function M.check(state,game,pawn)
    if not valid(game) or not game:IsA('/Script/ZomboyVR.ZomboyGameState') then M.reset(state); return false end
    local plan=game:GetLoadoutPlan()
    if not valid(plan) or plan:GetFullName()~=M.plan then M.reset(state); return false end
    if state.world~=game:GetAddress() then M.reset(state); state.world=game:GetAddress() end
    -- The widget belongs to this player's loadout, never another player's choice.
    if state.holder and (not valid(state.holder) or not same(state.holder:GetOwner(),pawn)) then
        state.widget,state.holder=nil,nil
    end
    return true
end
function M.choose(state,choice,ready)
    if not state.world then state.choice=0
    elseif choice==2 then state.choice=2
    elseif choice==1 and ready then state.choice=1 end
    if not ready and state.choice==1 then state.choice=0 end
    return state.world~=nil and state.choice==1 and ready
end
return M
