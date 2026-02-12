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

local function runDgunRangeTest(commanderName, range)
	local myTeamID = Spring.GetMyTeamID()
	local enemyTeamID = 1 - myTeamID -- Assume team 0 and 1 exist in tests

	local midX, midZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
	
	-- Spawn Commander
	local comID = SyncedRun(function(locals)
		local y = Spring.GetGroundHeight(locals.midX, locals.midZ)
		return Spring.CreateUnit(locals.commanderName, locals.midX, y, locals.midZ, 0, locals.myTeamID)
	end)
	
	-- Spawn target units: one just inside max range, one just outside
	local targetInsideX = midX + range - 50
	local targetOutsideX = midX - range - 10 -- opposite side

	local targetInsideID = SyncedRun(function(locals)
		local y = Spring.GetGroundHeight(locals.targetInsideX, locals.midZ)
		return Spring.CreateUnit("armsolar", locals.targetInsideX, y, locals.midZ, 0, locals.enemyTeamID)
	end)

	local targetOutsideID = SyncedRun(function(locals)
		local y = Spring.GetGroundHeight(locals.targetOutsideX, locals.midZ)
		return Spring.CreateUnit("armsolar", locals.targetOutsideX, y, locals.midZ, 0, locals.enemyTeamID)
	end)

	Test.waitFrames(1)

	local targetDgunX = targetInsideX
	Spring.GiveOrderToUnit(comID, CMD.MANUALFIRE, { targetDgunX, 0, midZ }, 0)

	-- Wait enough frames for projectile to travel (velocity is 300, distance is ~300, so ~1-2 seconds)
	-- 60 frames = 2 seconds at 30 fps
	Test.waitFrames(120)

	-- Verify results: inside unit should be gone, outside unit should be alive
	local isInsideAlive = Spring.ValidUnitID(targetInsideID)
	local isOutsideAlive = Spring.ValidUnitID(targetOutsideID)

	assert(not isInsideAlive, string.format("%s failed to destroy target at range %d", commanderName, range - 5))
	assert(isOutsideAlive, string.format("%s destroyed target BEYOND its range at %d", commanderName, range + 10))

	-- Cleanup this run
	SyncedRun(function(locals)
		Spring.DestroyUnit(locals.comID, false, true)
		if Spring.ValidUnitID(locals.targetInsideID) then Spring.DestroyUnit(locals.targetInsideID, false, true) end
		if Spring.ValidUnitID(locals.targetOutsideID) then Spring.DestroyUnit(locals.targetOutsideID, false, true) end
	end)
end

function test() 
	-- Test Core Commander D-Gun (Range 262)
	runDgunRangeTest("corcom", 262)
	
	-- Test Arm Commander D-Gun (Range 250)
	runDgunRangeTest("armcom", 250)
end
