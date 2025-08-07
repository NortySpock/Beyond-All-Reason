local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Disable Unit After Sharing',
		desc    = 'Disable unit after sharing, for N seconds, when modoption is enabled',
		author  = 'NortySpock',
		date    = 'August 2025',
		license = 'GNU GPL, v2 or later',
		layer   = 3,
		enabled = true
	}
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end

if Spring.GetModOptions().disable_unit_after_sharing then
	return true
end

function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
	if (capture) then
		return true
	end

	

	return true
end
