-- Isolated signals and native-client double: never sends remotes or presses input.
return function(factory)
	local getupvalues = getupvalues or (debug and debug.getupvalues)
	local signals, checks, calls, clock, enabled = {}, 0, 0, 10, false
	local function signal()
		local handlers = {}
		local event = {}
		function event:Connect(callback)
			local connection = { Connected = true }
			function connection:Disconnect() self.Connected = false end
			handlers[#handlers + 1] = { connection = connection, callback = callback }
			return connection
		end
		function event:Fire(...)
			for _, h in ipairs(handlers) do if h.connection.Connected then h.callback(...) end end
		end
		function event:count()
			local n = 0
			for _, h in ipairs(handlers) do if h.connection.Connected then n = n + 1 end end
			return n
		end
		signals[#signals + 1] = event
		return event
	end
	local function character(x)
		local root = { Position = Vector3.new(x, 0, 0) }
		local humanoid = { Health = 100, FindFirstChildOfClass = function() end }
		local model = { DescendantAdded = signal(), DescendantRemoving = signal(), dagger = true, stunned = false }
		function model:FindFirstChild(name)
			if name == "HumanoidRootPart" then return root end
			if name == "Parrying Dagger" and self.dagger then return {} end
		end
		function model:FindFirstChildOfClass() return humanoid end
		function model:GetAttribute(name) return name == "IsStunned" and self.stunned end
		return model, root, humanoid
	end
	local localCharacter, localRoot, localHumanoid = character(0)
	local enemy, enemyRoot, enemyHumanoid = character(16)
	local player = { Name = "Local", Character = localCharacter, Team = { Name = "Survivors" }, CharacterAdded = signal() }
	local killer = { Name = "Killer", Character = enemy, Team = { Name = "Killer" }, CharacterAdded = signal() }
	local teamChanged = signal()
	function killer:GetPropertyChangedSignal() return teamChanged end
	local players = { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return { player, killer } end }
	local reply, heartbeat = signal(), signal()
	local lookupReply = reply
	local folder = { FindFirstChild = function(self, name)
		if name == "parryResult" then return { OnClientEvent = lookupReply } end
		return self
	end }
	local client = { player = player, character = localCharacter, rootPart = localRoot, humanoid = localHumanoid,
		blocked = false, isParryResolving = false }
	client.tool = { IsDescendantOf = function(_, model) return model == localCharacter and localCharacter.dagger end }
	local readinessChecks, clientSearches = 0, 0
	function client:CanUse() readinessChecks = readinessChecks + 1 return not self.blocked and not self.isParryResolving end
	function client:Parry() calls = calls + 1 self.isParryResolving = true end
	local text, deferred, queue = "", false, {}
	local input = {}
	local timers = {}
	local function runTimers()
		for index = #timers, 1, -1 do
			if timers[index].at <= clock then
				local timer = table.remove(timers, index)
				timer.callback()
			end
		end
	end
	local feature = factory({
		players = players, player = player, input = input, storage = folder,
		runService = { Heartbeat = heartbeat }, clock = function() return clock end,
		spawn = function(callback) if deferred then queue[#queue + 1] = callback else callback() end end,
		delay = function(seconds, callback) timers[#timers + 1] = { at = clock + seconds, callback = callback } end,
		getEnabled = function() return enabled end, setEnabled = function(value) enabled = value end,
		report = function(value) text = value end, emit = function() end,
	})
	local function expect(value, message) assert(value, message) checks = checks + 1 end
	if type(getconnections) == "function" and type(getupvalues) == "function" then
		local event = Instance.new("BindableEvent")
		lookupReply = event.Event
		local connection = event.Event:Connect(function() return client end)
		local found = feature._findClient()
		connection:Disconnect() event:Destroy()
		lookupReply = reply
		expect(found == client, "Could not discover the native-client callback upvalue")
	end
	feature._findClient = function() clientSearches = clientSearches + 1 return client end
	local function track(name)
		return { Name = name or "attack", IsPlaying = true, TimePosition = 0, Speed = 1,
			Animation = { AnimationId = "rbxassetid://1" } }
	end
	local function result(success)
		client.isParryResolving = false
		reply:Fire(success, success and 90 or 60)
	end
	feature._step()
	expect(calls == 0 and heartbeat:count() == 0, "Disabled feature subscribed or activated")
	feature.setEnabled(true)
	expect(heartbeat:count() == 0, "Idle enable installed a Heartbeat loop")
	local setupSearches = clientSearches
	feature.setEnabled(true)
	expect(heartbeat:count() == 0, "Repeated idle enable installed a Heartbeat loop")
	for _ = 1, 1000 do heartbeat:Fire() end
	expect(clientSearches == setupSearches and readinessChecks == 0, "Idle feature searched callbacks or checked native readiness")
	killer.Team.Name = "Survivors" teamChanged:Fire()
	expect(enemy.DescendantAdded:count() == 0, "Survivor retained character animation monitoring")
	killer.Team.Name = "Killer" teamChanged:Fire()
	expect(enemy.DescendantAdded:count() == 1, "Killer role change did not restore character monitoring")
	feature._observe(killer, track("RunAnim"))
	expect(calls == 0, "Non-attack animation triggered parry")
	feature._observe(killer, track())
	expect(calls == 0, "Killer outside 15 studs triggered parry")
	expect(clientSearches == setupSearches and readinessChecks == 0, "Distant attack performed expensive native checks")
	expect(heartbeat:count() == 1, "Attack cue did not install range monitoring")
	enemyRoot.Position = Vector3.new(15, 0, 0)
	clock = clock + 0.02
	heartbeat:Fire()
	expect(calls == 1 and client.isParryResolving, "Entering 15 studs during wind-up did not activate native client")
	expect(heartbeat:count() == 0, "Pending result retained a frame loop")
	expect(math.abs(feature.getDiagnostics().pending.localMs - 20) < 0.00001, "Cue-to-call timing is incorrect")
	heartbeat:Fire()
	expect(calls == 1, "Pending request repeated parry")
	clock = clock + 0.12
	result(true)
	local last = feature.getDiagnostics().history[1]
	expect(last.success and last.cooldown == 90 and math.abs(last.replyMs - 120) < 0.00001,
		"Reply result or observed round-trip timing is incorrect")
	heartbeat:Fire()
	expect(calls == 1, "Same attack triggered twice")
	expect(heartbeat:count() == 0, "Resolved cue retained the Heartbeat loop")
	client.blocked = true
	local beforeChecks, beforeSearches = readinessChecks, clientSearches
	feature._observe(killer, track("lungehold"))
	expect(calls == 1, "Blocked native dagger was activated")
	for _ = 1, 1000 do heartbeat:Fire() end
	expect(readinessChecks == beforeChecks + 1 and clientSearches == beforeSearches,
		"Nearby rejected cue repeatedly checked native readiness or searched callbacks")
	expect(heartbeat:count() == 0, "Nearby rejected cue retained a frame loop")
	client.blocked = false
	localCharacter.dagger = false
	feature._observe(killer, track())
	expect(calls == 1 and text == "No equipped dagger", "Missing dagger did not block activation")
	localCharacter.dagger = true
	clock = clock + 0.81
	heartbeat:Fire()
	expect(calls == 1, "Expired attack cue triggered parry")
	expect(heartbeat:count() == 0, "Expired cue retained the Heartbeat loop")
	local stopped = track() stopped.IsPlaying = false
	feature._observe(killer, stopped)
	expect(calls == 1, "Stopped animation triggered parry")
	enemy.stunned = true
	feature._observe(killer, track())
	expect(calls == 1, "Stunned killer triggered parry")
	enemy.stunned = false
	enemyHumanoid.Health = 0
	feature._observe(killer, track())
	expect(calls == 1, "Dead killer triggered parry")
	enemyHumanoid.Health = 100
	player.Team.Name = "Killer"
	feature._observe(killer, track())
	expect(calls == 1, "Non-survivor activated dagger")
	player.Team.Name = "Survivors"
	feature._observe(killer, track())
	expect(calls == 2, "Fresh attack did not activate")
	expect(feature.getDiagnostics().pending.localMs == 0, "Attack event introduced a polling delay")
	clock = clock + 0.1 result(false)
	expect(feature.getDiagnostics().history[2].success == false, "Failed parry reported success")
	feature._observe(killer, track())
	clock = clock + 3.1 runTimers()
	expect(feature.getDiagnostics().pending == nil and text == "No parry result within 3s", "Missing reply retained pending request")
	client.isParryResolving = false
	for _, id in ipairs({ "129784271201071", "132817836308238" }) do
		local generic = track("Animation")
		generic.Animation.AnimationId = "rbxassetid://" .. id
		local beforeCalls = calls
		feature._observe(killer, generic)
		expect(calls == beforeCalls + 1, "Generic replicated Jeff attack track was missed")
		result(false)
	end
	local idle = track("Animation")
	idle.Animation.AnimationId = "rbxassetid://134758728973154"
	local beforeCalls = calls
	feature._observe(killer, idle)
	expect(calls == beforeCalls, "Generic replicated idle track triggered parry")
	deferred = true
	feature._observe(killer, track())
	local before = calls
	feature.setEnabled(false)
	for _, callback in ipairs(queue) do callback() end
	expect(calls == before, "Disable did not cancel queued activation")
	for _, event in ipairs(signals) do expect(event:count() == 0, "Disable leaked an event connection") end
	feature.destroy()
	return string.format("PASS: %d auto-parry assertions; range, native readiness, timing, deduplication and cleanup", checks)
end
