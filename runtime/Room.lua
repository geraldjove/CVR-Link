-- Only the actual loadout plan grants access. Names typed by a host do not.
local M={}
M.plan='ZomboyLoadoutPlanInfo /CVRFlatscreen/CVRFlatscreenPlan.CVRFlatscreenPlan'
M.hub_mode='BlueprintGeneratedClass /Game/Blueprints/GameModes/HubLevel/HubGameMode.HubGameMode_C'
local function valid(o) return o and o:IsValid() end
local function same(a,b) return valid(a) and valid(b) and a:GetAddress()==b:GetAddress() end
function M.new() return {choice=0} end
function M.reset(state)
    state.world,state.choice,state.widget,state.holder=nil,0,nil,nil
    state.world_name=nil
    state.home,state.automatic=false,false
end
function M.check(state,game,pawn,experimental,standalone)
    if not valid(game) then M.reset(state); return false end
    local address=game:GetAddress()
    -- Several travel callbacks can precede the actual unload. Do not auto-enable
    -- again on a last tick from the match we are leaving.
    if state.departing and state.departing==game:GetFullName() then M.reset(state); return false end
    state.departing=nil
    local plan=game:IsA('/Script/ZomboyVR.ZomboyGameState') and game:GetLoadoutPlan()
    local room=valid(plan) and plan:GetFullName()==M.plan
    local hub=standalone==true and valid(game.GameModeClass) and game.GameModeClass:GetFullName()==M.hub_mode or false
    local home=not room and experimental==true and hub
    if not room and not home then
        M.reset(state)
        -- Missing replicated data is still locked, but is not proof of another
        -- loadout. Wait for a known plan before sending a headset-free player home.
        return false,not hub and valid(game.GameModeClass) and (valid(plan) or not game:IsA('/Script/ZomboyVR.ZomboyGameState')) or false
    end
    if state.world~=address or state.home~=home then
        M.reset(state); state.world=address; state.world_name=game:GetFullName(); state.home=home
    end
    -- The widget belongs to this player's loadout, never another player's choice.
    if state.holder and (not valid(state.holder) or not same(state.holder:GetOwner(),pawn)) then
        state.widget,state.holder=nil,nil
    end
    return true
end
function M.choose(state,choice,ready,experimental)
    if not state.world then state.choice=0
    elseif choice==2 then state.choice,state.automatic=2,false
    elseif choice==1 and ready then state.choice,state.automatic=1,false
    elseif state.automatic and not experimental then state.choice,state.automatic=0,false
    elseif state.choice==0 and experimental and ready then state.choice,state.automatic=1,true end
    if not ready and state.choice==1 then state.choice,state.automatic=0,false end
    return state.world~=nil and state.choice==1 and ready
end
return M
