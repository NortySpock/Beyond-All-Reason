function skip()
	return false
end

function setup()
	Test.clearMap()

	Spring.SendCommands("editdefs 1")
	Spring.SendCommands("globallos")
	Spring.SendCommands("setspeed 5")
end

function cleanup()
	Test.clearMap()

	Spring.SendCommands("globallos")
	Spring.SendCommands("setspeed 1")
	Spring.SendCommands("editdefs 0")
end

function createUnits()
	SyncedRun(function(locals)
		local flightTime = locals.flightTime
		 
	end)

	local units, unitNames = SyncedRun(function(locals)
		local midX, midZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
		local units = {}
		local unitNames = {}
		local function createUnit(def, x, z, teamID)
			local x = midX + x
			local z = midZ + z
			local y = Spring.GetGroundHeight(x, z)
			local unitID = Spring.CreateUnit(def, x, y, z, "south", teamID)
			units[#units+1] = unitID
			unitNames[def] = unitID
			return unitID
		end

		createUnit("armafus", 100, -500, 0) 

		return units, unitNames
	end)

	Test.waitFrames(1)

 
	local isAlive = Spring.ValidUnitID(unitNames["armafus"])
	
	assert(isAlive == true)

	--Test.waitFrames(300) --for replay debugging
end

function test()
	createUnits()
 
end
