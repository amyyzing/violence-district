local GLOBAL_KEY = "ViolenceDistrictLogic"
local BASE_KEY = "ViolenceDistrictBaseUrl"
local DEFAULT_BASE_URL = "https://raw.githubusercontent.com/amyyzing/violence-district/main/"
local VERSION = 90

local globalState = getgenv and getgenv() or _G
local baseUrl = globalState and globalState[BASE_KEY] or DEFAULT_BASE_URL
local existing = globalState and globalState[GLOBAL_KEY]
local previousState

local function noop() end

local function safeCall(callback, ...)
	if callback then
		pcall(callback, ...)
	end
end

if existing then
	if existing.Version == VERSION then
		return existing
	end

	if existing.getState then
		previousState = existing.getState()
	end

	safeCall(existing.setSkillCheckEnabled, false)
	safeCall(existing.setHighlightsEnabled, false)
	safeCall(existing.setPathTreeEnabled, false)
	safeCall(existing.setProjectileVisualiserEnabled, false)
	safeCall(existing.setSpearAimEnabled, false)
	safeCall(existing.setAutoParryEnabled, false)

	if existing.destroy then
		existing.destroy()
	end

	pcall(function()
		existing.toggleSkillCheck = noop
		existing.toggleHighlights = noop
		existing.togglePathTree = noop
		existing.toggleProjectileVisualiser = noop
		existing.setSkillCheckEnabled = noop
		existing.setHighlightsEnabled = noop
		existing.setPathTreeEnabled = noop
		existing.setProjectileVisualiserEnabled = noop
		existing.setSpearAimEnabled = noop
		existing.toggleSpearAim = noop
		existing.setAutoParryEnabled = noop
		existing.toggleAutoParry = noop
	end)

	if globalState then
		globalState[GLOBAL_KEY] = nil
	end
end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local Logic = {}

local K = {
	GENERATOR_HITBOX_NAME = "HitBox",
	PLAYER_HL = "CateyesHighlight",
	GEN_HL = "CateyesGeneratorHighlight",
	GEN_PROGRESS = "CateyesGeneratorProgress",
	HOOK_HL = "CateyesHookHighlight",
	GEN_COLOR = Color3.fromRGB(255, 235, 59),
	HOOK_COLOR = Color3.fromRGB(170, 92, 255),
	DEFAULT_PLAYER_COLOR = Color3.fromRGB(255, 255, 255),
	SKILL_MODES = { "Normal", "Perfect" },
	DEFAULT_SKILL_MODE = "Perfect",
	MAP_RESYNC_INTERVAL = 10,
	PROJECTILE_FOLDER_NAME = "CateyesProjectileVisualiser",
	PROJECTILE_GUI_NAME = "CateyesProjectilePower",
	PROJECTILE_SPEED = 165,
	PROJECTILE_MID_SPEED = 142.5,
	PROJECTILE_CHARGE_SPEED = 150,
	PROJECTILE_FULL_CHARGE_TIME = 2,
	PROJECTILE_GRAVITY_MULTIPLIER = 0.5,
	PROJECTILE_FLIGHT_TIME = 4,
	PROJECTILE_ARC_STEPS = 160,
	PROJECTILE_PREVIEW_TIME = 1.35,
	PROJECTILE_BEAM_THICKNESS = 3,
	PROJECTILE_BEAM_ZINDEX = -1,
	PROJECTILE_IMPACT_RADIUS = 0.25,
	PROJECTILE_START_FORWARD = 3,
	PROJECTILE_START_UP = 1.5,
	PROJECTILE_TARGET_HL = "CateyesProjectileTargetHighlight",
	PROJECTILE_TARGET_COLOR = Color3.fromRGB(255, 72, 112),
	SPEAR_AIM_FOV_RADIUS = 120,
	PROJECTILE_HOLD_ANIMATION_IDS = {
		["92098503722633"] = true,
		["84093948968516"] = true,
		["138045669415653"] = true,
		["137688077908355"] = true,
		["101784373049485"] = true,
		["122986861455212"] = true,
	},
	PROJECTILE_THROW_ANIMATION_IDS = {
		["93136435416899"] = true,
		["86266790353635"] = true,
		["124191224140066"] = true,
		["136859656743697"] = true,
	},
}
K.FEATURE_BASE_URL = baseUrl .. "features/"
K.FEATURE_MODULE_FILES = {
	Highlights = "highlights.luau",
	ProjectileVisualiser = "projectile_visualiser.luau",
	SkillCheck = "skill_check.luau",
	AutoParry = "auto_parry.luau",
}

local highlightsEnabled = previousState and previousState.highlightsEnabled == true or false
local skillCheckEnabled = previousState and previousState.skillCheckEnabled == true or false
local projectileVisualiserEnabled = previousState and previousState.projectileVisualiserEnabled == true or false
local spearAimEnabled = previousState and previousState.spearAimEnabled == true or false
local autoParryEnabled = previousState and previousState.autoParryEnabled == true or false
local autoParryStatus = "Off"
local skillCheckMode = previousState and previousState.skillCheckMode or K.DEFAULT_SKILL_MODE
local started = false
local active = true

local trackedGenerators = {}
local trackedHooks = {}
local generatorConnections = {}
local pendingGeneratorConnections = {}
local playerConnections = {}
local mapConnections = {}
local connections = {}

local mapContainer
local projectilePreviewFolder
local projectilePowerGui
local projectilePowerLabel
local projectileBeamAdornment
local projectileArcBeams = {}
local projectileImpactAdornment
local projectileRenderBound = false
local projectileThrowHolding = false
local projectileInputHolding = false
local projectileAnimationHolding = false
local projectileHoldStartClock = 0
local spearAimBound, spearAimTarget = false, nil
local spearAimReleaseUntil, spearAimSpeed = 0, K.PROJECTILE_SPEED

local featureModules = {}


local stateChanged = Instance.new("BindableEvent")

local function make(className, props)
	local obj = Instance.new(className)
	for key, value in pairs(props) do
		obj[key] = value
	end
	return obj
end

local function trackConnection(connection)
	table.insert(connections, connection)
	return connection
end

local function trackMapConnection(connection)
	table.insert(mapConnections, connection)
	return connection
end

function Logic.getFeatureAvailability(player)
	player = player or LP
	local character = player.Character
	local team = player.Team and player.Team.Name or ""
	-- The character marker covers melee mode; selection metadata also covers initial spawn.
	local selected = player.GetAttribute and player:GetAttribute("SelectedKiller")
	local veil = team == "Killer" and character ~= nil
		and (character:GetAttribute("spearmode") ~= nil or selected == "Veil")
	local dagger = team:lower():match("^survivor") ~= nil and character ~= nil
		and character:FindFirstChild("Parrying Dagger", true) ~= nil
	return { projectileVisualiserEnabled = veil, spearAimEnabled = veil, autoParryEnabled = dagger }
end

local function copyState()
	return {
		highlightsEnabled = highlightsEnabled,
		skillCheckEnabled = skillCheckEnabled,
		projectileVisualiserEnabled = projectileVisualiserEnabled,
		spearAimEnabled = spearAimEnabled,
		autoParryEnabled = autoParryEnabled,
		autoParryStatus = autoParryStatus,
		skillCheckMode = skillCheckMode,
	}
end

local function emitState()
	if active then
		stateChanged:Fire(copyState())
	end
end

local function setHighlight(model, on, name, color)
	if not model or not model:IsA("Model") then
		return
	end

	local highlight = model:FindFirstChild(name)
	if not on then
		if highlight and highlight:IsA("Highlight") then
			highlight:Destroy()
		end
		return
	end

	if highlight and not highlight:IsA("Highlight") then
		return
	end

	if not highlight then
		highlight = make("Highlight", {
			Name = name,
			Parent = model,
		})
	end

	highlight.Adornee = model
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = 0.45
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
end

local function playerColor(player)
	return player.TeamColor and player.TeamColor.Color or K.DEFAULT_PLAYER_COLOR
end

local function applyPlayer(player)
	if player.Character then
		setHighlight(player.Character, highlightsEnabled and player ~= LP, K.PLAYER_HL, playerColor(player))
	end
end

local function applyPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		applyPlayer(player)
	end
end

local function disconnectPlayer(player)
	local list = playerConnections[player]
	if not list then
		return
	end

	for _, connection in ipairs(list) do
		connection:Disconnect()
	end
	playerConnections[player] = nil
end

local function watchPlayer(player)
	disconnectPlayer(player)

	local list = {}
	playerConnections[player] = list

	local function add(connection)
		table.insert(list, connection)
		return connection
	end

	add(player.CharacterAdded:Connect(function(character)
		task.defer(function()
			if active then
				setHighlight(character, highlightsEnabled and player ~= LP, K.PLAYER_HL, playerColor(player))
			end
		end)
	end))

	add(player:GetPropertyChangedSignal("TeamColor"):Connect(function()
		if active and highlightsEnabled then
			applyPlayer(player)
		end
	end))

	applyPlayer(player)
end

local function disconnectMapConnections()
	for _, connection in ipairs(mapConnections) do
		connection:Disconnect()
	end
	table.clear(mapConnections)
end

local function isGenerator(model)
	return model:IsA("Model") and (model.Name == "Generator" or model:GetAttribute("RepairProgress") ~= nil)
end

local function numberFromAttribute(value)
	local valueType = typeof(value)
	if valueType == "number" then
		return value
	end

	if valueType == "string" then
		return tonumber(value:match("%-?%d+%.?%d*"))
	end

	return nil
end

local function repairProgress(model)
	return numberFromAttribute(model:GetAttribute("RepairProgress")) or 0
end

local function isGeneratorComplete(model)
	return repairProgress(model) >= 100
end

function Logic._getGeneratorHitBox(model)
	if not model or not model.Parent then
		return nil
	end

	local hitBox = model:FindFirstChild(K.GENERATOR_HITBOX_NAME, true)
	if hitBox and hitBox:IsA("BasePart") then
		return hitBox
	end

	local wanted = string.lower(K.GENERATOR_HITBOX_NAME)
	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") and string.lower(obj.Name) == wanted then
			return obj
		end
	end

	return nil
end

local function removeGeneratorProgress(model)
	local label = model:FindFirstChild(K.GEN_PROGRESS)
	if label then label:Destroy() end
end

function Logic._updateGeneratorProgress(model)
	local anchor = Logic._getGeneratorHitBox(model) or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not anchor then return end
	local billboard = model:FindFirstChild(K.GEN_PROGRESS)
	if not billboard then
		billboard = make("BillboardGui", {
			Name = K.GEN_PROGRESS, AlwaysOnTop = true, LightInfluence = 0,
			Size = UDim2.fromScale(6, 0.85), MaxDistance = 300, Parent = model,
		})
		make("TextLabel", {
			Name = "Progress", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
			TextScaled = true, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 245, 190),
			TextStrokeColor3 = Color3.fromRGB(18, 20, 26), TextStrokeTransparency = 0.15,
			Parent = billboard,
		})
	end
	-- Billboard scale is measured in studs, so size follows distance and zoom.
	billboard.Adornee = anchor
	billboard.StudsOffsetWorldSpace = Vector3.new(0, anchor.Size.Y * 0.5 + 0.75, 0)
	local progress = math.clamp(repairProgress(model), 0, 100)
	progress = math.floor(progress * 10) / 10
	billboard.Progress.Text = string.format("%g/100 (%g%%)", progress, progress)
	return billboard
end

local function applyGeneratorHighlight(model)
	if highlightsEnabled and not isGeneratorComplete(model) then
		setHighlight(model, true, K.GEN_HL, K.GEN_COLOR)
		Logic._updateGeneratorProgress(model)
	else
		setHighlight(model, false, K.GEN_HL)
		removeGeneratorProgress(model)
	end
end

local function disconnectPendingGenerator(model)
	local connection = pendingGeneratorConnections[model]
	if connection then
		connection:Disconnect()
		pendingGeneratorConnections[model] = nil
	end
end

local function disconnectGenerator(model)
	local connection = generatorConnections[model]
	if connection then
		connection:Disconnect()
		generatorConnections[model] = nil
	end
end

local function trackGenerator(model)
	disconnectPendingGenerator(model)
	trackedGenerators[model] = true

	if not generatorConnections[model] then
		generatorConnections[model] = model:GetAttributeChangedSignal("RepairProgress"):Connect(function()
			if active and trackedGenerators[model] then
				applyGeneratorHighlight(model)
			end
		end)
	end

	applyGeneratorHighlight(model)

end

local function watchPendingGenerator(model)
	if trackedGenerators[model] or pendingGeneratorConnections[model] then
		return
	end

	pendingGeneratorConnections[model] = model:GetAttributeChangedSignal("RepairProgress"):Connect(function()
		if not active or not mapContainer or not model:IsDescendantOf(mapContainer) then
			disconnectPendingGenerator(model)
			return
		end

		if isGenerator(model) then
			trackGenerator(model)
		end
	end)

	task.delay(3, function()
		if not active or trackedGenerators[model] then
			disconnectPendingGenerator(model)
			return
		end

		if mapContainer and model:IsDescendantOf(mapContainer) and isGenerator(model) then
			trackGenerator(model)
		else
			disconnectPendingGenerator(model)
		end
	end)
end

local function untrackGenerator(model)
	setHighlight(model, false, K.GEN_HL)
	removeGeneratorProgress(model)
	disconnectGenerator(model)
	disconnectPendingGenerator(model)
	trackedGenerators[model] = nil

end

local function trackHook(model)
	trackedHooks[model] = true
	if highlightsEnabled then
		setHighlight(model, true, K.HOOK_HL, K.HOOK_COLOR)
	end
end

local function untrackHook(model)
	setHighlight(model, false, K.HOOK_HL)
	trackedHooks[model] = nil
end

local function trackMapObject(obj)
	-- A streamed generator may arrive before its hitbox does.
	if obj:IsA("BasePart") then
		local parent = obj.Parent
		while parent and parent ~= mapContainer do
			if trackedGenerators[parent] then
				applyGeneratorHighlight(parent)
				return
			end
			parent = parent.Parent
		end
	end
	if not obj:IsA("Model") then
		return
	end

	if obj.Name == "Hook" then
		trackHook(obj)
	elseif isGenerator(obj) then
		trackGenerator(obj)
	else
		watchPendingGenerator(obj)
	end
end

local function untrackMapObject(obj)
	disconnectPendingGenerator(obj)

	if trackedGenerators[obj] then
		untrackGenerator(obj)
	end

	if trackedHooks[obj] then
		untrackHook(obj)
	end
end

local function removeMapHighlights()
	for model in pairs(trackedGenerators) do
		setHighlight(model, false, K.GEN_HL)
		removeGeneratorProgress(model)
	end

	for model in pairs(trackedHooks) do
		setHighlight(model, false, K.HOOK_HL)
	end
end

local function clearMapCache()
	removeMapHighlights()

	local models = {}
	for model in pairs(generatorConnections) do
		table.insert(models, model)
	end

	for _, model in ipairs(models) do
		disconnectGenerator(model)
	end

	local pendingModels = {}
	for model in pairs(pendingGeneratorConnections) do
		table.insert(pendingModels, model)
	end

	for _, model in ipairs(pendingModels) do
		disconnectPendingGenerator(model)
	end

	table.clear(trackedGenerators)
	table.clear(trackedHooks)
end

local function setMapContainer(map)
	if mapContainer == map then
		return
	end

	disconnectMapConnections()
	clearMapCache()
	mapContainer = map

	if not mapContainer then
		return
	end

	trackMapConnection(mapContainer.DescendantAdded:Connect(function(obj)
		task.defer(function()
			if active and mapContainer and obj:IsDescendantOf(mapContainer) then
				trackMapObject(obj)
			end
		end)
	end))

	trackMapConnection(mapContainer.DescendantRemoving:Connect(function(obj)
		untrackMapObject(obj)
	end))

	if mapContainer.Destroying then
		trackMapConnection(mapContainer.Destroying:Connect(function()
			if active and mapContainer == map then
				disconnectMapConnections()
				clearMapCache()
				mapContainer = nil
			end
		end))
	end
end

local function resyncMap()
	local map = workspace:FindFirstChild("Map")
	setMapContainer(map)

	if not mapContainer then
		return
	end

	local seenGenerators = {}
	local seenHooks = {}

	for _, obj in ipairs(mapContainer:GetDescendants()) do
		if obj:IsA("Model") then
			if obj.Name == "Hook" then
				seenHooks[obj] = true
				trackHook(obj)
			elseif isGenerator(obj) then
				seenGenerators[obj] = true
				trackGenerator(obj)
			end
		end
	end

	local generators = {}
	for model in pairs(trackedGenerators) do
		table.insert(generators, model)
	end

	for _, model in ipairs(generators) do
		if not seenGenerators[model] then
			untrackGenerator(model)
		elseif highlightsEnabled then
			applyGeneratorHighlight(model)
		end
	end

	local hooks = {}
	for model in pairs(trackedHooks) do
		table.insert(hooks, model)
	end

	for _, model in ipairs(hooks) do
		if not seenHooks[model] then
			untrackHook(model)
		elseif highlightsEnabled then
			setHighlight(model, true, K.HOOK_HL, K.HOOK_COLOR)
		end
	end

end

local function getCharacter()
	return LP.Character
end

local function ensureProjectileFolder()
	if projectilePreviewFolder and projectilePreviewFolder.Parent then
		return projectilePreviewFolder
	end

	local existingFolder = workspace:FindFirstChild(K.PROJECTILE_FOLDER_NAME)
	if existingFolder then
		projectilePreviewFolder = existingFolder
		return existingFolder
	end

	projectilePreviewFolder = make("Folder", {
		Name = K.PROJECTILE_FOLDER_NAME,
		Parent = workspace,
	})
	return projectilePreviewFolder
end

local function ensureProjectilePowerGui()
	if projectilePowerGui and projectilePowerGui.Parent then
		return projectilePowerGui, projectilePowerLabel
	end

	local existingGui = PG:FindFirstChild(K.PROJECTILE_GUI_NAME)
	if existingGui then
		projectilePowerGui = existingGui
		projectilePowerLabel = existingGui:FindFirstChild("Power")
		return projectilePowerGui, projectilePowerLabel
	end

	projectilePowerGui = make("ScreenGui", {
		Name = K.PROJECTILE_GUI_NAME,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = PG,
	})
	projectilePowerLabel = make("TextLabel", {
		Name = "Power",
		Size = UDim2.new(0, 176, 0, 28),
		Position = UDim2.new(0.5, -88, 0.78, 0),
		BackgroundColor3 = Color3.fromRGB(16, 18, 21),
		BackgroundTransparency = 0.24,
		BorderSizePixel = 0,
		Text = "",
		TextColor3 = Color3.fromRGB(255, 232, 119),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		Visible = false,
		Parent = projectilePowerGui,
	})
	make("UICorner", {
		CornerRadius = UDim.new(0, 8),
		Parent = projectilePowerLabel,
	})

	return projectilePowerGui, projectilePowerLabel
end

local function hideProjectilePowerGui()
	if projectilePowerLabel then
		projectilePowerLabel.Visible = false
	end
end

local function clearProjectilePreview()
	for _, beam in ipairs(projectileArcBeams) do beam:Destroy() end
	table.clear(projectileArcBeams)
	if projectileBeamAdornment then
		projectileBeamAdornment:Destroy()
		projectileBeamAdornment = nil
	end
	if projectileImpactAdornment then
		projectileImpactAdornment:Destroy()
		projectileImpactAdornment = nil
	end
	if Logic._projectileTargetModel then
		local highlight = Logic._projectileTargetModel:FindFirstChild(K.PROJECTILE_TARGET_HL)
		if highlight and highlight:IsA("Highlight") then
			highlight:Destroy()
		end
		Logic._projectileTargetModel = nil
	end
	hideProjectilePowerGui()
end

local function destroyProjectileVisuals()
	clearProjectilePreview()
	Logic._projectileAdornmentRoot = nil
	if projectilePreviewFolder then
		projectilePreviewFolder:Destroy()
		projectilePreviewFolder = nil
	end
	if projectilePowerGui then
		projectilePowerGui:Destroy()
		projectilePowerGui = nil
		projectilePowerLabel = nil
	end
end

local function stopProjectileRender()
	if projectileRenderBound then
		RunService:UnbindFromRenderStep("CateyesProjectilePreview")
		projectileRenderBound = false
	end
end

local function projectileWeaponActive()
	local character = getCharacter()
	return Logic.getFeatureAvailability().spearAimEnabled and character and character:GetAttribute("spearmode") == true
end

local function projectilePreviewAllowed()
	return active and projectileVisualiserEnabled and projectileWeaponActive() and projectileThrowHolding
end

local function setProjectileHolding(inputHolding, animationHolding)
	if inputHolding ~= nil then
		projectileInputHolding = inputHolding == true
	end
	if animationHolding ~= nil then
		projectileAnimationHolding = animationHolding == true
	end

	local nextHolding = projectileInputHolding or projectileAnimationHolding
	if nextHolding and not projectileThrowHolding then
		projectileHoldStartClock = os.clock()
		spearAimTarget, spearAimReleaseUntil = nil, 0
	elseif not nextHolding then
		if projectileThrowHolding and spearAimTarget then spearAimReleaseUntil = os.clock() + 0.15 end
		projectileHoldStartClock = 0
	end

	projectileThrowHolding = nextHolding
	Logic._refreshProjectileVisualiser()
end

function Logic._projectileSpecialReady(playerGui)
	for _, name in ipairs({ "Slasher", "Slasher-mob", "Slasher-con" }) do
		local gui = playerGui:FindFirstChild(name)
		local moves = gui and gui:FindFirstChild("Gen")
		local move = moves and moves:FindFirstChild("Move2")
		local icon = move and move:FindFirstChild("Icon")
		if gui and gui:IsA("ScreenGui") and gui.Enabled and icon then
			local color = icon.ImageColor3
			return color.R > 0.9 and color.G > 0.9 and color.B > 0.9
		end
	end
	return false
end

function Logic._projectileLaunchSpeed(held, specialReady)
	if held >= K.PROJECTILE_FULL_CHARGE_TIME and specialReady then return K.PROJECTILE_SPEED, true end
	if held >= 1 then return K.PROJECTILE_MID_SPEED, false end
	return math.max(held * K.PROJECTILE_CHARGE_SPEED, 1), false
end

local function projectilePowerState()
	if not projectileThrowHolding or projectileHoldStartClock <= 0 then
		return "READY", 1, Color3.fromRGB(255, 232, 119), K.PROJECTILE_SPEED
	end

	local held = os.clock() - projectileHoldStartClock
	local speed, piercing = Logic._projectileLaunchSpeed(held, Logic._projectileSpecialReady(PG))
	if piercing then
		return "FULL", 1, Color3.fromRGB(255, 121, 73), speed, true
	end

	if held >= 1 then
		return "MID", K.PROJECTILE_MID_SPEED / K.PROJECTILE_SPEED, Color3.fromRGB(255, 178, 82), K.PROJECTILE_MID_SPEED
	end

	return "LOW", math.clamp(speed / K.PROJECTILE_SPEED, 0, 1), Color3.fromRGB(126, 226, 255), speed
end

local function updateProjectilePowerIndicator(label, percent, color)
	local _, powerLabel = ensureProjectilePowerGui()
	if not powerLabel then
		return
	end

	powerLabel.Visible = true
	powerLabel.Text = string.format("SPEAR %s  %d%%", label, math.floor(percent * 100 + 0.5))
	powerLabel.TextColor3 = color
end

function Logic._projectileStartPosition(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position + root.CFrame.LookVector * K.PROJECTILE_START_FORWARD + Vector3.new(0, K.PROJECTILE_START_UP, 0)
	end

	local camera = workspace.CurrentCamera
	return camera and camera.CFrame.Position or nil
end

function Logic._projectileRaycastParams(character)
	local ignore = {}
	if workspace.CurrentCamera then table.insert(ignore, workspace.CurrentCamera) end
	if projectilePreviewFolder then
		table.insert(ignore, projectilePreviewFolder)
	end
	if character then
		table.insert(ignore, character)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	pcall(function()
		params.RespectCanCollide = false
	end)

	return params
end

local projectileSteps, projectileStepIndex, projectileStepSum, projectileStepSquares = {}, 0, 0, 0
function Logic._recordProjectileStep(dt)
	if dt <= 0 or dt > 0.25 then return end
	projectileStepIndex = projectileStepIndex % 32 + 1
	local old = projectileSteps[projectileStepIndex] or 0
	projectileSteps[projectileStepIndex] = dt
	projectileStepSum = projectileStepSum + dt - old
	projectileStepSquares = projectileStepSquares + dt * dt - old * old
end

function Logic._projectileFrameStep(fallback)
	-- Velocity-first integration adds a drop proportional to sum(dt^2), not just mean(dt).
	return projectileStepSum > 0 and projectileStepSquares / projectileStepSum or (fallback or 1 / 60)
end

function Logic._spearIntercept(origin, target, targetVelocity, speed, gravity, frameStep, latency)
	if speed <= 0 then return nil end
	local relative = target + targetVelocity * (latency or 0) - origin
	local step = frameStep or 1 / 60
	local function displacement(t)
		return relative + targetVelocity * t + Vector3.new(0, 0.5 * gravity * t * (t + step), 0)
	end
	local function errorAt(t)
		local delta = displacement(t)
		return delta.Magnitude * delta.Magnitude - speed * speed * t * t
	end
	local function solve(before, after)
		for _ = 1, 24 do
			local middle = (before + after) * 0.5
			if errorAt(middle) > 0 then before = middle else after = middle end
		end
		local time = (before + after) * 0.5
		local delta = displacement(time)
		if delta.Magnitude < 0.000001 then return nil end
		return delta.Unit, time, target + targetVelocity * (time + (latency or 0))
	end
	local older, before = 0, 0
	local olderError, beforeError = errorAt(0), errorAt(0)
	for index = 1, 400 do
		local after = K.PROJECTILE_FLIGHT_TIME * index / 400
		local afterError = errorAt(after)
		if afterError <= 0 then return solve(before, after) end
		-- Near maximum range, both roots can fall between two scan samples.
		if before > 0 and beforeError < olderError and beforeError < afterError then
			local left, right = older, after
			for _ = 1, 32 do
				local a, b = left + (right - left) / 3, right - (right - left) / 3
				if errorAt(a) < errorAt(b) then right = b else left = a end
			end
			local minimum = (left + right) * 0.5
			if errorAt(minimum) <= 0 then return solve(older, minimum) end
		end
		older, olderError, before, beforeError = before, beforeError, after, afterError
	end
	return nil
end

function Logic._spearAimParts(player)
	if player == LP or not player.Team or not player.Team.Name:lower():match("^survivor") then return nil end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not humanoid or humanoid.Health <= 0 or character:GetAttribute("Knocked") then return nil end
	return root, character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or root, humanoid
end

function Logic._selectSpearAimTarget(camera, mouse, players)
	local closest, best = nil, math.huge
	for _, player in ipairs(players or Players:GetPlayers()) do
		local root, torso = Logic._spearAimParts(player)
		if root then
			local point, visible = camera:WorldToViewportPoint(torso.Position)
			if visible and point.Z > 0 then
				local distance = (Vector2.new(point.X, point.Y) - mouse).Magnitude
				if distance <= K.SPEAR_AIM_FOV_RADIUS and distance < best then closest, best = player, distance end
			end
		end
	end
	return closest
end

function Logic._spearMotionVelocity(sample, position, now, grounded)
	local elapsed = sample.time and now - sample.time or 0
	if not sample.position or elapsed > 0.25 or elapsed < 0 then
		sample.position, sample.time, sample.velocity = position, now, Vector3.zero
	elseif elapsed >= 0.06 then
		local movement = position - sample.position
		-- Do not lead across teleports or replication corrections.
		sample.velocity = movement.Magnitude <= 100 * elapsed and movement / elapsed or Vector3.zero
		sample.position, sample.time = position, now
	end
	local velocity = sample.velocity or Vector3.zero
	if grounded then velocity = Vector3.new(velocity.X, 0, velocity.Z) end
	return velocity
end

function Logic._spearAimAlpha(dt)
	return 1 - math.exp(-28 * math.max(dt or 1 / 60, 0))
end

local spearAimMotion
local function stopSpearAim()
	if spearAimBound then RunService:UnbindFromRenderStep("CateyesSpearAim") end
	spearAimBound, spearAimTarget, spearAimReleaseUntil = false, nil, 0
	Logic._spearAimDebug = nil
	spearAimMotion = nil
end

local function updateSpearAim(deltaTime)
	local character, camera = getCharacter(), workspace.CurrentCamera
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not active or not spearAimEnabled or not projectileWeaponActive() or not camera
		or not humanoid or humanoid.Health <= 0 or not LP.Team or LP.Team.Name ~= "Killer"
		or (not projectileThrowHolding and os.clock() > spearAimReleaseUntil) then stopSpearAim() return end
	if not spearAimTarget and projectileThrowHolding then
		local inset = game:GetService("GuiService"):GetGuiInset()
		spearAimTarget = Logic._selectSpearAimTarget(camera, UserInputService:GetMouseLocation() - inset)
	end
	if not spearAimTarget then return end
	local root, torso, targetHumanoid = Logic._spearAimParts(spearAimTarget)
	if not root then stopSpearAim() return end
	local origin = Logic._projectileStartPosition(character)
	if not origin then return end
	if projectileThrowHolding then local _, _, _, speed = projectilePowerState() spearAimSpeed = speed end
	if not spearAimMotion or spearAimMotion.root ~= root then spearAimMotion = { root = root } end
	-- Remote AssemblyLinearVelocity can remain stale while the character moves in a different direction.
	local velocity = Logic._spearMotionVelocity(spearAimMotion, root.Position, os.clock(),
		targetHumanoid.FloorMaterial ~= Enum.Material.Air)
	local ok, ping = pcall(function() return LP:GetNetworkPing() end)
	local latency = ok and math.clamp(ping * 0.5, 0, 0.25) or 0
	local direction, time, point = Logic._spearIntercept(origin, torso.Position, velocity, spearAimSpeed,
		workspace.Gravity * K.PROJECTILE_GRAVITY_MULTIPLIER, Logic._projectileFrameStep(deltaTime), latency)
	Logic._spearAimDebug = { target = spearAimTarget, direction = direction, flightTime = time, point = point,
		speed = spearAimSpeed, velocity = velocity }
	if direction then
		local goal = CFrame.lookAt(camera.CFrame.Position, camera.CFrame.Position + direction)
		-- Ease while tracking; finish alignment on release so smoothing does not offset the throw.
		local alpha = projectileThrowHolding and Logic._spearAimAlpha(deltaTime) or 1
		camera.CFrame = camera.CFrame:Lerp(goal, alpha)
	end
end

function Logic._refreshSpearAim()
	if active and spearAimEnabled and projectileWeaponActive()
		and (projectileThrowHolding or os.clock() < spearAimReleaseUntil) then
		if not spearAimBound then
			RunService:BindToRenderStep("CateyesSpearAim", Enum.RenderPriority.Camera.Value + 1, updateSpearAim)
			spearAimBound = true
		end
	else stopSpearAim() end
end

function Logic._projectileCharacterModel(instance)
	local model = instance and instance:FindFirstAncestorOfClass("Model")
	while model do
		if model ~= getCharacter() and model:FindFirstChildOfClass("Humanoid") then
			return model
		end

		local parent = model.Parent
		model = parent and parent:FindFirstAncestorOfClass("Model") or nil
	end

	return nil
end

function Logic._projectileSegmentRaycast(origin, direction, params, piercing)
	local distance = direction.Magnitude
	if distance <= 0.000001 then
		return nil, nil
	end

	local unit = direction.Unit
	local traveled = 0
	while traveled < distance do
		local result = workspace:Raycast(origin + unit * traveled, unit * (distance - traveled), params)
		if not result then
			return nil, nil
		end

		local part = result.Instance
		local ignored = part:IsA("BasePart") and (part.Transparency >= 1 or not part.CanCollide)
		if not ignored then
			local characterModel = Logic._projectileCharacterModel(part)
			if characterModel then return result, characterModel end
			if not piercing then return result, nil end
		end

		local filter = params.FilterDescendantsInstances
		table.insert(filter, result.Instance)
		params.FilterDescendantsInstances = filter
		-- Excluding the part lets the next cast see the wall behind it. Keep
		-- forward progress tiny so a nearby thin wall is not skipped too.
		traveled = math.min(math.max(traveled + 0.001, (result.Position - origin).Magnitude + 0.001), distance)
	end

	return nil, nil
end

function Logic._ensureProjectileAdornmentRoot()
	local root = Logic._projectileAdornmentRoot
	if root and root.Parent then
		return root
	end

	root = make("Part", {
		Name = "AdornmentRoot",
		Anchored = true,
		CanCollide = false,
		Size = Vector3.new(0.1, 0.1, 0.1),
		Transparency = 1,
		CFrame = CFrame.new(),
		Parent = ensureProjectileFolder(),
	})
	pcall(function()
		root.CanTouch = false
	end)
	pcall(function()
		root.CanQuery = false
	end)
	Logic._projectileAdornmentRoot = root
	return root
end

function Logic._projectileImpactSphere()
	if projectileImpactAdornment and projectileImpactAdornment.Parent then
		return projectileImpactAdornment
	end

	projectileImpactAdornment = make("SphereHandleAdornment", {
		Name = "Impact",
		Adornee = Logic._ensureProjectileAdornmentRoot(),
		AlwaysOnTop = false,
		ZIndex = K.PROJECTILE_BEAM_ZINDEX,
		Radius = K.PROJECTILE_IMPACT_RADIUS,
		Color3 = Color3.fromRGB(255, 232, 119),
		Transparency = 0.05,
		Parent = ensureProjectileFolder(),
	})
	return projectileImpactAdornment
end

function Logic._projectileBeam()
	if projectileBeamAdornment and projectileBeamAdornment.Parent then
		return projectileBeamAdornment
	end

	projectileBeamAdornment = make("LineHandleAdornment", {
		Name = "Beam",
		Adornee = Logic._ensureProjectileAdornmentRoot(),
		AlwaysOnTop = false,
		ZIndex = K.PROJECTILE_BEAM_ZINDEX,
		Length = 0,
		Thickness = K.PROJECTILE_BEAM_THICKNESS,
		Color3 = Color3.fromRGB(255, 232, 119),
		Transparency = 0.12,
		Parent = ensureProjectileFolder(),
	})
	return projectileBeamAdornment
end

function Logic._setProjectileImpact(position, color)
	local impact = Logic._projectileImpactSphere()
	impact.CFrame = CFrame.new(position)
	impact.Radius = K.PROJECTILE_IMPACT_RADIUS
	impact.Color3 = color
	impact.Transparency = 0.05
end

function Logic._setProjectileBeam(fromPosition, toPosition, color)
	local beam = Logic._projectileBeam()
	local offset = toPosition - fromPosition
	local distance = offset.Magnitude
	if distance <= 0.000001 then
		beam.Length = 0
		beam.Transparency = 1
		return
	end

	beam.CFrame = CFrame.lookAt(fromPosition, toPosition)
	beam.Length = distance
	beam.Thickness = K.PROJECTILE_BEAM_THICKNESS
	beam.Color3 = color
	beam.Transparency = 0.12
end

function Logic._projectileVisualOrigin(camera, fallback)
	-- The first-person spear is cosmetic; it must not move the physics origin.
	local spear = camera and camera:FindFirstChild("Spear", true)
	local hitbox = spear and spear:FindFirstChild("Hitbox")
	if hitbox and hitbox:IsA("BasePart") then return hitbox.Position end
	return fallback
end

function Logic._projectileTrajectory(origin, direction, speed, gravity, params, frameStep, piercing)
	local points = { origin }
	local velocity = direction.Unit * speed
	local previous = origin
	local step = frameStep or 1 / 60
	for index = 1, K.PROJECTILE_ARC_STEPS do
		local t = K.PROJECTILE_FLIGHT_TIME * index / K.PROJECTILE_ARC_STEPS
		-- ProjectileHandler updates velocity before position each Heartbeat.
		local position = origin + velocity * t + Vector3.new(0, -0.5 * gravity * t * (t + step), 0)
		local result, target = Logic._projectileSegmentRaycast(previous, position - previous, params, piercing)
		table.insert(points, result and result.Position or position)
		if result then return points, result, target end
		previous = position
	end
	return points
end

function Logic._setProjectileArc(points, _visualOrigin, color)
	-- Keep the cloning template hidden. A straight link from the cosmetic
	-- spear to the release point is not part of the projectile's flight.
	Logic._projectileBeam().Transparency = 1
	projectileBeamAdornment.Length = 0
	local sampleTime = K.PROJECTILE_FLIGHT_TIME / K.PROJECTILE_ARC_STEPS
	for index = 1, #points - 1 do
		local beam = projectileArcBeams[index]
		if not beam then
			beam = Logic._projectileBeam():Clone()
			beam.Name = "Arc" .. index
			beam.Parent = ensureProjectileFolder()
			projectileArcBeams[index] = beam
		end
		local delta = points[index + 1] - points[index]
		beam.Length = delta.Magnitude
		beam.CFrame = delta.Magnitude > 0.000001 and CFrame.lookAt(points[index], points[index + 1]) or CFrame.new(points[index])
		beam.Color3 = color
		local time = index * sampleTime
		beam.Transparency = time <= K.PROJECTILE_PREVIEW_TIME and (0.14 + time / K.PROJECTILE_PREVIEW_TIME * 0.35) or 1
	end
	for index = #points, #projectileArcBeams do projectileArcBeams[index].Transparency = 1 end
end

function Logic._setProjectileTargetHighlight(model)
	if Logic._projectileTargetModel and Logic._projectileTargetModel ~= model then
		local oldHighlight = Logic._projectileTargetModel:FindFirstChild(K.PROJECTILE_TARGET_HL)
		if oldHighlight and oldHighlight:IsA("Highlight") then
			oldHighlight:Destroy()
		end
	end

	Logic._projectileTargetModel = model
	if not model then
		return
	end

	local highlight = model:FindFirstChild(K.PROJECTILE_TARGET_HL)
	if highlight and not highlight:IsA("Highlight") then
		highlight:Destroy()
		highlight = nil
	end
	if not highlight then
		highlight = make("Highlight", {
			Name = K.PROJECTILE_TARGET_HL,
			Parent = model,
		})
	end

	highlight.Adornee = model
	highlight.FillColor = K.PROJECTILE_TARGET_COLOR
	highlight.OutlineColor = K.PROJECTILE_TARGET_COLOR
	highlight.FillTransparency = 0.25
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
end

local function updateProjectilePreview(deltaTime)
	if not projectilePreviewAllowed() then
		clearProjectilePreview()
		stopProjectileRender()
		return
	end

	local character = getCharacter()
	local camera = workspace.CurrentCamera
	if not character or not camera then
		clearProjectilePreview()
		return
	end

	local startPosition = Logic._projectileStartPosition(character)
	if not startPosition then
		clearProjectilePreview()
		return
	end

	local params = Logic._projectileRaycastParams(character)
	-- Lookvectorgiver sends this direction, without aiming at Mouse.Hit.
	local aimDirection = camera.CFrame.LookVector
	local powerLabel, powerPercent, powerColor, speed, piercing = projectilePowerState()
	updateProjectilePowerIndicator(powerLabel, powerPercent, powerColor)
	local points, result, characterModel = Logic._projectileTrajectory(startPosition, aimDirection, speed,
		workspace.Gravity * K.PROJECTILE_GRAVITY_MULTIPLIER, params, Logic._projectileFrameStep(deltaTime), piercing)
	local beamColor = characterModel and K.PROJECTILE_TARGET_COLOR or powerColor
	local impactColor = characterModel and K.PROJECTILE_TARGET_COLOR
		or (result and Color3.fromRGB(255, 96, 72) or powerColor)
	Logic._setProjectileArc(points, Logic._projectileVisualOrigin(camera, startPosition), beamColor)
	if result then
		Logic._setProjectileImpact(result.Position, impactColor)
	elseif projectileImpactAdornment then
		projectileImpactAdornment.Transparency = 1
	end
	Logic._setProjectileTargetHighlight(characterModel)
end

function Logic._refreshProjectileVisualiser()
	Logic._refreshSpearAim()
	if projectilePreviewAllowed() then
		if not projectileRenderBound then
			-- Draw from this frame's camera, rather than the previous Heartbeat's aim.
			RunService:BindToRenderStep("CateyesProjectilePreview", Enum.RenderPriority.Camera.Value + 2, updateProjectilePreview)
			projectileRenderBound = true
		end
	else
		clearProjectilePreview()
		stopProjectileRender()
	end
end

local function projectileTrackAnimationId(track)
	local animation = track and track.Animation
	local animationId = animation and animation.AnimationId
	if typeof(animationId) ~= "string" then
		return nil
	end

	return string.match(animationId, "%d+")
end

function Logic._watchProjectileAnimations(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		local ok, result = pcall(function()
			return humanoid:WaitForChild("Animator", 3)
		end)
		animator = ok and result or nil
	end
	if not animator then
		return
	end

	trackConnection(animator.AnimationPlayed:Connect(function(track)
		if not active or character ~= getCharacter() then return end
		local animationId = projectileTrackAnimationId(track)
		if not animationId then
			return
		end

		if K.PROJECTILE_HOLD_ANIMATION_IDS[animationId] then
			if projectileWeaponActive() then
				setProjectileHolding(nil, true)
				trackConnection(track.Stopped:Connect(function()
					if active and character == getCharacter() then setProjectileHolding(nil, false) end
				end))
			end
		elseif K.PROJECTILE_THROW_ANIMATION_IDS[animationId] then
			setProjectileHolding(false, false)
		end
	end))
end

function Logic._watchProjectileCharacter(character)
	if not character then
		return
	end

	trackConnection(character:GetAttributeChangedSignal("spearmode"):Connect(function()
		if not active or character ~= getCharacter() then return end
		if character:GetAttribute("spearmode") ~= true then
			setProjectileHolding(false, false)
		end
		Logic._refreshProjectileVisualiser()
	end))
	task.defer(function()
		if active and character == getCharacter() then Logic._watchProjectileAnimations(character) end
	end)
end

local function applyProjectileVisualiser()
	Logic._refreshProjectileVisualiser()
end

local function applyHighlights()
	applyPlayers()
	if highlightsEnabled then
		resyncMap()
	else
		removeMapHighlights()
	end
end

local function clearAllHighlights()
	local wasEnabled = highlightsEnabled
	highlightsEnabled = false
	applyPlayers()
	removeMapHighlights()
	highlightsEnabled = wasEnabled
end

local function watchMapContainer()
	setMapContainer(workspace:FindFirstChild("Map"))

	trackConnection(workspace.ChildAdded:Connect(function(child)
		if child.Name == "Map" then
			if highlightsEnabled then
				resyncMap()
			else
				setMapContainer(child)
			end
		end
	end))

	trackConnection(workspace.ChildRemoved:Connect(function(child)
		if child == mapContainer then
			disconnectMapConnections()
			clearMapCache()
			mapContainer = nil
		end
	end))
end

local function normalizeSkillMode(mode, fallback)
	for _, option in ipairs(K.SKILL_MODES) do
		if mode == option then
			return option
		end
	end
	return fallback or K.DEFAULT_SKILL_MODE
end

skillCheckMode = normalizeSkillMode(skillCheckMode, K.DEFAULT_SKILL_MODE)

function Logic._loadFeatureModule(name, fallbackFactory, context)
	local fileName = K.FEATURE_MODULE_FILES[name]
	local factory
	local loadFailure

	if fileName and loadstring and game then
		local ok, result = pcall(function()
			local chunk, err = loadstring(game:HttpGet(K.FEATURE_BASE_URL .. fileName))
			if not chunk then
				error(err)
			end
			return chunk()
		end)
		if ok and type(result) == "function" then
			factory = result
		else
			loadFailure = result
		end
	end
	if (name == "SkillCheck" or name == "AutoParry") and not factory then
		error("Failed to load " .. name .. " module: " .. tostring(loadFailure), 0)
	end

	factory = factory or fallbackFactory
	local ok, feature = pcall(factory, context)
	if ok and type(feature) == "table" then
		return feature
	end
	if name == "SkillCheck" or name == "AutoParry" then
		error("Failed to initialize " .. name .. " module: " .. tostring(feature), 0)
	end

	return fallbackFactory(context)
end

function Logic._fallbackToggleFeature(context)
	local feature = {}

	function feature.setEnabled(on)
		local nextValue = on == true
		if context.getEnabled() == nextValue then
			return
		end

		context.setEnabled(nextValue)
		if context.apply then
			context.apply()
		end
		context.emit()
	end

	function feature.toggle()
		feature.setEnabled(not context.getEnabled())
	end

	return feature
end

function Logic._installFeatureModules()
	if featureModules.Highlights then
		return
	end

	featureModules.Highlights = Logic._loadFeatureModule("Highlights", Logic._fallbackToggleFeature, {
		getEnabled = function()
			return highlightsEnabled
		end,
		setEnabled = function(value)
			highlightsEnabled = value
		end,
		apply = applyHighlights,
		emit = emitState,
	})

	featureModules.ProjectileVisualiser = Logic._loadFeatureModule("ProjectileVisualiser", Logic._fallbackToggleFeature, {
		getEnabled = function()
			return projectileVisualiserEnabled
		end,
		setEnabled = function(value)
			projectileVisualiserEnabled = value
		end,
		apply = applyProjectileVisualiser,
		emit = emitState,
	})
	featureModules.SpearAim = Logic._fallbackToggleFeature({
		getEnabled = function() return spearAimEnabled end,
		setEnabled = function(value) spearAimEnabled = value end,
		apply = Logic._refreshSpearAim,
		emit = emitState,
	})
	featureModules.AutoParry = Logic._loadFeatureModule("AutoParry", nil, {
		players = Players, player = LP, input = UserInputService,
		storage = ReplicatedStorage, runService = RunService,
		getEnabled = function() return autoParryEnabled end,
		setEnabled = function(value) autoParryEnabled = value end,
		report = function(text) autoParryStatus = text emitState() end,
		emit = emitState,
	})

	featureModules.SkillCheck = Logic._loadFeatureModule("SkillCheck", nil, {
		playerGui = PG,
		runService = RunService,
		virtualInputManager = game:GetService("VirtualInputManager"),
		getEnabled = function()
			return skillCheckEnabled
		end,
		setEnabled = function(value)
			skillCheckEnabled = value
		end,
		getMode = function()
			return skillCheckMode
		end,
		setMode = function(value)
			skillCheckMode = value
		end,
		normalizeMode = normalizeSkillMode,
		emit = emitState,
	})
end

function Logic.getState()
	Logic._installFeatureModules()
	return copyState()
end

function Logic.setHighlightsEnabled(on)
	Logic._installFeatureModules()
	featureModules.Highlights.setEnabled(on)
end

function Logic.toggleHighlights()
	Logic._installFeatureModules()
	featureModules.Highlights.toggle()
end

function Logic.setProjectileVisualiserEnabled(on)
	if on and not Logic.getFeatureAvailability().projectileVisualiserEnabled then return end
	Logic._installFeatureModules()
	featureModules.ProjectileVisualiser.setEnabled(on)
end

function Logic.toggleProjectileVisualiser()
	Logic.setProjectileVisualiserEnabled(not projectileVisualiserEnabled)
end

function Logic.setSpearAimEnabled(on)
	if on and not Logic.getFeatureAvailability().spearAimEnabled then return end
	Logic._installFeatureModules()
	featureModules.SpearAim.setEnabled(on)
end

function Logic.toggleSpearAim()
	Logic.setSpearAimEnabled(not spearAimEnabled)
end

function Logic.setSkillCheckEnabled(on)
	Logic._installFeatureModules()
	featureModules.SkillCheck.setEnabled(on)
end

function Logic.setAutoParryEnabled(on)
	if on and not Logic.getFeatureAvailability().autoParryEnabled then return end
	Logic._installFeatureModules()
	featureModules.AutoParry.setEnabled(on)
end

function Logic.toggleAutoParry()
	Logic.setAutoParryEnabled(not autoParryEnabled)
end

function Logic.getParryDiagnostics()
	Logic._installFeatureModules()
	return featureModules.AutoParry.getDiagnostics()
end

function Logic.toggleSkillCheck()
	Logic._installFeatureModules()
	featureModules.SkillCheck.toggle()
end

function Logic.setSkillCheckMode(mode)
	Logic._installFeatureModules()
	featureModules.SkillCheck.setMode(mode)
end

function Logic.start()
	Logic._installFeatureModules()
	if started then
		emitState()
		return
	end

	started = true
	trackConnection(RunService.Heartbeat:Connect(Logic._recordProjectileStep))

	for _, player in ipairs(Players:GetPlayers()) do
		watchPlayer(player)
	end

	trackConnection(Players.PlayerAdded:Connect(watchPlayer))
	trackConnection(Players.PlayerRemoving:Connect(function(player)
		disconnectPlayer(player)
	end))

	watchMapContainer()
	Logic._watchProjectileCharacter(LP.Character)

	trackConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or UserInputService:GetFocusedTextBox() then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if projectileWeaponActive() then
				setProjectileHolding(true, nil)
			end
			return
		end

		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.Y then
				Logic.toggleHighlights()
			elseif input.KeyCode == Enum.KeyCode.G then
				Logic.toggleSkillCheck()
			elseif input.KeyCode == Enum.KeyCode.H then
				Logic.toggleProjectileVisualiser()
			elseif input.KeyCode == Enum.KeyCode.J then
				Logic.toggleSpearAim()
			elseif input.KeyCode == Enum.KeyCode.K then
				Logic.toggleAutoParry()
			end
		end
	end))

	trackConnection(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			setProjectileHolding(false, nil)
		end
	end))

	trackConnection(LP.CharacterAdded:Connect(function(character)
		Logic._watchProjectileCharacter(character)
		setProjectileHolding(false, false)
		Logic._refreshProjectileVisualiser()
	end))
	trackConnection(UserInputService.WindowFocusReleased:Connect(function()
		setProjectileHolding(false, false)
		stopSpearAim()
	end))

	task.spawn(function()
		while active do
			task.wait(K.MAP_RESYNC_INTERVAL)
			if highlightsEnabled then
				applyPlayers()
				resyncMap()
			end
		end
	end)

	applyHighlights()
	if projectileVisualiserEnabled then
		applyProjectileVisualiser()
	end
	emitState()
end

function Logic.destroy()
	if not active then
		return
	end

	active = false
	for _, feature in pairs(featureModules) do
		safeCall(feature.destroy)
	end
	table.clear(featureModules)
	clearAllHighlights()
	destroyProjectileVisuals()
	stopProjectileRender()
	stopSpearAim()
	disconnectMapConnections()
	clearMapCache()

	local players = {}
	for player in pairs(playerConnections) do
		table.insert(players, player)
	end

	for _, player in ipairs(players) do
		disconnectPlayer(player)
	end

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)

	if globalState and globalState[GLOBAL_KEY] == Logic then
		globalState[GLOBAL_KEY] = nil
	end

	stateChanged:Destroy()
end

Logic.Changed = stateChanged.Event
Logic.SkillModes = K.SKILL_MODES
Logic.SpearAimFovRadius = K.SPEAR_AIM_FOV_RADIUS
Logic.Version = VERSION

if globalState then
	globalState[GLOBAL_KEY] = Logic
end

return Logic
