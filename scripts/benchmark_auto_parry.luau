-- Idle replay with cheap doubles; measures module work, not in-game FPS.
if not table.clear then table.clear = function(t) for key in pairs(t) do t[key] = nil end end end
local vectorMeta = {}
local function position(x) return setmetatable({ X = x, Y = 0, Z = 0 }, vectorMeta) end
vectorMeta.__sub = function(a, b) return position(a.X - b.X) end
vectorMeta.__index = function(v, key) if key == "Magnitude" then return math.abs(v.X) end end
local function measure(factory, nearby)
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
	local humanoid = { Health = 100, FindFirstChildOfClass = function() end }
	local root = { Position = position(0) }
	local character = {
		DescendantAdded = signal(), DescendantRemoving = signal(),
		FindFirstChild = function(_, name) lookups = lookups + 1 return name == "HumanoidRootPart" and root or {} end,
		FindFirstChildOfClass = function() lookups = lookups + 1 return humanoid end,
	}
	local enemyRoot = { Position = position(10) }
	local enemy = {
		DescendantAdded = signal(), DescendantRemoving = signal(),
		FindFirstChild = function() lookups = lookups + 1 return enemyRoot end,
		FindFirstChildOfClass = function() lookups = lookups + 1 return humanoid end,
		GetAttribute = function() return false end,
	}
	local player = { Team = { Name = "Survivors" }, Character = character, CharacterAdded = signal() }
	local killer = { Team = { Name = "Killer" }, Character = enemy, CharacterAdded = signal(), GetPropertyChangedSignal = function() return signal() end }
	local feature = factory({
		player = player,
		players = { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return { player, killer } end },
		runService = { Heartbeat = heartbeat }, storage = { FindFirstChild = function() end }, input = {},
		getEnabled = function() return enabled end, setEnabled = function(value) enabled = value end,
		report = function() end, emit = function() end, spawn = function(callback) callback() end,
	})
	feature._findClient = function()
		searches = searches + 1
		return { character = character, rootPart = root, humanoid = humanoid,
			tool = { IsDescendantOf = function() return true end },
			CanUse = function() readiness = readiness + 1 return false end }
	end
	feature.setEnabled(true)
	lookups, searches, readiness = 0, 0, 0
	local start = os.clock()
	if nearby then feature._observe(killer, { Name = "attack", IsPlaying = true, Animation = { AnimationId = "rbxassetid://1" } }) end
	for _ = 1, 20000 do heartbeat:Fire() end
	local ms = (os.clock() - start) * 1000
	feature.destroy()
	return string.format("%.2fms; %d character lookups; %d client lookup calls; %d readiness checks", ms, lookups, searches, readiness)
end
for _, path in ipairs(arg) do
	local factory = assert(loadfile(path))()
	print(path .. " idle: " .. measure(factory, false))
	print(path .. " nearby blocked attack: " .. measure(factory, true))
end
