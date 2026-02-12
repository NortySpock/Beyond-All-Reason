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
		local y = Spring.GetGroundHeight(locals.x, locals.z)
		return Spring.CreateUnit(locals.name, locals.x, y, locals.z, 0, locals.teamID)
	end, { name = commanderName, x = midX, z = midZ, teamID = myTeamID })

	-- Wait for unit to exist
	Test.waitFrames(1)

	-- Spawn target units: one just inside max range, one just outside
	local targetInsideX = midX + range - 5
	local targetOutsideX = midX + range + 10 -- bit more buffer for the splash logic

	local targetInsideID = SyncedRun(function(locals)
		local y = Spring.GetGroundHeight(locals.x, locals.z)
		return Spring.CreateUnit("armsolar", locals.x, y, locals.z, 0, locals.teamID)
	end, { x = targetInsideX, z = midZ, teamID = enemyTeamID })

	local targetOutsideID = SyncedRun(function(locals)
		local y = Spring.GetGroundHeight(locals.x, locals.z)
		return Spring.CreateUnit("armsolar", locals.x, y, locals.z, 0, locals.teamID)
	end, { x = targetOutsideX, z = midZ, teamID = enemyTeamID })

	Test.waitFrames(1)

	-- Force dgun order to a point far away to ensure it travels its full distance
	-- CMD.MANUALFIRE (D-Gun)
	local targetDgunX = midX + range + 100
	Spring.GiveOrderToUnit(comID, CMD.MANUALFIRE, { targetDgunX, 0, midZ }, 0)

	-- Wait enough frames for projectile to travel (velocity is 300, distance is ~300, so ~1-2 seconds)
	-- 60 frames = 2 seconds at 30 fps
	Test.waitFrames(60)

	-- Verify results: inside unit should be gone, outside unit should be alive
	local isInsideAlive = Spring.ValidUnitID(targetInsideID)
	local isOutsideAlive = Spring.ValidUnitID(targetOutsideID)

	assert(not isInsideAlive, string.format("%s failed to destroy target at range %d", commanderName, range - 5))
	assert(isOutsideAlive, string.format("%s destroyed target BEYOND its range at %d", commanderName, range + 10))

	-- Cleanup this run
	SyncedRun(function(locals)
		Spring.DestroyUnit(locals.comID, false, true)
		if Spring.ValidUnitID(locals.t1) then Spring.DestroyUnit(locals.t1, false, true) end
		if Spring.ValidUnitID(locals.t2) then Spring.DestroyUnit(locals.t2, false, true) end
	end, { comID = comID, t1 = targetInsideID, t2 = targetOutsideID })
end

function test() 
	-- Test Core Commander D-Gun (Range 262)
	runDgunRangeTest("corcom", 262)
	
	-- Test Arm Commander D-Gun (Range 250)
	runDgunRangeTest("armcom", 250)
end
