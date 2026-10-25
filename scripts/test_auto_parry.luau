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
		local humanoid = { Health = 100, HealthChanged = signal(), IsA = function(_, class) return class == "Humanoid" end, FindFirstChildOfClass = function() end }
		local model = { DescendantAdded = signal(), DescendantRemoving = signal(), dagger = true, stunned = false }
		function model:FindFirstChild(name)
			if name == "Animations" then return self.animationsScript end
			if name == "HumanoidRootPart" then return root end
			if name == "Parrying Dagger" and self.dagger then return {} end
		end
		function model:FindFirstChildOfClass() return humanoid end
		function model:GetAttribute(name) return name == "IsStunned" and self.stunned end
		return model, root, humanoid
	end
	local localCharacter, localRoot, localHumanoid = character(0)
	local enemy, enemyRoot, enemyHumanoid = character(13.01)
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
	local sourceReads = 0
	enemy.animationsScript = { Name = "Animations", IsA = function(_, class) return class == "LocalScript" end }
	local function runTimers()
		for index = #timers, 1, -1 do
			if timers[index].at <= clock then
				local timer = table.remove(timers, index)
				timer.callback()
			end
		end
	end
	local feature = factory({
		readAnimationSource = function()
			sourceReads = sourceReads + 1
			return [[local controller = start({
				vmAnimations = {attack = "rbxassetid://900000001"},
				animations = {lungehold = "rbxassetid://900000002", attack = "rbxassetid://900000003"},
				trackAnimations = {Stunned = "rbxassetid://900000004"}
			})]]
		end,
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
	expect(sourceReads == 1, "Character setup did not cache its animation source")
	killer.Team.Name = "Survivors" teamChanged:Fire()
	expect(enemy.DescendantAdded:count() == 0, "Survivor retained character animation monitoring")
	killer.Team.Name = "Killer" teamChanged:Fire()
	expect(enemy.DescendantAdded:count() == 1, "Killer role change did not restore character monitoring")
	feature._observe(killer, track("RunAnim"))
	expect(calls == 0, "Non-attack animation triggered parry")
	feature._observe(killer, track())
	expect(calls == 0, "Killer outside 13 studs triggered parry")
	expect(clientSearches == setupSearches and readinessChecks == 0, "Distant attack performed expensive native checks")
	expect(heartbeat:count() == 1, "Attack cue did not install range monitoring")
	enemyRoot.Position = Vector3.new(13, 0, 0)
	clock = clock + 0.02
	heartbeat:Fire()
	expect(calls == 1 and client.isParryResolving, "Entering 13 studs during wind-up did not activate native client")
	expect(heartbeat:count() == 0, "Pending result retained a frame loop")
	expect(math.abs(feature.getDiagnostics().pending.localMs - 20) < 0.00001, "Cue-to-call timing is incorrect")
	reply:Fire(false, 60, false, false, {})
	expect(feature.getDiagnostics().pending ~= nil, "Another character's parry result consumed the request")
	reply:Fire(false, 0, false, true, player.Character)
	expect(feature.getDiagnostics().pending ~= nil, "Cooldown reset consumed the request")
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
	local blockedCue = feature.getDiagnostics().lastBlocked
	expect(blockedCue and blockedCue.reason == "Dagger not ready" and blockedCue.animationId == "rbxassetid://1",
		"Native rejection after an earlier success was hidden")
	expect(text == "Dagger not ready", "Blocked cue left an old success status visible")
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
	for _, id in ipairs({ "129784271201071", "132817836308238", "82666958311998" }) do
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
	for _, item in ipairs({ { "isParryOnCooldown", "Dagger cooldown" }, { "isSilenced", "Dagger silenced" } }) do
		client[item[1]] = true
		local beforeReadiness, beforeCalls = readinessChecks, calls
		feature._observe(killer, track())
		expect(feature.getDiagnostics().lastBlocked.reason == item[2] and text == item[2], "Native blocking reason was lost")
		for _ = 1, 1000 do heartbeat:Fire() end
		expect(readinessChecks == beforeReadiness and calls == beforeCalls and heartbeat:count() == 0,
			"Blocked cue performed repeated readiness or parry work")
		client[item[1]] = false
	end
	local beforeLongHold = calls
	enemyRoot.Position = Vector3.new(14, 0, 0)
	local held = track("lungehold")
	feature._observe(killer, held)
	clock = clock + 3
	heartbeat:Fire()
	expect(calls == beforeLongHold and heartbeat:count() == 1, "Long hold was lost or activated outside 13 studs")
	enemyRoot.Position = Vector3.new(13, 0, 0)
	heartbeat:Fire()
	expect(calls == beforeLongHold + 1, "Entering 13 studs after a long hold did not parry")
	result(false)
	enemyRoot.Position = Vector3.new(14, 0, 0) heartbeat:Fire()
	enemyRoot.Position = Vector3.new(12, 0, 0) heartbeat:Fire()
	expect(calls == beforeLongHold + 1 and heartbeat:count() == 0, "Same held signal repeated the attempt")
	for _, id in ipairs({ "122812055447896", "129784271201071" }) do
		local existingHold = track("Animation")
		existingHold.Animation.AnimationId = "rbxassetid://" .. id
		existingHold.TimePosition = 4
		local before = calls
		feature._observe(killer, existingHold, true)
		expect(calls == before + 1, "Already-playing generic melee hold was treated as expired")
		result(false)
	end
	local function cancelledHold(change, message)
		enemyRoot.Position = Vector3.new(14, 0, 0)
		local hold = track("lungehold")
		local before = calls
		feature._observe(killer, hold)
		clock = clock + 2
		change(hold)
		enemyRoot.Position = Vector3.new(12, 0, 0)
		heartbeat:Fire()
		expect(calls == before and heartbeat:count() == 0, message)
	end
	cancelledHold(function(hold) hold.IsPlaying = false end, "Cancelled long hold triggered or retained its monitor")
	cancelledHold(function() enemyHumanoid.Health = 0 end, "Dead killer retained its held cue")
	enemyHumanoid.Health = 100
	cancelledHold(function() killer.Team.Name = "Survivors" end, "Role change retained a held attack monitor")
	killer.Team.Name = "Killer"
	enemyRoot.Position = Vector3.new(14, 0, 0)
	local beforeExpired = calls
	feature._observe(killer, track("attack"))
	clock = clock + 1
	enemyRoot.Position = Vector3.new(12, 0, 0)
	heartbeat:Fire()
	expect(calls == beforeExpired and heartbeat:count() == 0, "Completed swing was incorrectly kept as a persistent hold")
	-- Generic replicated tracks must work without meaningful track names.
	for _, row in ipairs({
		{ "Stalker", "117042998468241", "133963973694098" },
		{ "Killer", "129784271201071", "132817836308238" },
		{ "Hidden", "113255068724446", "74968262036854" },
		{ "Abysswalker", "118907603246885", "78432063483146" },
		{ "Veil", "122812055447896", "78935059863801" },
		{ "Halloween Veil", "84926129581106", "81963230963908" },
		{ "Butcher", "127417297154354", "83333467665074" },
		{ "Fresh controller discovered on spawn", "900000002", "900000003" },
		{ "Slasher", "110355011987939", "139369275981139" },
		{ "Masked", "105374834496520", "111920872708571" },
		{ "Cure candidate", "135002183282873", "121216847022485" },
	}) do
		local held = track("Animation")
		held.Animation.AnimationId = "http://www.roblox.com/asset/?id=" .. row[2]
		held.TimePosition = 4
		enemyRoot.Position = Vector3.new(14, 0, 0)
		local before = calls
		feature._observe(killer, held, true)
		clock = clock + 3 heartbeat:Fire()
		expect(calls == before and heartbeat:count() == 1, row[1] .. " hold expired or activated outside range")
		enemyRoot.Position = Vector3.new(13, 0, 0) heartbeat:Fire()
		expect(calls == before + 1, row[1] .. " generic held cue was missed")
		result(false)
		local swing = track("Animation")
		swing.Animation.AnimationId = "rbxassetid://" .. row[3]
		feature._observe(killer, swing)
		expect(calls == before + 2, row[1] .. " generic swing was missed")
		result(false)
		enemyRoot.Position = Vector3.new(14, 0, 0)
		feature._observe(killer, swing)
		clock = clock + 1
		enemyRoot.Position = Vector3.new(13, 0, 0) heartbeat:Fire()
		expect(calls == before + 2 and heartbeat:count() == 0, row[1] .. " finished swing became a persistent hold")
	end
	for _, id in ipairs({ "80411309607666", "98163597193511", "130593238885843", "138720291317243" }) do
		local special = track("Animation")
		special.Animation.AnimationId = "rbxassetid://" .. id
		local before = calls
		feature._observe(killer, special)
		expect(calls == before + 1, "Special attack was missed: " .. id)
		result(false)
	end
	for _, id in ipairs({ "92098503722633", "111229698330816", "135181748009911", "117070354890871", "106871536134254" }) do
		local other = track("Animation")
		other.Animation.AnimationId = "rbxassetid://" .. id
		local before = calls
		feature._observe(killer, other)
		expect(calls == before and heartbeat:count() == 0, "Movement, startup or non-melee animation triggered parry: " .. id)
	end
	enemyRoot.Position = Vector3.new(12, 0, 0)
	local beforeUnknown = calls
	for i = 1, 20 do feature._observe(killer, track("Unknown" .. i)) end
	local evidence = feature.getDiagnostics().observations
	expect(#evidence == 16 and evidence[16].recognized == false and evidence[16].distance == 12,
		"Unknown nearby animation evidence was absent or unbounded")
	expect(calls == beforeUnknown and heartbeat:count() == 0, "Unknown animation activated dagger or frame monitoring")
	localHumanoid.HealthChanged:Fire(60)
	local damage = feature.getDiagnostics().lastDamage
	expect(damage and damage.from == 100 and damage.health == 60 and #damage.observations == 16 and damage.distances.Killer == 12,
		"Damage did not snapshot recent nearby cue evidence")
	localCharacter.DescendantRemoving:Fire({ Name = "Parrying Dagger" })
	expect(feature.getDiagnostics().lastDamage == damage, "Unequipping discarded the missed-hit evidence")
	clock = clock + 1
	localCharacter.DescendantAdded:Fire({ Name = "Parrying Dagger", IsA = function() return false end })
	clock = clock + 1 runTimers()
	-- A dagger initialized after all setup retries must recover on a fresh cue.
	localCharacter.DescendantRemoving:Fire(client.tool)
	local search = feature._findClient
	local delayedSearches = 0
	feature._findClient = function() delayedSearches = delayedSearches + 1 return nil end
	localCharacter.DescendantAdded:Fire({ Name = "Parrying Dagger", IsA = function() return false end })
	clock = clock + 0.2 runTimers()
	clock = clock + 0.6 runTimers()
	clock = clock + 0.6 runTimers()
	expect(not feature.getDiagnostics().clientBound and delayedSearches == 3, "Setup retries did not remain bounded")
	for _ = 1, 1000 do heartbeat:Fire() end
	expect(delayedSearches == 3, "Unbound dagger performed per-frame client searches")
	feature._findClient = search
	local lateCue = track("Animation")
	lateCue.Animation.AnimationId = "rbxassetid://135002183282873"
	local beforeRecovery = calls
	feature._observe(killer, lateCue)
	expect(feature.getDiagnostics().clientBound and calls == beforeRecovery + 1, "Late native dagger did not recover on Cure's cue")
	expect(heartbeat:count() == 0, "Recovered native attempt retained a frame monitor")
	result(false)
	expect(sourceReads == 1, "Combat or role changes repeated source discovery for an unchanged script")
	for _, id in ipairs({ "900000001", "900000004" }) do
		local nonMelee = track("Animation") nonMelee.Animation.AnimationId = "rbxassetid://" .. id
		local beforeIgnore = calls
		feature._observe(killer, nonMelee)
		expect(calls == beforeIgnore, "Viewmodel or stun asset was classified as melee")
	end
	expect(not feature._registerAnimationSource('return { vmAnimations = { attack="rbxassetid://900000005" } }'),
		"Source without a third-person table was accepted")
	expect(not feature._registerAnimationSource('return { animations = { attack=chooseTrack() } }'),
		"Computed animation value was guessed")
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
