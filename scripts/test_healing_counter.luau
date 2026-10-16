-- Isolated character fixtures; never changes the player's health or attributes.
return function(guiSource)
	local added, removing, changed = Instance.new("BindableEvent"), Instance.new("BindableEvent"), Instance.new("BindableEvent")
	local guiRoot, playerGui = Instance.new("Folder"), Instance.new("Folder")
	local characters, controller = {}, nil
	local function character(progress, withHumanoid)
		local model = Instance.new("Model")
		model:SetAttribute("HealProgress", progress)
		if withHumanoid then
			local humanoid = Instance.new("Humanoid")
			humanoid.Health = 60
			humanoid.Parent = model
		end
		characters[#characters + 1] = model
		return model
	end
	local player = { Character = character(70, true), CharacterAdded = added.Event, CharacterRemoving = removing.Event }
	function player:WaitForChild() return playerGui end
	local state = { skillCheckMode = "Perfect" }
	local logic = { Version = 88, SpearAimFovRadius = 120, Changed = changed.Event, start = function() end, getState = function() return state end }
	for _, name in ipairs({ "setHighlightsEnabled", "setSkillCheckEnabled", "setProjectileVisualiserEnabled", "setSpearAimEnabled", "setAutoParryEnabled", "setSkillCheckMode" }) do
		logic[name] = function() end
	end
	logic.getFeatureAvailability = function() return {} end
	local globals = { ViolenceDistrictLogic = logic }
	local proxy = {}
	function proxy:GetService(name)
		if name == "Players" then return { LocalPlayer = player } end
		if name == "CoreGui" then return guiRoot end
		return game:GetService(name)
	end
	local chunk = assert(loadstring(guiSource))
	local environment = setmetatable({ game = proxy, getgenv = function() return globals end }, { __index = getfenv() })
	setfenv(chunk, environment)
	local checks = 0
	local function expect(text)
		task.wait()
		assert(controller.Gui.Panel.Content.HealingCounter.Text == text, "Unexpected healing counter: " .. controller.Gui.Panel.Content.HealingCounter.Text)
		checks = checks + 1
	end
	local ok, err = pcall(function()
		controller = chunk()
		expect("Heal 70/100")
		player.Character:SetAttribute("HealProgress", 80)
		expect("Heal 80/100")
		player.Character.Humanoid.Health = 100
		expect("Heal 100/100")
		player.Character.Humanoid.Health = 60
		player.Character:SetAttribute("HealProgress", nil)
		expect("Heal —/100")
		local previous = player.Character
		player.Character = character(25.5, true)
		added:Fire(player.Character)
		expect("Heal 25.5/100")
		previous:SetAttribute("HealProgress", 10)
		expect("Heal 25.5/100")
		removing:Fire(player.Character)
		expect("Heal —/100")
		player.Character = character(33, false)
		added:Fire(player.Character)
		expect("Heal —/100")
		local humanoid = Instance.new("Humanoid")
		humanoid.Health = 60
		humanoid.Parent = player.Character
		expect("Heal 33/100")
		player.Character:SetAttribute("HealProgress", 150)
		expect("Heal 100/100")
		player.Character:SetAttribute("HealProgress", -2)
		expect("Heal 0/100")
		controller.destroy()
		task.wait()
		assert(#getconnections(added.Event) == 0 and #getconnections(removing.Event) == 0, "Character listeners survived GUI cleanup")
		checks = checks + 1
	end)
	if controller then controller.destroy() end
	for _, model in ipairs(characters) do model:Destroy() end
	for _, object in ipairs({ added, removing, changed, guiRoot, playerGui }) do object:Destroy() end
	assert(ok, err)
	return string.format("PASS: %d healing counter assertions; progress, healing, respawn, stale character, delayed humanoid, cleanup", checks)
end
