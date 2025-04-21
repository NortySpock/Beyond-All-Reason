if not Spring.GetModOptions().unit_market then
    return
end
-- This handles fair transfer of resource for unit if the modoption is enabled, otherwise it just self removes.

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name    = "Unit Market - Backend",
        desc    = "Allows players to trade units with each other. Allies only. Fair price!",
        author  = "Tom Fyuri",
        date    = "2024",
        license = "GNU GPL v2",
        layer   = 0,
        enabled = true
    }
end

VFS.Include("luarules/configs/customcmds.h.lua")

if gadgetHandler:IsSyncedCode() then

-- We just have a state which holds unit price. (zero or nil - can't trade it)
-- At this time we support only one price - the full price - no tips - no discount - no markups - it should be fair.
-- We allow to trade any (finished and unfinished both) units between players.
-- AI however still only recognizes only finished units as gifts. AI will only sell finished units as well.
-- AI will remember your gifts and give you discount in kind for your purchases. In practise, this means you can swap units with the AI for free, as long as you've given the AI more than you've taken from the AI.

-- There is no GUI or any other fancy tricks here. This is just a backend. Other widget makers though should be able to use this no problem.

local unitsForSale = {}
local spGetPlayerInfo       = Spring.GetPlayerInfo
local spGetTeamInfo         = Spring.GetTeamInfo
local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitTeam			= Spring.GetUnitTeam
local ShareTeamResource     = Spring.ShareTeamResource
local spGetTeamResources    = Spring.GetTeamResources
local TransferUnit          = Spring.TransferUnit
local spAreTeamsAllied      = Spring.AreTeamsAllied
local spSendLuaUIMsg        = Spring.SendLuaUIMsg
local spSendLuaRulesMsg     = Spring.SendLuaRulesMsg
local spValidUnitID         = Spring.ValidUnitID
local spGetUnitHealth       = Spring.GetUnitHealth
local spGetUnitRulesParam  	= Spring.GetUnitRulesParam
local spSetUnitRulesParam   = Spring.SetUnitRulesParam
local spIsCheatingEnabled   = Spring.IsCheatingEnabled
local spEditUnitCmdDesc     = Spring.EditUnitCmdDesc
local spFindUnitCmdDesc     = Spring.FindUnitCmdDesc
local spInsertUnitCmdDesc   = Spring.InsertUnitCmdDesc
local spGetUnitCmdDescs     = Spring.GetUnitCmdDescs
local spGetTeamList         = Spring.GetTeamList
local spSetUnitBuildSpeed   = Spring.SetUnitBuildSpeed
local RPAccess = {allied = true}
local AllyAIsalesEverything = true -- does this needs to be a modoption? This seems useful for coop.
local AllyAItab = {} -- [teamAI_ID][teamID] -- array of teams that this AI team owes metal to
local AllowPlayersSellUnfinished = true -- allows players to set unfinished units on sale
local TeamIsSaving = {} -- whether team is saving metal to buy something

local sellCmd = {
    id = CMD_SELL_UNIT,
    type = CMDTYPE.ICON_MODE,
    tooltip = "",
    name = 'Sell Unit',
    cursor = 'sellunit',
    action = 'sellunit',
    params = { '0', 'Not For Sale', 'For Sale' }
}


local buildPower = {}
local realBuildSpeed = {}
local unitBuildSpeed = {}
for unitDefID, unitDef in pairs(UnitDefs) do
    if unitDef.buildSpeed > 0 then
        unitBuildSpeed[unitDefID] = unitDef.buildSpeed
    end
end

local function UnitSaleBroadcast(unitID, price, msgFromTeamID)
    SendToUnsynced("UnitSale",  unitID, price, msgFromTeamID)
end

local function UnitSoldBroadcast(unitID, price, old_ownerTeamID, msgFromTeamID)
    SendToUnsynced("UnitSold", unitID, price, old_ownerTeamID, msgFromTeamID)
end

local function setForSaleState(unitID, state)
	local cmdDescID = spFindUnitCmdDesc(unitID, CMD_SELL_UNIT)
	if cmdDescID then
		sellCmd.params[1] = state
		spEditUnitCmdDesc(unitID, cmdDescID, {params = sellCmd.params})
	end
end

local function setNotForSale(unitID)
    if spValidUnitID(unitID) then
        setForSaleState(unitID, 0)
    end
    spSetUnitRulesParam(unitID, "unitPrice", 0, RPAccess)
    UnitSaleBroadcast(unitID, 0, spGetUnitTeam(unitID))
    unitsForSale[unitID] = nil
end

local tax_resource_sharing_enabled = Spring.GetModOptions().tax_resource_sharing_amount ~= nil and Spring.GetModOptions().tax_resource_sharing_amount > 0
local tax_resource_amount = Spring.GetModOptions().tax_resource_sharing_amount or 0

local disable_unit_sharing_enabled = (
    Spring.GetModOptions().disable_unit_sharing_economy_and_production
    or Spring.GetModOptions().disable_unit_sharing_combat_units
    or Spring.GetModOptions().disable_unit_sharing_all
    or tax_resource_sharing_enabled)
local saleWhitelist = {}
if tax_resource_sharing_enabled ~= 0 or Spring.GetModOptions().disable_assist_ally_construction then
    AllowPlayersSellUnfinished = false -- needs to be off, otherwise the buyer can assist their unfinished blueprint after buying it
end

local function setUnitOnSale(unitID, specifiedPrice, toggle)

    if not spValidUnitID(unitID) then return false end
    local unitDefID = spGetUnitDefID(unitID)
    if not unitDefID then return false end
    local unitDef = UnitDefs[unitDefID]
    if not unitDef then return false end
    local finished = not Spring.GetUnitIsBeingBuilt(unitID)
    if not AllowPlayersSellUnfinished and not finished then return false end

    -- When tax resource sharing is on, only allow selling t2 cons through unit market
    if tax_resource_sharing_enabled then
        if not unitDef.customParams.shareable_under_resource_tax then return false end
    end
    if toggle and not (unitsForSale[unitID] == nil or unitsForSale[unitID] == 0) then
        setNotForSale(unitID)
        return false
    end
    
    local price
    if not specifiedPrice or specifiedPrice <= 0 then
        price = unitDef.metalCost
    else 
        price = specifiedPrice
    end

    unitsForSale[unitID] = price
    spSetUnitRulesParam(unitID, "unitPrice", price, RPAccess)
    UnitSaleBroadcast(unitID, price, spGetUnitTeam(unitID))
    setForSaleState(unitID, 1)
    return true
end

local function getAIdiscount(newTeamID, oldTeamID, price)
    if not AllyAIsalesEverything then return 0 end

    local myDiscount = AllyAItab[oldTeamID] and AllyAItab[oldTeamID][newTeamID] or 0
    local finalDiscount = math.min(price, myDiscount) -- Ensure finalDiscount doesn't exceed price

    if finalDiscount > 0 then
        if myDiscount > 0 then
            AllyAItab[oldTeamID][newTeamID] = myDiscount - finalDiscount
        end
        return finalDiscount
    else
        return 0
    end
end

local function tryToBuyUnit(unitID, msgFromTeamID)
    if not unitID or unitsForSale[unitID] == nil or unitsForSale[unitID] == 0 then return end
    local unitDefID = spGetUnitDefID(unitID)
    if not unitDefID then return end
    local unitDef = UnitDefs[unitDefID]
    if not unitDef then return end
    
    local sellerTeamID = spGetUnitTeam(unitID)
    local _, _, _, isAiTeam = spGetTeamInfo(sellerTeamID)
    if not spAreTeamsAllied(sellerTeamID, buyerTeamID) then return end

    local current = select(1,spGetTeamResources(buyerTeamID, "metal"))
    local price = unitsForSale[unitID]

    if isAiTeam then
        local discount = getAIdiscount(buyerTeamID, sellerTeamID, price) -- if AI ally owes you metal, you can discount
        price = price - discount
        --Spring.Echo("debug discount: "..discount) -- debug: if AI owes you money...
    end

    if (current < price) then return end
    
    if disable_unit_sharing_enabled then
        saleWhitelist[unitID] = true
    end

    TransferUnit(unitID, buyerTeamID)
    if buyerTeamID ~= sellerTeamID and price > 0 then -- don't send resources to yourself
        
        Spring.AddTeamResource(sellerTeamID, "metal", price) -- adjust metal manually so that unit market bypasses resource share tax
        Spring.AddTeamResource(sellerTeamID, "metal", -1 * price)
    end
    setNotForSale(unitID)
    UnitSoldBroadcast(unitID, price, sellerTeamID, buyerTeamID)
end

if disable_unit_sharing_enabled then
    function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
        if(capture) then
            return true
        end
        if saleWhitelist[unitID] then
            saleWhitelist[unitID] = nil
            return true
        end
        if(GG.disable_unit_sharing_unitTypeAllowedToBeShared) then
            return GG.disable_unit_sharing_unitTypeAllowedToBeShared(unitDefID)
        else
            return true
        end
    end
end

-- this takes control and makes all cons stop using metal, we remove all limits on a) shutdown b) storage getting full c) widget crash - should be safe enough
local function SetTeamSavingMetal(teamID, status)
    local old_status = TeamIsSaving[teamID]
    if (old_status ~= status) then
        if (status == true) then -- enable
            for _, unitID in pairs(buildPower[teamID]) do
                spSetUnitBuildSpeed(unitID, 0.01)
            end
        else -- disable
            for _, unitID in pairs(buildPower[teamID]) do
                spSetUnitBuildSpeed(unitID, realBuildSpeed[unitID])
            end
        end
        TeamIsSaving[teamID] = status
    end
end

function gadget:RecvLuaMsg(msg, playerID)
    local _, _, mySpec, msgFromTeamID = spGetPlayerInfo(playerID, false)

    if mySpec then return end

    local words = {}
    for word in msg:gmatch("%S+") do
        table.insert(words, word)
    end
    
    if words[1] == "unitOfferToSell" then
        local unitID = tonumber(words[2])
        --local sale_price = tonumber(words[3])
        -- at the moment we only support "fair" price, but it is possible here to set unit price by client, for now we send 0 - set price automatically
        local unitTeamID = spGetUnitTeam(unitID)
        if msgFromTeamID ~= unitTeamID and not spIsCheatingEnabled() then return end -- in cheat mode you can set other units for sale, not just your own
        setUnitOnSale(unitID, 0, false)
    elseif words[1] == "unitTryToBuy" then
        local unitID = tonumber(words[2])
        tryToBuyUnit(unitID, msgFromTeamID)
    elseif words[1] == "startSaving" then
        SetTeamSavingMetal(msgFromTeamID, true)
    elseif words[1] == "stopSaving" then
        SetTeamSavingMetal(msgFromTeamID, false)
    end
end

-- failsafe
function gadget:GameFrame(frame)
    if (frame % 45) == 1 then
        for teamID, status in pairs(TeamIsSaving) do
            if status then
                local current, storage, _, _, _, shareSlider = spGetTeamResources(teamID, "metal")
                if (current >= (storage * 0.9)) or (current >= (storage * shareSlider)) then
                    SetTeamSavingMetal(teamID, false)
                end
            end
        end
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
    setNotForSale(unitID)
    buildPower[teamID][unitID] = nil
end

function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
    if unitDefID then
		spInsertUnitCmdDesc(unitID, sellCmd)
        setNotForSale(unitID)

        realBuildSpeed[unitID] = unitBuildSpeed[unitDefID] or 0
        buildPower[teamID][unitID] = unitID
    end
end

function gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
    if (AllyAIsalesEverything) and spAreTeamsAllied(newTeamID, oldTeamID) then
        local unitDef = UnitDefs[unitDefID]
        local _, _, _, isAiTeamOld = spGetTeamInfo(oldTeamID) -- player
        local _, _, _, isAiTeamNew = spGetTeamInfo(newTeamID) -- gives unit to AI
        if not isAiTeamOld and isAiTeamNew and unitDef.metalCost>0 then
            local finished = (select(5,spGetUnitHealth(unitID))==1) -- AI tab only accepts finished units
            if finished then
                local price = unitDef.metalCost
                -- This "ugly" calculation won't be called too much since you are not often giving units to the AI
                -- But it might be a good idea to pre init arrays if we expand this optional functionality for between players
                if AllyAItab[newTeamID] == nil then
                    AllyAItab[newTeamID] = {}
                end
                if AllyAItab[newTeamID][oldTeamID] == nil then
                    AllyAItab[newTeamID][oldTeamID] = 0
                end
                AllyAItab[newTeamID][oldTeamID] = AllyAItab[newTeamID][oldTeamID] + price
                --Spring.Echo("old team "..oldTeamID.." owes "..newTeamID.." this much: "..AllyAItab[newTeamID][oldTeamID]..".") -- debug
                -- TODO this is kinda useful but I don't know how to not spam you constantly with this information...
                -- so need to figure out how to show you how much AI owes you metal for your donations
                -- possible TODO, maybe forbid AI from selling you its metal extractors?
                setUnitOnSale(unitID, price, false)
                return
            end
        end
    end
    setNotForSale(unitID)
end

function gadget:UnitFinished(unitID, unitDefID, teamID, builderID)
    if (AllyAIsalesEverything) then
        local _, _, _, isAiTeam = spGetTeamInfo(teamID)
        if isAiTeam then
            local unitDefID = spGetUnitDefID(unitID)
            if not unitDefID then return end
            local unitDef = UnitDefs[unitDefID]
            if not unitDef then return end
            if unitDef.metalCost <= 0 then return end

            local price = unitDef.metalCost
            setUnitOnSale(unitID, price, false)
        end
    end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	-- accepts: CMD_SELL_UNIT
	local unitDef = UnitDefs[unitDefID]
	if unitDef then
		local price = unitDef.metalCost
		setUnitOnSale(unitID, price, true)
	end
	return true
end

local function isTeamSaving(teamID)
    return TeamIsSaving[teamID]
end

function gadget:Initialize()
    gadgetHandler:RegisterAllowCommand(CMD_SELL_UNIT)
    local teamList = spGetTeamList()
	for _, teamID in ipairs(teamList) do
        TeamIsSaving[teamID] = false
        buildPower[teamID] = {}
	end
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID), spGetUnitTeam(unitID))
	end
    --
    if (AllyAIsalesEverything) then -- set all AI units for sale
        for _, unitID in ipairs(Spring.GetAllUnits()) do
            local teamID = spGetUnitTeam(unitID)
            local _, _, _, isAiTeam = spGetTeamInfo(teamID)
            if isAiTeam then
                local unitDefID = spGetUnitDefID(unitID)
                if unitDefID then
                    local unitDef = UnitDefs[unitDefID]
                    if unitDef and unitDef.metalCost >= 0 then
                        local price = unitDef.metalCost
                        setUnitOnSale(unitID, price, false)
                    end
                end
            end
        end
    end
    GG.isTeamSaving = isTeamSaving
end

function gadget:Shutdown()
    local teamList = spGetTeamList()
	for _, teamID in ipairs(teamList) do
        if TeamIsSaving[teamID] then
            SetTeamSavingMetal(teamID, false)
        end
    end
    GG.isTeamSaving = nil
end

else -- unsynced

    -- lets only broadcast these trades to allies and spectators
	local spGetSpectatingState = Spring.GetSpectatingState
	local spec, _ = spGetSpectatingState()
    local spGetPlayerInfo = Spring.GetPlayerInfo
	local myPlayerID = Spring.GetMyPlayerID()
    local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
    local spAreTeamsAllied = Spring.AreTeamsAllied
    local myTeamID = Spring.GetMyTeamID()
    local myAllyTeamID = Spring.GetMyAllyTeamID()

	function gadget:PlayerChanged(playerID)
        myPlayerID = Spring.GetMyPlayerID()
        myTeamID = Spring.GetMyTeamID()
        myAllyTeamID = Spring.GetMyAllyTeamID()
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("UnitSale", handleSaleEvent)
		gadgetHandler:AddSyncAction("UnitSold", handleSoldEvent)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("UnitSale")
		gadgetHandler:RemoveSyncAction("UnitSold")
	end

	function handleSaleEvent(_, unitID, price, msgFromTeamID)
		local spec, fullView = spGetSpectatingState()
		if not spec or not fullView then
            if not spAreTeamsAllied(msgFromTeamID, myTeamID) then return end
		end
		if Script.LuaUI("UnitSale") then
			Script.LuaUI.UnitSale(unitID, price, msgFromTeamID)
		end
	end

	function handleSoldEvent(_, unitID, price, old_ownerTeamID, msgFromTeamID)
		local spec, fullView = spGetSpectatingState()
		if not spec or not fullView then
            if not spAreTeamsAllied(msgFromTeamID, myTeamID) then return end
		end
		if Script.LuaUI("UnitSold") then
			Script.LuaUI.UnitSold(unitID, price, old_ownerTeamID, msgFromTeamID)
		end
	end
end
