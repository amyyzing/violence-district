-- Idle replay with cheap doubles; measures module work, not in-game FPS.
table.clear = table.clear or function(t) for key in pairs(t) do t[key] = nil end end
local function measure(factory)
	local function signal()
		local callbacks = {}
		return {
			Connect = function(_, callback)
				local connection = { active = true }
				function connection:Disconnect() self.active = false end
				callbacks[#callbacks + 1] = { connection, callback }
				return connection
			end,
			Fire = function()
				for _, entry in ipairs(callbacks) do if entry[1].active then entry[2]() end end
			end,
		}
	end
	local heartbeat, enabled = signal(), false
	local lookups, searches, readiness = 0, 0, 0
	local character = {
		FindFirstChild = function() lookups = lookups + 1 return {} end,
		FindFirstChildOfClass = function() lookups = lookups + 1 return { Health = 100 } end,
	}
	local player = { Team = { Name = "Survivors" }, Character = character, CharacterAdded = signal() }
	local feature = factory({
		player = player,
		players = { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return { player } end },
		runService = { Heartbeat = heartbeat }, storage = { FindFirstChild = function() end }, input = {},
		getEnabled = function() return enabled end, setEnabled = function(value) enabled = value end,
		report = function() end, emit = function() end, spawn = function(callback) callback() end,
	})
	feature._findClient = function()
		searches = searches + 1
		return { CanUse = function() readiness = readiness + 1 return true end }
	end
	feature.setEnabled(true)
	lookups, searches, readiness = 0, 0, 0
	local start = os.clock()
	for _ = 1, 20000 do heartbeat:Fire() end
	local ms = (os.clock() - start) * 1000
	feature.destroy()
	return string.format("%.2fms; %d character lookups; %d client lookup calls; %d readiness checks", ms, lookups, searches, readiness)
end
for _, path in ipairs(arg) do
	print(path .. ": " .. measure(assert(loadfile(path))()))
end
