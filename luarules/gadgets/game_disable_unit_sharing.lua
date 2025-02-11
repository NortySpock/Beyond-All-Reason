function gadget:GetInfo()
	return {
		name    = 'Disable Unit Sharing',
		desc    = 'Disable unit sharing when modoption is enabled',
		author  = 'Rimilel',
		date    = 'April 2024',
		license = 'GNU GPL, v2 or later',
		layer   = 0,
		enabled = true
	}
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end

local tax_resource_sharing_enabled = Spring.GetModOptions().tax_resource_sharing_amount ~= nil and Spring.GetModOptions().tax_resource_sharing_amount > 0
local disable_share_econ_and_lab = Spring.GetModOptions().disable_unit_sharing_economy_and_production or tax_resource_sharing_enabled
local disable_share_combat_units = Spring.GetModOptions().disable_unit_sharing_combat_units
local disable_share_all = Spring.GetModOptions().disable_unit_sharing_all

if not disable_share_econ_and_lab and not disable_share_combat_units and not disable_share_all then 
	return false
end



local isEconOrLab = {} 
local isCombatUnitOrTacticalBuilding = {} 

for unitDefID, unitDef in pairs(UnitDefs) do
	-- Mark labs and mobile production
	-- Mark econ units
	local treatAsCombatUnit = unitDef.customParams.disableunitsharing_treatascombatunit == "1"
	if not treatAsCombatUnit then
		if unitDef.customParams.unitgroup == "energy" or unitDef.customParams.unitgroup == "metal" then
			isEconOrLab[unitDefID] = true
		elseif unitDef.canResurrect then
			isEconOrLab[unitDefID] = true
		elseif (unitDef.isFactory or unitDef.isBuilder) then
			isEconOrLab[unitDefID] = true
		end
	end

	-- Mark combat units and tactical buildings
	if unitDef.isBuilding and not isEconOrLab[unitDefID] then 
		isCombatUnitOrTacticalBuilding[unitDefID] = true
	elseif #unitDef.weapons > 0 or treatAsCombatUnit then
		isCombatUnitOrTacticalBuilding[unitDefID] = true
	end
end


-- Returns whether the unit is allowed to be shared according to the unit sharing restrictions.
local function unitTypeAllowedToBeShared(unitDefID)
	if disable_share_all then return false end
	if disable_share_econ_and_lab and isEconOrLab[unitDefID] then return false end
	if disable_share_combat_units and isCombatUnitOrTacticalBuilding[unitDefID] then return false end
	return true
end
GG.disable_unit_sharing_unitTypeAllowedToBeShared = unitTypeAllowedToBeShared

if Spring.GetModOptions().unit_market then
	-- let unit market handle unit sharing so that buying units will still work. 
	return false
end


function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
	if(capture) then
		return true
	end
	return unitTypeAllowedToBeShared(unitDefID)
end



