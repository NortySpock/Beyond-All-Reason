function skip()
	return Spring.GetGameFrame() <= 0
end

function setup()
	Test.clearMap()
	-- Enable UnitCommand callin for tests
	Test.expectCallin("UnitCommand")
end

function cleanup()
	Test.clearMap()
end

function test() 
	local myTeamID = Spring.GetMyTeamID()

	local middleX, middleZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
	local targetOffset = 100
	local targetX, targetZ = middleX + targetOffset, middleZ + targetOffset

	unitID = SyncedRun(function(locals)
		local x, z = middleX, middleZ
		local y = Spring.GetGroundHeight(x, z)
		return Spring.CreateUnit("corcom", x, y, z, 0, locals.myTeamID)
	end)

	local CMD_DGUN = CMD.MANUALFIRE

	Spring.GiveOrderToUnit(unitID, CMD_DGUN, { 1, 1, 1 }, 0)
	Test.waitUntilCallinArgs("UnitCommand", { nil, nil, nil, CMD_DGUN, nil, nil, nil })
	Spring.GiveOrderToUnit(unitID, CMD.MOVE, { 1, 1, 1 }, 0)
 
end
