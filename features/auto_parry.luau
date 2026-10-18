-- Observe replicated melee wind-ups, then use the already-running dagger client.
return function(context)
	local feature = {}
	local getupvalues = getupvalues or (debug and debug.getupvalues)
	local players, player = context.players, context.player
	local connections, watchers, cues, history, itemConnections = {}, {}, {}, {}, {}
	local pending, nativeClient, stepConnection, lastBlocked
	local lastClientSearch = -math.huge
	local now = context.clock or os.clock
	local spawn = context.spawn or function(callback) task.spawn(callback) end
	local delay = context.delay or function(seconds, callback) task.delay(seconds, callback) end
	local generation = 0
	local status = "Off"
	-- Replicated tracks may be named only "Animation". Match inspected attack assets too.
	local holdIds = { ["122812055447896"] = true, ["129784271201071"] = true }
	local attackIds = {
		["78935059863801"] = true, ["122812055447896"] = true, -- Veil
		["129784271201071"] = true, ["132817836308238"] = true, -- Jeff lunge/attack
		["82666958311998"] = true, -- Jeff AttackFrenzy-m, observed during Frenzy
	}
	local function report(text)
		if status == text then return end
		status = text
		context.report(text)
	end
	local function connect(list, signal, callback)
		local connection = signal:Connect(callback)
		list[#list + 1] = connection
		return connection
	end
	local function disconnect(list)
		for _, connection in ipairs(list) do connection:Disconnect() end
		table.clear(list)
	end
	local function equipped(client)
		return client and client.character == player.Character and client.tool
			and client.tool:IsDescendantOf(player.Character)
	end
	local function stopStepping()
		if stepConnection then stepConnection:Disconnect() stepConnection = nil end
	end
	function feature._findClient()
		if equipped(nativeClient) then return nativeClient end
		nativeClient = nil
		if now() - lastClientSearch < 0.5 then return nil end
		lastClientSearch = now()
		if type(getconnections) ~= "function" or type(getupvalues) ~= "function" then return nil end
		local folder = context.storage:FindFirstChild("Remotes")
		folder = folder and folder:FindFirstChild("Items")
		folder = folder and folder:FindFirstChild("Parrying Dagger")
		local result = folder and folder:FindFirstChild("parryResult")
		if not result then return nil end
		for _, connection in pairs(getconnections(result.OnClientEvent)) do
			if connection.Function then
				local ok, values = pcall(getupvalues, connection.Function)
				if ok then
					for _, value in pairs(values) do
						if type(value) == "table" and rawget(value, "player") == player
							and rawget(value, "tool") and type(value.CanUse) == "function"
							and type(value.Parry) == "function" and equipped(value) then
							nativeClient = value
							return value
						end
					end
				end
			end
		end
	end
	local function warmClient()
		generation = generation + 1
		local token = generation
		local function lookup(attempt)
			if token ~= generation or not context.getEnabled() then return end
			local found = feature._findClient()
			if token ~= generation or not context.getEnabled() then return end
			nativeClient = found
			if found then
				if next(cues) then
					if not stepConnection then stepConnection = context.runService.Heartbeat:Connect(feature._step) end
					feature._step()
				end
			elseif attempt < 3 then
				delay(0.5, function() lookup(attempt + 1) end)
			else report("Dagger client unavailable") end
		end
		spawn(function() lookup(1) end)
	end
	function feature._observe(killer, track, existing)
		local name = track.Name:lower()
		local id = track.Animation and track.Animation.AnimationId:match("%d+")
		if name ~= "attack" and name ~= "lungehold" and not attackIds[id] then return end
		local age = existing and track.TimePosition / math.max(math.abs(track.Speed), 0.001) or 0
		local character = killer.Character
		cues[killer] = { track = track, character = character, at = now() - age, observedAt = now(), holding = name == "lungehold" or holdIds[id] == true,
			root = character and character:FindFirstChild("HumanoidRootPart"),
			humanoid = character and character:FindFirstChildOfClass("Humanoid") }
		if not stepConnection then stepConnection = context.runService.Heartbeat:Connect(feature._step) end
		feature._step()
	end
	function feature._result(success, cooldown)
		if not pending or not pending.callAt then return end
		local sample = pending
		pending = nil
		sample.replyMs = (now() - sample.callAt) * 1000
		sample.success, sample.cooldown = success == true, tonumber(cooldown)
		history[#history + 1] = sample
		if #history > 12 then table.remove(history, 1) end
		report(string.format("Call %.0fms | reply %.0fms | %s", sample.localMs, sample.replyMs,
			sample.success and "parried" or "not parried"))
	end
	local function readyAtRange(killer, client, enemy, delta)
		if delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z > 225 then return false end
		if enemy:GetAttribute("IsStunned") then return false end
		-- Consume this cue even if native validation rejects it: never retry every frame.
		local cue = cues[killer]
		cues[killer] = nil
		local function blocked(reason)
			local animation = cue and cue.track.Animation
			lastBlocked = { at = now(), reason = reason, killer = killer.Name, distance = delta.Magnitude,
				animationId = animation and animation.AnimationId }
			report(reason)
			return false
		end
		if not equipped(client) then return blocked("No equipped dagger") end
		if client.isParryOnCooldown then return blocked("Dagger cooldown") end
		if client.isParryResolving then return blocked("Dagger resolving") end
		if client.isSilenced then return blocked("Dagger silenced") end
		local ok, ready = pcall(client.CanUse, client)
		if not ok or not ready then return blocked("Dagger not ready") end
		return true
	end
	function feature._step()
		if not context.getEnabled() then return end
		if not pending and next(cues) == nil then stopStepping() return end
		if pending then
			stopStepping()
			return
		end
		if not player.Team or not player.Team.Name:lower():match("^survivor") then
			table.clear(cues)
			stopStepping()
			report("Survivors only")
			return
		end
		local client = nativeClient
		if not client then stopStepping() return end
		local character = player.Character
		local root, humanoid = client.rootPart, client.humanoid
		if client.character ~= character or not root or not humanoid or humanoid.Health <= 0 then
			table.clear(cues)
			stopStepping()
			return
		end
		for killer, cue in pairs(cues) do
			local enemy = killer.Character
			local enemyRoot, enemyHumanoid = cue.root, cue.humanoid
			local age = now() - cue.at
			if enemy ~= cue.character or not cue.track.IsPlaying or not enemyRoot
				or (not cue.holding and age > 0.8) or not killer.Team or killer.Team.Name ~= "Killer"
				or not enemyHumanoid or enemyHumanoid.Health <= 0 then
				cues[killer] = nil
			else
				local delta = enemyRoot.Position - root.Position
				if readyAtRange(killer, client, enemy, delta) then
					local sample = { killer = killer.Name, cueAt = cue.observedAt, distance = delta.Magnitude }
					pending = sample
					stopStepping()
					spawn(function()
						if not context.getEnabled() or pending ~= sample or not equipped(client) then
							if pending == sample then pending = nil end
							return
						end
						sample.callAt = now()
						sample.localMs = (sample.callAt - sample.cueAt) * 1000
						delay(3, function()
							if pending ~= sample then return end
							sample.timeout = true
							history[#history + 1] = sample
							if #history > 12 then table.remove(history, 1) end
							pending = nil
							report("No parry result within 3s")
						end)
						report(string.format("Call %.0fms | awaiting result", sample.localMs))
						local accepted, err = pcall(client.Parry, client)
						if not accepted and pending == sample then
							pending = nil
							sample.error = tostring(err)
							report("Native parry failed")
						elseif pending == sample and not client.isParryResolving then
							pending = nil
							report("Native parry not accepted")
						end
					end)
					return
				end
			end
		end
		if next(cues) == nil then stopStepping() end
	end
	local function unwatch(other)
		local watcher = watchers[other]
		if not watcher then return end
		disconnect(watcher.connections)
		disconnect(watcher.characterConnections)
		watchers[other], cues[other] = nil, nil
	end
	local function watch(other)
		if other == player or watchers[other] then return end
		local watcher = { connections = {}, characterConnections = {} }
		watchers[other] = watcher
		local function bind(character)
			disconnect(watcher.characterConnections)
			cues[other] = nil
			if not other.Team or other.Team.Name ~= "Killer" then return end
			local bound
			local function animatorAdded(animator)
				if not animator:IsA("Animator") or bound == animator then return end
				bound = animator
				connect(watcher.characterConnections, animator.AnimationPlayed, function(track)
					if other.Team and other.Team.Name == "Killer" then feature._observe(other, track) end
				end)
				if other.Team and other.Team.Name == "Killer" then
					for _, track in ipairs(animator:GetPlayingAnimationTracks()) do feature._observe(other, track, true) end
				end
			end
			connect(watcher.characterConnections, character.DescendantAdded, animatorAdded)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
			if animator then animatorAdded(animator) end
		end
		connect(watcher.connections, other.CharacterAdded, bind)
		connect(watcher.connections, other:GetPropertyChangedSignal("Team"), function()
			if other.Character then bind(other.Character) end
		end)
		if other.Character then bind(other.Character) end
	end
	local function stop()
		generation = generation + 1
		stopStepping()
		disconnect(connections)
		disconnect(itemConnections)
		local others = {}
		for other in pairs(watchers) do others[#others + 1] = other end
		for _, other in ipairs(others) do unwatch(other) end
		table.clear(cues)
		pending = nil
		lastClientSearch = -math.huge
	end
	local function bindItem(character)
		disconnect(itemConnections)
		generation = generation + 1
		pending = nil
		if not equipped(nativeClient) then nativeClient = nil end
		lastClientSearch = -math.huge
		table.clear(cues)
		stopStepping()
		local refresh = 0
		connect(itemConnections, character.DescendantAdded, function(item)
			if item.Name == "Parrying Dagger" or item.Name == "Parry Dagger" then
				refresh = refresh + 1
				local token = refresh
				delay(0.1, function()
					if context.getEnabled() and token == refresh and player.Character == character then warmClient() end
				end)
			end
		end)
		connect(itemConnections, character.DescendantRemoving, function(item)
			if item.Name == "Parrying Dagger" or (nativeClient and item == nativeClient.tool) then
				generation = generation + 1
				nativeClient = nil
				table.clear(cues)
				stopStepping()
			end
		end)
		warmClient()
	end
	local function start()
		report("Watching attacks")
		local folder = context.storage:FindFirstChild("Remotes")
		folder = folder and folder:FindFirstChild("Items")
		folder = folder and folder:FindFirstChild("Parrying Dagger")
		local result = folder and folder:FindFirstChild("parryResult")
		if result then connect(connections, result.OnClientEvent, feature._result) end
		connect(connections, players.PlayerAdded, watch)
		connect(connections, players.PlayerRemoving, unwatch)
		connect(connections, player.CharacterAdded, bindItem)
		if player.Character then bindItem(player.Character) end
		for _, other in ipairs(players:GetPlayers()) do watch(other) end
		feature._step()
	end
	function feature.setEnabled(value)
		value = value == true
		if value == context.getEnabled() then return end
		context.setEnabled(value)
		if value then start() else stop() report("Off") end
		context.emit()
	end
	function feature.toggle() feature.setEnabled(not context.getEnabled()) end
	function feature.getDiagnostics()
		return { status = status, pending = pending, history = history, lastBlocked = lastBlocked,
			clientBound = equipped(nativeClient) == true, monitoring = stepConnection ~= nil }
	end
	function feature.destroy() stop() nativeClient = nil end
	if context.getEnabled() then start() end
	return feature
end
