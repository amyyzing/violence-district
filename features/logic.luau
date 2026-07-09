local GLOBAL_KEY = "ViolenceDistrictLogic"
local BASE_KEY = "ViolenceDistrictBaseUrl"
local DEFAULT_BASE_URL = "https://raw.githubusercontent.com/amyyzing/violence-district/main/"
local VERSION = 54

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
	end)

	if globalState then
		globalState[GLOBAL_KEY] = nil
	end
end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local Logic = {}

local K = {
	GENERATOR_HITBOX_NAME = "HitBox",
	PLAYER_HL = "CateyesHighlight",
	GEN_HL = "CateyesGeneratorHighlight",
	HOOK_HL = "CateyesHookHighlight",
	GEN_COLOR = Color3.fromRGB(255, 235, 59),
	HOOK_COLOR = Color3.fromRGB(170, 92, 255),
	DEFAULT_PLAYER_COLOR = Color3.fromRGB(255, 255, 255),
	SKILL_MODES = { "Normal", "Perfect" },
	DEFAULT_SKILL_MODE = "Perfect",
	MAP_RESYNC_INTERVAL = 10,
	PATH_FOLDER_NAME = "CateyesPathTree",
	PATH_REFRESH_INTERVAL = 0.35,
	PATH_MAP_REFRESH_DEBOUNCE = 0.18,
	PATH_STALE_REFRESH_INTERVAL = 8,
	PATH_ORIGIN_REFRESH_DISTANCE = 4,
	PATH_TARGET_REFRESH_DISTANCE = 1,
	PATH_ROUTE_CHECK_INTERVAL = 0.12,
	PATH_ROUTE_PROXIMITY = 7,
	PATH_ROUTE_TOUCH_PROXIMITY = 3,
	PATH_ROUTE_PROGRESS_STEP = 0.5,
	PATH_ROUTE_TOUCH_REFRESH_COOLDOWN = 0.25,
	PATH_ROUTE_REFRESH_COOLDOWN = 0.45,
	PATH_ACTIVE_ROUTE_RESET_DISTANCE = 13,
	PATH_BLOCKED_CHECK_INTERVAL = 0.22,
	PATH_BLOCKED_REFRESH_COOLDOWN = 0.35,
	PATH_FLOAT_HEIGHT = 2.1,
	PATH_TURN_DOT = 0.94,
	PATH_CLEARANCE_RADIUS = 1,
	PATH_CLEARANCE_PADDING = 0.05,
	PATH_NAV_DIRECT_RATIO = 1.18,
	PATH_NAV_DIRECT_EXTRA = 3,
	PATH_GROUND_NEAR_UP = 6,
	PATH_GROUND_NEAR_DOWN = 16,
	PATH_GROUND_MIN_NORMAL_Y = 0.35,
	PATH_GROUND_MAX_SNAP_UP = 6,
	PATH_GROUND_MAX_SNAP_DOWN = 10,
	PATH_CLEARANCE_FLOOR_OFFSET = 0.35,
	PATH_TURN_SCORE = 5,
	PATH_POINT_SCORE = 0.35,
	PATH_CORNER_SPLIT_DISTANCE = 1.15,
	PATH_CORNER_MIN_SEGMENT = 2.5,
	PATH_CORNER_CURVE = 0.22,
	PATH_MAX_OBSTACLE_WATCHERS = 800,
	PATH_MAX_ROUTE_BUILDS_PER_REFRESH = 3,
	PATH_MAX_SHORTCUT_TESTS = 18,
	PATH_MAX_TARGET_CANDIDATES = 14,
	PATH_TARGET_APPROACH_PADDING = 1.25,
	PATH_TARGET_SIDE_INSET = 1.25,
	PATH_LOCAL_VISIBLE_DIRECT_DISTANCE = 18,
	PATH_FALL_MIN_DROP = 5,
	PATH_FALL_MAX_DROP = 120,
	PATH_FALL_SEARCH_DISTANCE = 90,
	PATH_FALL_SEARCH_STEP = 5,
	PATH_FALL_EDGE_BACKSTEP = 2.5,
	PATH_FALL_LANDING_FORWARD_STEP = 2.5,
	PATH_FALL_LANDING_FORWARD_TESTS = 3,
	PATH_FALL_TAKEOFF_MAX_HEIGHT_DIFF = 5,
	PATH_FALL_MAX_TRANSITIONS = 10,
	PATH_BEAM_SEGMENTS = 10,
	PATH_TARGET_OFFSETS = {
		Vector3.new(0, 0, 0),
		Vector3.new(6, 0, 0),
		Vector3.new(-6, 0, 0),
		Vector3.new(0, 0, 6),
		Vector3.new(0, 0, -6),
		Vector3.new(4, 0, 4),
		Vector3.new(-4, 0, 4),
		Vector3.new(4, 0, -4),
		Vector3.new(-4, 0, -4),
	},
	PATH_TARGET_TAG = "GeneratorPoint",
	PATH_TARGET_NAMES = {
		GeneratorPoint = true,
		RepairPoint = true,
		RepairPrompt = true,
		InteractPoint = true,
		InteractionPoint = true,
		Prompt = true,
	},
	PROJECTILE_FOLDER_NAME = "CateyesProjectileVisualiser",
	PROJECTILE_GUI_NAME = "CateyesProjectilePower",
	PROJECTILE_SPEED = 165,
	PROJECTILE_MID_SPEED = 142.5,
	PROJECTILE_CHARGE_SPEED = 150,
	PROJECTILE_FULL_CHARGE_TIME = 2,
	PROJECTILE_BEAM_DISTANCE = 1000,
	PROJECTILE_BEAM_THICKNESS = 3,
	PROJECTILE_BEAM_ZINDEX = 8,
	PROJECTILE_IMPACT_RADIUS = 0.7,
	PROJECTILE_START_FORWARD = 3,
	PROJECTILE_START_UP = 1.5,
	PROJECTILE_TARGET_HL = "CateyesProjectileTargetHighlight",
	PROJECTILE_TARGET_COLOR = Color3.fromRGB(255, 72, 112),
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
K.PATH_ORIGIN_REFRESH_DISTANCE_SQ = K.PATH_ORIGIN_REFRESH_DISTANCE * K.PATH_ORIGIN_REFRESH_DISTANCE
K.PATH_TARGET_REFRESH_DISTANCE_SQ = K.PATH_TARGET_REFRESH_DISTANCE * K.PATH_TARGET_REFRESH_DISTANCE
K.PATH_ROUTE_PROXIMITY_SQ = K.PATH_ROUTE_PROXIMITY * K.PATH_ROUTE_PROXIMITY
K.PATH_ROUTE_TOUCH_PROXIMITY_SQ = K.PATH_ROUTE_TOUCH_PROXIMITY * K.PATH_ROUTE_TOUCH_PROXIMITY
K.PATH_ACTIVE_ROUTE_RESET_DISTANCE_SQ = K.PATH_ACTIVE_ROUTE_RESET_DISTANCE * K.PATH_ACTIVE_ROUTE_RESET_DISTANCE
K.PATH_LOCAL_VISIBLE_DIRECT_DISTANCE_SQ = K.PATH_LOCAL_VISIBLE_DIRECT_DISTANCE * K.PATH_LOCAL_VISIBLE_DIRECT_DISTANCE
K.FEATURE_BASE_URL = baseUrl .. "features/"
K.FEATURE_MODULE_FILES = {
	Highlights = "highlights.luau",
	PathTree = "path_tree.luau",
	ProjectileVisualiser = "projectile_visualiser.luau",
	SkillCheck = "skill_check.luau",
}

local highlightsEnabled = previousState and previousState.highlightsEnabled == true or false
local skillCheckEnabled = previousState and previousState.skillCheckEnabled == true or false
local pathTreeEnabled = previousState and previousState.pathTreeEnabled == true or false
local projectileVisualiserEnabled = previousState and previousState.projectileVisualiserEnabled == true or false
local skillCheckMode = previousState and previousState.skillCheckMode or K.DEFAULT_SKILL_MODE
local started = false
local active = true

local trackedGenerators = {}
local trackedHooks = {}
local generatorConnections = {}
local generatorCompleteState = {}
local pendingGeneratorConnections = {}
local playerConnections = {}
local mapConnections = {}
local connections = {}

local mapContainer
local pathFolder
local pathRefreshQueued = false
local pathRefreshRunning = false
local pathForceRefresh = false
local pathActiveRouteKey
local pathActiveRouteProgress
local pathLastRouteRefreshClock = 0
local pathBuildId = 0
local pathSpherecastAvailable
local pathMapRefreshQueued = false
local mapResyncing = false
local projectilePreviewFolder
local projectilePowerGui
local projectilePowerLabel
local projectileBeamAdornment
local projectileImpactAdornment
local projectileHeartbeatConnection
local projectileThrowHolding = false
local projectileInputHolding = false
local projectileAnimationHolding = false
local projectileHoldStartClock = 0

Logic._pathLastBlockedCheckClock = 0
Logic._pathLastBlockedRefreshClock = 0
Logic._pathNavigationCache = {}
Logic._pathWaypointCache = {}
Logic._pathObstacleConnections = {}
Logic._pathObstacleWatchCount = 0
Logic._pathRoutes = {}
Logic._pathQueuedModels = {}
Logic._pathNextRouteId = 0
local featureModules = {}

local requestPathTreeRefresh
local clearPathVisuals

local stateChanged = Instance.new("BindableEvent")

local function make(className, props)
	local obj = Instance.new(className)
	for key, value in pairs(props) do
		obj[key] = value
	end
	return obj
end

local function magnitudeSquared(vector)
	return vector:Dot(vector)
end

local function distanceSquared(a, b)
	local delta = a - b
	return delta:Dot(delta)
end

local function trackConnection(connection)
	table.insert(connections, connection)
	return connection
end

local function trackMapConnection(connection)
	table.insert(mapConnections, connection)
	return connection
end

local function copyState()
	return {
		highlightsEnabled = highlightsEnabled,
		skillCheckEnabled = skillCheckEnabled,
		pathTreeEnabled = pathTreeEnabled,
		projectileVisualiserEnabled = projectileVisualiserEnabled,
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
		setHighlight(player.Character, highlightsEnabled, K.PLAYER_HL, playerColor(player))
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
				setHighlight(character, highlightsEnabled, K.PLAYER_HL, playerColor(player))
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

local function applyGeneratorHighlight(model)
	if highlightsEnabled and not isGeneratorComplete(model) then
		setHighlight(model, true, K.GEN_HL, K.GEN_COLOR)
	else
		setHighlight(model, false, K.GEN_HL)
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
				local wasComplete = generatorCompleteState[model] == true
				local complete = isGeneratorComplete(model)
				generatorCompleteState[model] = complete
				applyGeneratorHighlight(model)
				if wasComplete ~= complete and pathTreeEnabled and requestPathTreeRefresh and not mapResyncing then
					requestPathTreeRefresh(true)
				end
			end
		end)
	end

	generatorCompleteState[model] = isGeneratorComplete(model)
	applyGeneratorHighlight(model)

	if pathTreeEnabled and requestPathTreeRefresh and not mapResyncing then
		requestPathTreeRefresh(true)
	end
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
	disconnectGenerator(model)
	disconnectPendingGenerator(model)
	trackedGenerators[model] = nil
	generatorCompleteState[model] = nil

	if pathTreeEnabled and requestPathTreeRefresh and not mapResyncing then
		requestPathTreeRefresh(true)
	end
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
	end

	for model in pairs(trackedHooks) do
		setHighlight(model, false, K.HOOK_HL)
	end
end

local function clearMapCache()
	removeMapHighlights()
	if clearPathVisuals then
		clearPathVisuals()
	end

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

	for obj, connectionList in pairs(Logic._pathObstacleConnections) do
		for _, connection in ipairs(connectionList) do
			connection:Disconnect()
		end
		Logic._pathObstacleConnections[obj] = nil
	end
	Logic._pathObstacleWatchCount = 0

	table.clear(trackedGenerators)
	table.clear(trackedHooks)
	table.clear(generatorCompleteState)
end

local function shouldRefreshPathForMapObject(obj)
	return obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("Attachment") or obj:IsA("ProximityPrompt")
end

local function queueMapPathRefresh()
	if pathMapRefreshQueued then
		return
	end

	pathMapRefreshQueued = true
	task.delay(K.PATH_MAP_REFRESH_DEBOUNCE, function()
		pathMapRefreshQueued = false
		if active and pathTreeEnabled and requestPathTreeRefresh and not mapResyncing then
			requestPathTreeRefresh(true)
		end
	end)
end

local function requestPathRefreshForMapChange(obj)
	if pathTreeEnabled and requestPathTreeRefresh and not mapResyncing and shouldRefreshPathForMapObject(obj) then
		queueMapPathRefresh()
	end
end

function Logic._watchPathObstacle(obj)
	if not obj:IsA("BasePart") or Logic._pathObstacleConnections[obj] then
		return
	end

	if Logic._pathObstacleWatchCount >= K.PATH_MAX_OBSTACLE_WATCHERS then
		return
	end

	local connectionsForObject = {}
	Logic._pathObstacleConnections[obj] = connectionsForObject
	Logic._pathObstacleWatchCount = Logic._pathObstacleWatchCount + 1

	local function connectProperty(propertyName)
		local ok, signal = pcall(function()
			return obj:GetPropertyChangedSignal(propertyName)
		end)

		if ok and signal then
			table.insert(connectionsForObject, signal:Connect(function()
				if active then
					requestPathRefreshForMapChange(obj)
				end
			end))
		end
	end

	connectProperty("CanCollide")
end

function Logic._unwatchPathObstacle(obj)
	local connectionList = Logic._pathObstacleConnections[obj]
	if connectionList then
		for _, connection in ipairs(connectionList) do
			connection:Disconnect()
		end
		Logic._pathObstacleConnections[obj] = nil
		Logic._pathObstacleWatchCount = math.max(Logic._pathObstacleWatchCount - 1, 0)
	end
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
				Logic._watchPathObstacle(obj)
				trackMapObject(obj)
				requestPathRefreshForMapChange(obj)
			end
		end)
	end))

	trackMapConnection(mapContainer.DescendantRemoving:Connect(function(obj)
		requestPathRefreshForMapChange(obj)
		Logic._unwatchPathObstacle(obj)
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

	mapResyncing = true
	local seenGenerators = {}
	local seenHooks = {}

	for _, obj in ipairs(mapContainer:GetDescendants()) do
		Logic._watchPathObstacle(obj)
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

	mapResyncing = false
	if pathTreeEnabled and requestPathTreeRefresh then
		requestPathTreeRefresh(false)
	end
end

local function getCharacter()
	return LP.Character
end

local function getHumanoid()
	local character = getCharacter()
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

local function numberProperty(instance, propertyName)
	if not instance then
		return nil
	end

	local ok, value = pcall(function()
		return instance[propertyName]
	end)

	if ok and typeof(value) == "number" then
		return value
	end

	return nil
end

local function currentHipHeight()
	return math.max(numberProperty(getHumanoid(), "HipHeight") or 2, 0)
end

local function getTorsoPart()
	local character = getCharacter()
	if not character then
		return nil
	end

	return character:FindFirstChild("Torso")
		or character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("HumanoidRootPart")
end

function Logic._getRootPart()
	local character = getCharacter()
	if not character then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	local torso = getTorsoPart()
	if torso and torso:IsA("BasePart") then
		return torso
	end

	return nil
end

function Logic._currentRootClearanceRadius()
	local root = Logic._getRootPart()
	if root and root:IsA("BasePart") then
		return math.max(math.max(root.Size.X, root.Size.Z) * 0.5 + K.PATH_CLEARANCE_PADDING, 0.5)
	end

	return K.PATH_CLEARANCE_RADIUS
end

local function currentAgentHeight()
	local root = Logic._getRootPart()
	local rootHeight = root and root:IsA("BasePart") and root.Size.Y or 2

	return math.max(5, currentHipHeight() + rootHeight + 1)
end

local function currentPathAgent()
	return {
		AgentRadius = Logic._currentRootClearanceRadius(),
		AgentHeight = currentAgentHeight(),
		AgentCanJump = false,
		AgentCanClimb = false,
		WaypointSpacing = 2,
	}
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

local function stopProjectileHeartbeat()
	if projectileHeartbeatConnection then
		projectileHeartbeatConnection:Disconnect()
		projectileHeartbeatConnection = nil
	end
end

local function projectileWeaponActive()
	local character = getCharacter()
	return character and character:GetAttribute("spearmode") == true
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
	elseif not nextHolding then
		projectileHoldStartClock = 0
	end

	projectileThrowHolding = nextHolding
	Logic._refreshProjectileVisualiser()
end

local function projectilePowerState()
	if not projectileThrowHolding or projectileHoldStartClock <= 0 then
		return "READY", 1, Color3.fromRGB(255, 232, 119)
	end

	local held = os.clock() - projectileHoldStartClock
	if held >= K.PROJECTILE_FULL_CHARGE_TIME then
		return "FULL", 1, Color3.fromRGB(255, 121, 73)
	end

	if held >= 1 then
		return "MID", K.PROJECTILE_MID_SPEED / K.PROJECTILE_SPEED, Color3.fromRGB(255, 178, 82)
	end

	local speed = math.max(held * K.PROJECTILE_CHARGE_SPEED, 1)
	return "LOW", math.clamp(speed / K.PROJECTILE_SPEED, 0, 1), Color3.fromRGB(126, 226, 255)
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

local function projectileStartPosition(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position + root.CFrame.LookVector * K.PROJECTILE_START_FORWARD + Vector3.new(0, K.PROJECTILE_START_UP, 0)
	end

	local camera = workspace.CurrentCamera
	return camera and camera.CFrame.Position or nil
end

local function projectileRaycastParams(character)
	local ignore = {}
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

function Logic._projectileSegmentRaycast(origin, direction, params)
	local distance = direction.Magnitude
	if distance <= 0.000001 then
		return nil, nil
	end

	local unit = direction.Unit
	local traveled = 0
	local skips = 0
	while traveled < distance and skips < 8 do
		local result = workspace:Raycast(origin + unit * traveled, unit * (distance - traveled), params)
		if not result then
			return nil, nil
		end

		local characterModel = Logic._projectileCharacterModel(result.Instance)
		if characterModel then
			return result, characterModel
		end

		if result.Instance == workspace.Terrain then
			return result, nil
		end

		if result.Instance:IsA("BasePart") and result.Instance.CanCollide then
			return result, nil
		end

		local filter = params.FilterDescendantsInstances
		table.insert(filter, result.Instance)
		params.FilterDescendantsInstances = filter
		traveled = math.min((result.Position - origin).Magnitude + 0.05, distance)
		skips = skips + 1
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
		AlwaysOnTop = true,
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
		AlwaysOnTop = true,
		ZIndex = K.PROJECTILE_BEAM_ZINDEX - 1,
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
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
end

local function updateProjectilePreview()
	if not projectilePreviewAllowed() then
		clearProjectilePreview()
		stopProjectileHeartbeat()
		return
	end

	local character = getCharacter()
	local camera = workspace.CurrentCamera
	if not character or not camera then
		clearProjectilePreview()
		return
	end

	local startPosition = projectileStartPosition(character)
	if not startPosition then
		clearProjectilePreview()
		return
	end

	local params = projectileRaycastParams(character)
	local viewport = camera.ViewportSize
	local aimRay = camera:ViewportPointToRay(viewport.X * 0.5, viewport.Y * 0.5)
	local horizontalDirection = Vector3.new(aimRay.Direction.X, 0, aimRay.Direction.Z)
	if horizontalDirection.Magnitude <= 0.000001 then
		clearProjectilePreview()
		return
	end
	horizontalDirection = horizontalDirection.Unit * K.PROJECTILE_BEAM_DISTANCE

	local powerLabel, powerPercent, powerColor = projectilePowerState()
	updateProjectilePowerIndicator(powerLabel, powerPercent, powerColor)
	local result, characterModel = Logic._projectileSegmentRaycast(startPosition, horizontalDirection, params)
	local endPosition = result and result.Position or startPosition + horizontalDirection
	local beamColor = characterModel and K.PROJECTILE_TARGET_COLOR or powerColor
	local impactColor = characterModel and K.PROJECTILE_TARGET_COLOR
		or (result and Color3.fromRGB(255, 96, 72) or powerColor)
	Logic._setProjectileBeam(startPosition, endPosition, beamColor)
	Logic._setProjectileImpact(endPosition, impactColor)
	Logic._setProjectileTargetHighlight(characterModel)
end

function Logic._refreshProjectileVisualiser()
	if projectilePreviewAllowed() then
		if not projectileHeartbeatConnection then
			projectileHeartbeatConnection = RunService.RenderStepped:Connect(updateProjectilePreview)
		end
	else
		clearProjectilePreview()
		stopProjectileHeartbeat()
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
		local animationId = projectileTrackAnimationId(track)
		if not animationId then
			return
		end

		if K.PROJECTILE_HOLD_ANIMATION_IDS[animationId] then
			if projectileWeaponActive() then
				setProjectileHolding(nil, true)
				trackConnection(track.Stopped:Connect(function()
					setProjectileHolding(nil, false)
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
		if character:GetAttribute("spearmode") ~= true then
			setProjectileHolding(false, false)
		end
		Logic._refreshProjectileVisualiser()
	end))
	task.defer(function()
		Logic._watchProjectileAnimations(character)
	end)
end

local function getModelCenter(model)
	if not model or not model.Parent then
		return nil
	end

	local ok, cframe = pcall(function()
		return model:GetBoundingBox()
	end)

	if ok and cframe then
		return cframe.Position
	end

	local pivotOk, pivot = pcall(function()
		return model:GetPivot()
	end)

	if pivotOk and pivot then
		return pivot.Position
	end

	return nil
end

local function getModelSize(model)
	if not model or not model.Parent then
		return nil
	end

	local ok, _, size = pcall(function()
		return model:GetBoundingBox()
	end)

	if ok and size then
		return size
	end

	return nil
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

function Logic._generatorTargetPosition(model)
	local hitBox = Logic._getGeneratorHitBox(model)
	if hitBox then
		-- Stable generator anchor only. Actual route destinations are grounded
		-- approach points generated outside the hitbox surface.
		return hitBox.Position, hitBox
	end

	return getModelCenter(model), nil
end

local function generatorPathCenter(model, fallback)
	local hitBox = Logic._getGeneratorHitBox(model)
	if hitBox then
		return hitBox.Position, hitBox
	end

	return fallback or getModelCenter(model), nil
end

local function signNonZero(value, fallback)
	if value and value < 0 then
		return -1
	end

	if value and value > 0 then
		return 1
	end

	if fallback and fallback < 0 then
		return -1
	end

	return 1
end

local function clampHitBoxAxis(value, halfSize)
	if halfSize <= 0.05 then
		return 0
	end

	local inset = math.min(K.PATH_TARGET_SIDE_INSET, math.max(halfSize - 0.05, 0))
	local limit = math.max(halfSize - inset, 0)
	if limit <= 0.05 then
		return 0
	end

	return math.clamp(value, -limit, limit)
end

function Logic._pathTargetApproachPadding()
	return Logic._currentRootClearanceRadius() + K.PATH_TARGET_APPROACH_PADDING
end

function Logic._coercePathTargetOutsideHitBox(position, targetModel, origin)
	if not position or not targetModel then
		return position
	end

	local hitBox = Logic._getGeneratorHitBox(targetModel)
	if not hitBox then
		return position
	end

	local halfX = hitBox.Size.X * 0.5
	local halfZ = hitBox.Size.Z * 0.5
	if halfX <= 0.05 or halfZ <= 0.05 then
		return position
	end

	local padding = Logic._pathTargetApproachPadding()
	local localPosition = hitBox.CFrame:PointToObjectSpace(position)
	if math.abs(localPosition.X) > halfX + padding * 0.35
		or math.abs(localPosition.Z) > halfZ + padding * 0.35 then
		return position
	end

	local localOrigin = origin and hitBox.CFrame:PointToObjectSpace(origin) or localPosition
	local ratioX = math.abs(localOrigin.X) / math.max(halfX, 1)
	local ratioZ = math.abs(localOrigin.Z) / math.max(halfZ, 1)
	if ratioX >= ratioZ then
		localPosition = Vector3.new(
			signNonZero(localOrigin.X, localPosition.X) * (halfX + padding),
			localPosition.Y,
			clampHitBoxAxis(localOrigin.Z, halfZ)
		)
	else
		localPosition = Vector3.new(
			clampHitBoxAxis(localOrigin.X, halfX),
			localPosition.Y,
			signNonZero(localOrigin.Z, localPosition.Z) * (halfZ + padding)
		)
	end

	return hitBox.CFrame:PointToWorldSpace(localPosition)
end

local function worldPositionOf(obj)
	if not obj then
		return nil
	end

	if obj:IsA("BasePart") then
		return obj.Position
	end

	if obj:IsA("Attachment") then
		return obj.WorldPosition
	end

	if obj:IsA("Model") then
		return Logic._generatorTargetPosition(obj) or getModelCenter(obj)
	end

	if obj:IsA("ProximityPrompt") and obj.Parent then
		return worldPositionOf(obj.Parent)
	end

	return nil
end

local function addPathTargetCandidate(candidates, position)
	if not position then
		return nil
	end

	for _, candidate in ipairs(candidates) do
		if distanceSquared(candidate, position) < 1 then
			return nil
		end
	end

	table.insert(candidates, position)
	return position
end

function Logic._applyRootCollisionGroup(params)
	local root = Logic._getRootPart()
	if not root or not root:IsA("BasePart") then
		return
	end

	pcall(function()
		params.CollisionGroup = root.CollisionGroup
	end)
end

function Logic._pathGroundRaycastParams(targetModel, extraIgnore)
	local ignore = {}
	if pathFolder then
		table.insert(ignore, pathFolder)
	end
	if targetModel then
		table.insert(ignore, targetModel)
	end

	local character = getCharacter()
	if character then
		table.insert(ignore, character)
	end
	if extraIgnore then
		for _, instance in ipairs(extraIgnore) do
			table.insert(ignore, instance)
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	pcall(function()
		params.RespectCanCollide = true
	end)
	Logic._applyRootCollisionGroup(params)

	return params
end

function Logic._pathClearanceOverlapParams(targetModel)
	local ignore = {}
	if pathFolder then
		table.insert(ignore, pathFolder)
	end
	if targetModel then
		table.insert(ignore, targetModel)
	end

	local character = getCharacter()
	if character then
		table.insert(ignore, character)
	end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	pcall(function()
		params.RespectCanCollide = true
	end)
	pcall(function()
		params.MaxParts = 32
	end)
	Logic._applyRootCollisionGroup(params)

	return params
end

function Logic._isWalkableGroundHit(result)
	if not result or not result.Instance then
		return false
	end

	if result.Normal and result.Normal.Y < K.PATH_GROUND_MIN_NORMAL_Y then
		return false
	end

	if result.Instance == workspace.Terrain then
		return true
	end

	if result.Instance:IsA("BasePart") then
		return result.Instance.CanCollide
	end

	return true
end

function Logic._hasAgentClearance(position, targetModel)
	if not position then
		return false
	end

	local radius = Logic._currentRootClearanceRadius()
	local height = currentAgentHeight()
	local size = Vector3.new(radius * 2, height, radius * 2)
	local center = position + Vector3.new(0, -K.PATH_FLOAT_HEIGHT + K.PATH_CLEARANCE_FLOOR_OFFSET + height * 0.5, 0)
	local ok, parts = pcall(function()
		return workspace:GetPartBoundsInBox(CFrame.new(center), size, Logic._pathClearanceOverlapParams(targetModel))
	end)

	if not ok or not parts then
		return true
	end

	for _, part in ipairs(parts) do
		if part:IsA("BasePart") and part.CanCollide then
			return false
		end
	end

	return true
end

function Logic._projectToWalkablePathPosition(position, targetModel)
	if not position then
		return nil
	end

	local up = K.PATH_GROUND_NEAR_UP
	local down = K.PATH_GROUND_NEAR_DOWN
	local start = position + Vector3.new(0, up, 0)
	local direction = Vector3.new(0, -(up + down), 0)
	local result = workspace:Raycast(start, direction, Logic._pathGroundRaycastParams(targetModel))
	if not result or not Logic._isWalkableGroundHit(result) then
		return nil
	end

	local snapUp = result.Position.Y - position.Y
	local snapDown = position.Y - result.Position.Y
	if snapUp > K.PATH_GROUND_MAX_SNAP_UP or snapDown > K.PATH_GROUND_MAX_SNAP_DOWN then
		return nil
	end

	local grounded = result.Position + Vector3.new(0, K.PATH_FLOAT_HEIGHT, 0)
	if not Logic._hasAgentClearance(grounded, targetModel) then
		return nil
	end

	return grounded
end

function Logic._projectFallLandingPathPosition(position, takeoffY, targetModel)
	if not position or not takeoffY then
		return nil
	end

	local up = K.PATH_GROUND_NEAR_UP
	local start = Vector3.new(position.X, takeoffY + up, position.Z)
	local direction = Vector3.new(0, -(K.PATH_FALL_MAX_DROP + up), 0)
	local result = workspace:Raycast(start, direction, Logic._pathGroundRaycastParams(targetModel))
	if not result or not Logic._isWalkableGroundHit(result) then
		return nil
	end

	local grounded = result.Position + Vector3.new(0, K.PATH_FLOAT_HEIGHT, 0)
	local drop = takeoffY - grounded.Y
	if drop < K.PATH_FALL_MIN_DROP or drop > K.PATH_FALL_MAX_DROP then
		return nil
	end

	if not Logic._hasAgentClearance(grounded, targetModel) then
		return nil
	end

	return grounded
end

function Logic._addGroundedPathTargetCandidate(candidates, position, targetModel, origin)
	local approachPosition = Logic._coercePathTargetOutsideHitBox(position, targetModel, origin)
	local grounded = Logic._projectToWalkablePathPosition(approachPosition, targetModel)
	if not grounded then
		return false
	end

	return addPathTargetCandidate(candidates, grounded) ~= nil
end

local function isPointNearGenerator(position, model, center)
	if not position or not center then
		return false
	end

	local size = getModelSize(model)
	local hitBox = Logic._getGeneratorHitBox(model)
	if hitBox then
		size = hitBox.Size
	end

	local radius = 18
	if size then
		radius = math.max(size.X, size.Y, size.Z) * (hitBox and 1.25 or 0.75) + 10
	end

	return distanceSquared(position, center) <= radius * radius
end

local function collectTaggedPathTargets(model, center, origin, candidates)
	local ok, tagged = pcall(CollectionService.GetTagged, CollectionService, K.PATH_TARGET_TAG)
	if ok and tagged then
		for _, obj in ipairs(tagged) do
			local position = worldPositionOf(obj)
			if obj:IsDescendantOf(model) or isPointNearGenerator(position, model, center) then
				Logic._addGroundedPathTargetCandidate(candidates, position, model, origin)
			end
		end
	end
end

local function collectNamedPathTargets(model, origin, candidates)
	for _, obj in ipairs(model:GetDescendants()) do
		if obj.Name ~= K.GENERATOR_HITBOX_NAME and (K.PATH_TARGET_NAMES[obj.Name] or obj:IsA("ProximityPrompt")) then
			Logic._addGroundedPathTargetCandidate(candidates, worldPositionOf(obj), model, origin)
		end
	end
end

local function collectHitBoxApproachTargets(model, hitBox, origin, candidates)
	if not model or not hitBox then
		return
	end

	local halfX = hitBox.Size.X * 0.5
	local halfZ = hitBox.Size.Z * 0.5
	if halfX <= 0.05 or halfZ <= 0.05 then
		return
	end

	local padding = Logic._pathTargetApproachPadding()
	local outsideX = halfX + padding
	local outsideZ = halfZ + padding
	local localOrigin = origin and hitBox.CFrame:PointToObjectSpace(origin) or Vector3.new(0, 0, 0)
	local signX = signNonZero(localOrigin.X, 1)
	local signZ = signNonZero(localOrigin.Z, 1)
	local clampedX = clampHitBoxAxis(localOrigin.X, halfX)
	local clampedZ = clampHitBoxAxis(localOrigin.Z, halfZ)
	local y = 0

	local function addLocal(x, z)
		local worldPosition = hitBox.CFrame:PointToWorldSpace(Vector3.new(x, y, z))
		Logic._addGroundedPathTargetCandidate(candidates, worldPosition, model, origin)
	end

	if math.abs(localOrigin.X) / math.max(halfX, 1) >= math.abs(localOrigin.Z) / math.max(halfZ, 1) then
		addLocal(signX * outsideX, clampedZ)
		addLocal(clampedX, signZ * outsideZ)
	else
		addLocal(clampedX, signZ * outsideZ)
		addLocal(signX * outsideX, clampedZ)
	end

	addLocal(-signX * outsideX, clampedZ)
	addLocal(clampedX, -signZ * outsideZ)
	addLocal(outsideX, 0)
	addLocal(-outsideX, 0)
	addLocal(0, outsideZ)
	addLocal(0, -outsideZ)
	addLocal(signX * outsideX, signZ * outsideZ)
	addLocal(signX * outsideX, -signZ * outsideZ)
	addLocal(-signX * outsideX, signZ * outsideZ)
	addLocal(-signX * outsideX, -signZ * outsideZ)
end

local function collectPathTargetPositions(model, center, origin)
	local candidates = {}
	local anchor, hitBox = generatorPathCenter(model, center)
	if not anchor then
		return candidates
	end

	if hitBox then
		-- Hitbox-side points come first because model bounds can include large
		-- invisible parts that poison the center/bounds.
		collectHitBoxApproachTargets(model, hitBox, origin, candidates)
	end

	collectTaggedPathTargets(model, anchor, origin, candidates)
	collectNamedPathTargets(model, origin, candidates)

	if #candidates == 0 then
		for _, offset in ipairs(K.PATH_TARGET_OFFSETS) do
			Logic._addGroundedPathTargetCandidate(candidates, anchor + offset, model, origin)
		end
	end

	local scoredCandidates = {}
	for index, candidate in ipairs(candidates) do
		scoredCandidates[index] = {
			position = candidate,
			score = (candidate - origin).Magnitude + (candidate - anchor).Magnitude * 0.2,
		}
	end

	table.sort(scoredCandidates, function(a, b)
		return a.score < b.score
	end)

	for index, candidate in ipairs(scoredCandidates) do
		candidates[index] = candidate.position
	end

	while #candidates > K.PATH_MAX_TARGET_CANDIDATES do
		table.remove(candidates)
	end

	return candidates
end

local function destroyPathVisuals()
	if pathFolder then
		pathFolder:Destroy()
		pathFolder = nil
	end
end

function Logic._resetPathRoutes()
	for model, route in pairs(Logic._pathRoutes) do
		if route.folder then
			route.folder:Destroy()
		end
		if route.buildFolder then
			route.buildFolder:Destroy()
		end
		Logic._pathRoutes[model] = nil
	end

	table.clear(Logic._pathQueuedModels)
	Logic._pathNextRouteId = 0
end

clearPathVisuals = function()
	pathBuildId = pathBuildId + 1
	pathActiveRouteKey = nil
	pathActiveRouteProgress = nil
	pathLastRouteRefreshClock = 0
	Logic._pathLastBlockedCheckClock = 0
	Logic._pathLastBlockedRefreshClock = 0
	table.clear(Logic._pathNavigationCache)
	table.clear(Logic._pathWaypointCache)
	Logic._resetPathRoutes()
	destroyPathVisuals()
end

local function isCurrentPathBuild(root, buildId)
	return active and pathTreeEnabled and buildId == pathBuildId and root ~= nil
end

function Logic._ensurePathFolder()
	if pathFolder and pathFolder.Parent then
		return pathFolder
	end

	local existingFolder = workspace:FindFirstChild(K.PATH_FOLDER_NAME)
	if existingFolder and existingFolder:IsA("Folder") then
		pathFolder = existingFolder
		return pathFolder
	end

	if existingFolder then
		existingFolder:Destroy()
	end

	pathFolder = make("Folder", {
		Name = K.PATH_FOLDER_NAME,
		Parent = workspace,
	})
	return pathFolder
end

function Logic._routeForModel(model)
	local route = Logic._pathRoutes[model]
	if route then
		return route
	end

	Logic._pathNextRouteId = Logic._pathNextRouteId + 1
	local key = string.format("GeneratorPath_%02d", Logic._pathNextRouteId)
	route = {
		key = key,
		lastRefreshClock = nil,
		nextRetryClock = nil,
	}
	Logic._pathRoutes[model] = route
	return route
end

function Logic._removePathRoute(model)
	local route = Logic._pathRoutes[model]
	if not route then
		return
	end

	if route.folder then
		route.folder:Destroy()
	end
	if route.buildFolder then
		route.buildFolder:Destroy()
	end

	Logic._pathQueuedModels[model] = nil
	Logic._pathRoutes[model] = nil
end

function Logic._prunePathRoutes(seenModels)
	for model in pairs(Logic._pathRoutes) do
		if not seenModels[model] then
			Logic._removePathRoute(model)
		end
	end
end

function Logic._shouldRefreshRoute(route, origin, entry, now, force)
	if force or Logic._pathQueuedModels[entry.model] then
		return true
	end

	if route.nextRetryClock and now < route.nextRetryClock then
		return false
	end

	if not route.folder or not route.folder.Parent then
		return true
	end

	if not route.points or #route.points < 2 then
		return true
	end

	if not route.lastOrigin then
		return true
	end

	if distanceSquared(origin, route.lastOrigin) >= K.PATH_ORIGIN_REFRESH_DISTANCE_SQ then
		return true
	end

	if not route.lastTarget or distanceSquared(entry.target, route.lastTarget) >= K.PATH_TARGET_REFRESH_DISTANCE_SQ then
		return true
	end

	return not route.lastRefreshClock or now - route.lastRefreshClock >= K.PATH_STALE_REFRESH_INTERVAL
end

function Logic._createRouteBuildFolder(route)
	if route.buildFolder then
		route.buildFolder:Destroy()
	end

	route.buildFolder = make("Folder", {
		Name = route.key .. "_Building",
	})
	return route.buildFolder
end

function Logic._swapRouteFolder(route, buildFolder)
	local oldFolder = route.folder
	buildFolder.Name = route.key
	buildFolder.Parent = pathFolder
	route.folder = buildFolder
	route.buildFolder = nil

	if oldFolder and oldFolder ~= buildFolder then
		oldFolder:Destroy()
	end
end

local function makePathPoint(parent, name, position, size, transparency)
	local part = make("Part", {
		Name = name,
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		CastShadow = false,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size, size),
		CFrame = CFrame.new(position),
		Color = Color3.fromRGB(255, 154, 58),
		Material = Enum.Material.Neon,
		Transparency = transparency,
		Parent = parent,
	})

	return part
end

local function makePathStartAttachment(parent, position)
	local pointPart = makePathPoint(parent, "PathStart", position, 0.26, 0.36)
	return make("Attachment", {
		Name = "Attachment1",
		Parent = pointPart,
	})
end

local function addEmbers(attachment, rate)
	make("ParticleEmitter", {
		Name = "Embers",
		Texture = "rbxasset://textures/particles/fire_main.dds",
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 241, 132)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 120, 44)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(106, 209, 255)),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.65, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.18),
			NumberSequenceKeypoint.new(0.55, 0.32),
			NumberSequenceKeypoint.new(1, 0),
		}),
		LightEmission = 1,
		Rate = rate,
		Lifetime = NumberRange.new(0.35, 0.75),
		Speed = NumberRange.new(0.45, 1.35),
		SpreadAngle = Vector2.new(25, 25),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-80, 80),
		Parent = attachment,
	})
end

local function addPathBeam(parent, attachment0, attachment1, curve0, curve1)
	curve0 = curve0 or 0
	curve1 = curve1 or 0

	make("Beam", {
		Name = "FireGuide",
		Attachment0 = attachment0,
		Attachment1 = attachment1,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 245, 125)),
			ColorSequenceKeypoint.new(0.48, Color3.fromRGB(255, 119, 40)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 210, 255)),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.32),
			NumberSequenceKeypoint.new(0.5, 0.12),
			NumberSequenceKeypoint.new(1, 0.32),
		}),
		Width0 = 0.54,
		Width1 = 0.54,
		CurveSize0 = curve0,
		CurveSize1 = curve1,
		FaceCamera = true,
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 4,
		Segments = K.PATH_BEAM_SEGMENTS,
		Texture = "rbxasset://textures/particles/fire_main.dds",
		TextureLength = 4,
		TextureMode = Enum.TextureMode.Wrap,
		TextureSpeed = 2.5,
		Parent = parent,
	})

	make("Beam", {
		Name = "GuideCore",
		Attachment0 = attachment0,
		Attachment1 = attachment1,
		Color = ColorSequence.new(Color3.fromRGB(255, 252, 210), Color3.fromRGB(126, 226, 255)),
		Transparency = NumberSequence.new(0.08),
		Width0 = 0.16,
		Width1 = 0.16,
		CurveSize0 = curve0,
		CurveSize1 = curve1,
		FaceCamera = true,
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 3,
		Segments = K.PATH_BEAM_SEGMENTS,
		Parent = parent,
	})
end

local function isTargetHit(instance, targetModel, targetPart)
	if not instance then
		return false
	end

	if targetPart then
		return instance == targetPart or instance:IsDescendantOf(targetPart)
	end

	return targetModel and instance and instance:IsDescendantOf(targetModel)
end

local function isCollidableBlocker(instance)
	if not instance then
		return false
	end

	if instance:IsA("BasePart") then
		return instance.CanCollide
	end

	return true
end

local function addPathIgnore(ignore, instance)
	if instance then
		table.insert(ignore, instance)
	end
end

local function pathIgnoreList()
	local ignore = {}
	addPathIgnore(ignore, pathFolder)
	addPathIgnore(ignore, getCharacter())
	return ignore
end

local function pathRaycastParams(ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	pcall(function()
		params.RespectCanCollide = true
	end)
	Logic._applyRootCollisionGroup(params)

	return params
end

local function castPathSegment(origin, direction, params)
	local radius = Logic._currentRootClearanceRadius()
	if pathSpherecastAvailable ~= false then
		local ok, result = pcall(function()
			return workspace:Spherecast(origin, radius, direction, params)
		end)

		if ok then
			pathSpherecastAvailable = true
			return result
		end

		pathSpherecastAvailable = false
	end

	local result = workspace:Raycast(origin, direction, params)
	if result then
		return result
	end

	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	local flatLengthSquared = magnitudeSquared(flatDirection)
	if flatLengthSquared <= 0.01 then
		return nil
	end

	local forward = flatDirection / math.sqrt(flatLengthSquared)
	local right = Vector3.new(-forward.Z, 0, forward.X)

	local sideOffset = right * radius
	result = workspace:Raycast(origin + sideOffset, direction, params)
	if result then
		return result
	end

	result = workspace:Raycast(origin - sideOffset, direction, params)
	if result then
		return result
	end

	local forwardOffset = forward * radius * 0.5
	result = workspace:Raycast(origin + forwardOffset, direction, params)
	if result then
		return result
	end

	result = workspace:Raycast(origin - forwardOffset, direction, params)
	if result then
		return result
	end

	return nil
end

local function isSegmentBlockedByCollidable(fromPosition, toPosition, targetModel, allowTargetHit, targetPart)
	local direction = toPosition - fromPosition
	local distanceSquaredValue = magnitudeSquared(direction)
	if distanceSquaredValue <= 0.01 then
		return false
	end

	local distance = math.sqrt(distanceSquaredValue)
	local unit = direction / distance
	local ignore = pathIgnoreList()

	local origin = fromPosition
	local remaining = distance
	for _ = 1, 24 do
		local params = pathRaycastParams(ignore)
		local result = castPathSegment(origin, unit * remaining, params)
		if not result then
			return false
		end

		local hit = result.Instance
		local collidable = isCollidableBlocker(hit)
		if isTargetHit(hit, targetModel, targetPart) then
			if allowTargetHit then
				return false
			end

			if collidable then
				return true
			end
		end

		if collidable then
			return true
		end

		if hit then
			table.insert(ignore, hit)
		end

		local hitDistance = result.Distance
		if not hitDistance then
			hitDistance = math.max((result.Position - origin):Dot(unit), 0)
		end

		origin = result.Position + unit * 0.12
		remaining = remaining - hitDistance - 0.12
		if remaining <= 0.1 then
			return false
		end
	end

	return false
end

local function isSegmentWalkable(fromPosition, toPosition, targetModel)
	return not isSegmentBlockedByCollidable(fromPosition, toPosition, targetModel)
end

local function closestPointOnSegment(point, startPosition, endPosition)
	local segment = endPosition - startPosition
	local lengthSquared = segment:Dot(segment)
	if lengthSquared <= 0.01 then
		return startPosition, 0
	end

	local alpha = math.clamp((point - startPosition):Dot(segment) / lengthSquared, 0, 1)
	return startPosition + segment * alpha, alpha
end

local function nearestRenderedPathSegment(position)
	local nearest
	for model, route in pairs(Logic._pathRoutes) do
		local points = route.points
		if route.folder and route.folder.Parent and points and #points >= 2 then
			for segmentIndex = 1, #points - 1 do
				local startPosition = points[segmentIndex]
				local endPosition = points[segmentIndex + 1]
				local closestPoint, alpha = closestPointOnSegment(position, startPosition, endPosition)
				local distanceSq = distanceSquared(position, closestPoint)
				if not nearest or distanceSq < nearest.distanceSq then
					nearest = {
						routeKey = route.key,
						model = model,
						distanceSq = distanceSq,
						progress = segmentIndex + alpha,
					}
				end
			end
		end
	end

	return nearest
end

local function routeHasBlockedSegment(route)
	local points = route and route.points
	if not points or #points < 2 then
		return false
	end

	for segmentIndex = 1, #points - 2 do
		if isSegmentBlockedByCollidable(points[segmentIndex], points[segmentIndex + 1], nil, false) then
			return true
		end
	end

	return false
end

local function renderedPathHasBlockedSegment()
	for model, route in pairs(Logic._pathRoutes) do
		if route.folder and route.folder.Parent and routeHasBlockedSegment(route) then
			return model
		end
	end

	return nil
end

local function refreshFromRenderedBlockers()
	if not active or not pathTreeEnabled or not requestPathTreeRefresh then
		return
	end

	local now = os.clock()
	if now - Logic._pathLastBlockedCheckClock < K.PATH_BLOCKED_CHECK_INTERVAL then
		return
	end

	Logic._pathLastBlockedCheckClock = now
	if now - Logic._pathLastBlockedRefreshClock < K.PATH_BLOCKED_REFRESH_COOLDOWN then
		return
	end

	local model = renderedPathHasBlockedSegment()
	if model then
		Logic._pathLastBlockedRefreshClock = now
		requestPathTreeRefresh(false, model)
	end
end

local function refreshFromRouteProximity()
	if not active or not pathTreeEnabled or not requestPathTreeRefresh then
		return
	end

	local root = Logic._getRootPart() or getTorsoPart()
	if not root then
		return
	end

	local nearest = nearestRenderedPathSegment(root.Position)
	if not nearest then
		pathActiveRouteKey = nil
		pathActiveRouteProgress = nil
		return
	end

	if nearest.distanceSq > K.PATH_ACTIVE_ROUTE_RESET_DISTANCE_SQ then
		pathActiveRouteKey = nil
		pathActiveRouteProgress = nil
		return
	end

	if nearest.distanceSq > K.PATH_ROUTE_PROXIMITY_SQ then
		return
	end

	local now = os.clock()
	local routeChanged = pathActiveRouteKey ~= nearest.routeKey
	local progressed = not pathActiveRouteProgress or math.abs(nearest.progress - pathActiveRouteProgress) >= K.PATH_ROUTE_PROGRESS_STEP
	local touchingRoute = nearest.distanceSq <= K.PATH_ROUTE_TOUCH_PROXIMITY_SQ
	local cooldown = touchingRoute and K.PATH_ROUTE_TOUCH_REFRESH_COOLDOWN or K.PATH_ROUTE_REFRESH_COOLDOWN
	pathActiveRouteKey = nearest.routeKey
	pathActiveRouteProgress = nearest.progress

	if routeChanged or ((touchingRoute or progressed) and now - pathLastRouteRefreshClock >= cooldown) then
		pathLastRouteRefreshClock = now
		requestPathTreeRefresh(false, nearest.model)
	end
end

local function appendPathPoint(points, position, minDistance)
	local previous = points[#points]
	local minDistanceValue = minDistance or 1.25
	if previous and distanceSquared(previous, position) < minDistanceValue * minDistanceValue then
		return false
	end

	table.insert(points, position)
	return true
end

local function appendExactPathPoint(points, position)
	local previous = points[#points]
	if previous and distanceSquared(previous, position) < 0.0025 then
		points[#points] = position
		return false
	end

	table.insert(points, position)
	return true
end

local function appendVisualTarget(points, target, targetModel, targetPart)
	if not points or #points == 0 then
		return nil
	end

	-- For hitbox-backed generators, the endpoint is already a grounded approach
	-- point. Never append another visual segment into hitbox/model center.
	if targetPart or (targetModel and Logic._getGeneratorHitBox(targetModel)) then
		return points
	end

	if isSegmentBlockedByCollidable(points[#points], target, targetModel, true, targetPart) then
		return nil
	end

	appendExactPathPoint(points, target)
	return points
end

local function pathSegmentsClear(points, targetModel)
	for index = 1, #points - 1 do
		if not isSegmentWalkable(points[index], points[index + 1], targetModel) then
			return false
		end
	end

	return true
end

function Logic._vectorCacheKey(position)
	return string.format(
		"%d,%d,%d",
		math.floor(position.X * 2 + 0.5),
		math.floor(position.Y * 2 + 0.5),
		math.floor(position.Z * 2 + 0.5)
	)
end

function Logic._navigationCacheKey(origin, destination)
	return Logic._vectorCacheKey(origin) .. "|" .. Logic._vectorCacheKey(destination)
end

function Logic._getPathWaypoints(path)
	local waypoints = Logic._pathWaypointCache[path]
	if not waypoints then
		waypoints = path:GetWaypoints()
		Logic._pathWaypointCache[path] = waypoints
	end

	return waypoints
end

function Logic._pathHasJumpWaypoint(path)
	for _, waypoint in ipairs(Logic._getPathWaypoints(path)) do
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			return true
		end
	end

	return false
end

function Logic._navigationPathLength(path, origin, destination)
	local length = 0
	local previous = origin

	for _, waypoint in ipairs(Logic._getPathWaypoints(path)) do
		local position = waypoint.Position
		local distance = (position - previous).Magnitude
		if distance > 0.25 then
			length = length + distance
			previous = position
		end
	end

	local finalDistance = (destination - previous).Magnitude
	if finalDistance > 0.25 then
		length = length + finalDistance
	end

	return length
end

function Logic._computeNavigationPath(origin, destination)
	if distanceSquared(destination, origin) <= 1 then
		return nil
	end

	local key = Logic._navigationCacheKey(origin, destination)
	local cached = Logic._pathNavigationCache[key]
	if cached ~= nil then
		return cached or nil
	end

	local ok, path = pcall(function()
		local nextPath = PathfindingService:CreatePath(currentPathAgent())
		nextPath:ComputeAsync(origin, destination)
		return nextPath
	end)

	if not ok or not path or path.Status ~= Enum.PathStatus.Success or Logic._pathHasJumpWaypoint(path) then
		Logic._pathNavigationCache[key] = false
		return nil
	end

	Logic._pathNavigationCache[key] = path
	return path
end

function Logic._isNavigationDirectEnough(origin, destination)
	local directDistance = (destination - origin).Magnitude
	if directDistance <= 1 then
		return true
	end

	local path = Logic._computeNavigationPath(origin, destination)
	if not path then
		return false
	end

	return Logic._navigationPathLength(path, origin, destination) <= directDistance * K.PATH_NAV_DIRECT_RATIO + K.PATH_NAV_DIRECT_EXTRA
end

function Logic._isShortcutWalkable(fromPosition, toPosition, targetModel)
	if not isSegmentWalkable(fromPosition, toPosition, targetModel) then
		return false
	end

	return Logic._isNavigationDirectEnough(fromPosition, toPosition)
end

local function simplifyPathPoints(rawPoints, targetModel)
	if #rawPoints <= 2 then
		return rawPoints
	end

	local points = { rawPoints[1] }
	local anchorIndex = 1
	local shortcutTests = 0
	while anchorIndex < #rawPoints do
		local nextIndex = anchorIndex + 1

		for candidateIndex = #rawPoints, anchorIndex + 2, -1 do
			shortcutTests = shortcutTests + 1
			if shortcutTests > K.PATH_MAX_SHORTCUT_TESTS then
				break
			end

			if Logic._isShortcutWalkable(rawPoints[anchorIndex], rawPoints[candidateIndex], targetModel) then
				nextIndex = candidateIndex
				break
			end
		end

		if nextIndex == #rawPoints then
			appendExactPathPoint(points, rawPoints[nextIndex])
		else
			appendPathPoint(points, rawPoints[nextIndex])
		end
		anchorIndex = nextIndex
	end

	return points
end

local pathScore

local function appendNavigationWaypoints(points, path, origin, destination)
	for _, waypoint in ipairs(Logic._getPathWaypoints(path)) do
		local position = waypoint.Position
		if distanceSquared(position, origin) > 4 and distanceSquared(position, destination) > 9 then
			appendPathPoint(points, position + Vector3.new(0, K.PATH_FLOAT_HEIGHT, 0))
		end
	end

	appendExactPathPoint(points, destination)
end

local function computeGroundedPathPoints(origin, destination, targetModel)
	local directDistanceSq = distanceSquared(destination, origin)
	if directDistanceSq <= 1 then
		return { origin, destination }
	end

	local heightDelta = destination.Y - origin.Y
	local shortLocalGrounded = directDistanceSq <= K.PATH_LOCAL_VISIBLE_DIRECT_DISTANCE_SQ
		and heightDelta <= 1.5
		and math.abs(heightDelta) <= K.PATH_FALL_TAKEOFF_MAX_HEIGHT_DIFF
	if isSegmentWalkable(origin, destination, targetModel)
		and (shortLocalGrounded or Logic._isNavigationDirectEnough(origin, destination)) then
		return { origin, destination }
	end

	local path = Logic._computeNavigationPath(origin, destination)
	if not path then
		return nil
	end

	local rawPoints = { origin }
	appendNavigationWaypoints(rawPoints, path, origin, destination)

	local simplified = simplifyPathPoints(rawPoints, targetModel)
	if pathSegmentsClear(simplified, targetModel) then
		return simplified
	end

	if pathSegmentsClear(rawPoints, targetModel) then
		return rawPoints
	end

	return nil
end

local function horizontalUnitAndDistance(fromPosition, toPosition)
	local delta = Vector3.new(toPosition.X - fromPosition.X, 0, toPosition.Z - fromPosition.Z)
	local distance = delta.Magnitude
	if distance <= 1 then
		return nil, distance
	end

	return delta / distance, distance
end

local function addFallTransition(transitions, takeoff, landing)
	for _, transition in ipairs(transitions) do
		if distanceSquared(transition.takeoff, takeoff) < 4 and distanceSquared(transition.landing, landing) < 4 then
			return false
		end
	end

	table.insert(transitions, {
		takeoff = takeoff,
		landing = landing,
	})

	return true
end

local function collectFallTransitions(origin, destination, targetModel)
	local direction, horizontalDistance = horizontalUnitAndDistance(origin, destination)
	if not direction then
		return {}
	end

	local transitions = {}
	local maxDistance = math.min(
		horizontalDistance + K.PATH_FALL_LANDING_FORWARD_STEP * K.PATH_FALL_LANDING_FORWARD_TESTS,
		K.PATH_FALL_SEARCH_DISTANCE
	)
	local distance = math.max(K.PATH_FALL_SEARCH_STEP, K.PATH_FALL_EDGE_BACKSTEP + 0.5)

	while distance <= maxDistance and #transitions < K.PATH_FALL_MAX_TRANSITIONS do
		local takeoffProbe = origin + direction * math.max(distance - K.PATH_FALL_EDGE_BACKSTEP, 0)
		local takeoff = Logic._projectToWalkablePathPosition(takeoffProbe, targetModel)

		if takeoff and math.abs(takeoff.Y - origin.Y) <= K.PATH_FALL_TAKEOFF_MAX_HEIGHT_DIFF then
			for forwardIndex = 0, K.PATH_FALL_LANDING_FORWARD_TESTS do
				local landingProbe = origin + direction * (distance + forwardIndex * K.PATH_FALL_LANDING_FORWARD_STEP)
				local landing = Logic._projectFallLandingPathPosition(landingProbe, takeoff.Y, targetModel)

				if landing and isSegmentWalkable(takeoff, landing, targetModel) then
					addFallTransition(transitions, takeoff, landing)
					break
				end
			end
		end

		distance = distance + K.PATH_FALL_SEARCH_STEP
	end

	return transitions
end

local function appendPointList(points, nextPoints, startIndex)
	for index = startIndex or 1, #nextPoints do
		if index == #nextPoints then
			appendExactPathPoint(points, nextPoints[index])
		else
			appendPathPoint(points, nextPoints[index])
		end
	end
end

local function computeFallPathToDestination(origin, destination, target, targetModel, targetPart)
	local bestPoints
	local bestScore
	for _, transition in ipairs(collectFallTransitions(origin, destination, targetModel)) do
		local prefix = computeGroundedPathPoints(origin, transition.takeoff, targetModel)
		local suffix = computeGroundedPathPoints(transition.landing, destination, targetModel)

		if prefix and suffix then
			local points = {}
			appendPointList(points, prefix, 1)
			appendExactPathPoint(points, transition.landing)
			appendPointList(points, suffix, 2)

			local visualPath = appendVisualTarget(points, target, targetModel, targetPart)
			if visualPath then
				local score = pathScore(visualPath)
				if not bestScore or score < bestScore then
					bestPoints = visualPath
					bestScore = score
				end
			end
		end
	end

	return bestPoints
end

local function unitAndDistance(fromPosition, toPosition)
	local delta = toPosition - fromPosition
	local distance = delta.Magnitude
	if distance <= 0.1 then
		return nil, distance
	end

	return delta / distance, distance
end

local function clampUnitDot(value)
	return math.clamp(value, -1, 1)
end

function pathScore(points)
	local pointCount = #points
	local length = 0
	local turnCost = 0
	local previousDirection

	for index = 1, pointCount - 1 do
		local delta = points[index + 1] - points[index]
		local distance = delta.Magnitude
		if distance > 0.1 then
			length = length + distance
			local direction = delta / distance
			if previousDirection then
				local dot = clampUnitDot(previousDirection:Dot(direction))
				if dot < K.PATH_TURN_DOT then
					turnCost = turnCost + 1 - dot
				end
			end
			previousDirection = direction
		end
	end

	return length + turnCost * K.PATH_TURN_SCORE + math.max(pointCount - 2, 0) * K.PATH_POINT_SCORE
end

local function cornerSplit(points, pointIndex, targetModel)
	if pointIndex <= 1 or pointIndex >= #points then
		return nil
	end

	local incomingDirection, incomingDistance = unitAndDistance(points[pointIndex - 1], points[pointIndex])
	local outgoingDirection, outgoingDistance = unitAndDistance(points[pointIndex], points[pointIndex + 1])
	if not incomingDirection or not outgoingDirection then
		return nil
	end

	local dot = clampUnitDot(incomingDirection:Dot(outgoingDirection))
	if dot > K.PATH_TURN_DOT then
		return nil
	end

	if incomingDistance < K.PATH_CORNER_MIN_SEGMENT or outgoingDistance < K.PATH_CORNER_MIN_SEGMENT then
		return nil
	end

	local splitDistance = math.min(K.PATH_CORNER_SPLIT_DISTANCE, incomingDistance * 0.4, outgoingDistance * 0.4)
	local beforeTurn = points[pointIndex] - incomingDirection * splitDistance
	local afterTurn = points[pointIndex] + outgoingDirection * splitDistance
	if not isSegmentWalkable(beforeTurn, afterTurn, targetModel) then
		return nil
	end

	local sign = incomingDirection:Cross(outgoingDirection).Y >= 0 and 1 or -1
	return beforeTurn, afterTurn, sign * K.PATH_CORNER_CURVE
end

local function buildRenderPath(points, targetModel)
	if #points <= 2 then
		return {
			points = points,
			curves = {},
		}
	end

	local renderPoints = { points[1] }
	local curves = {}

	for index = 2, #points - 1 do
		local beforeTurn, afterTurn, curve = cornerSplit(points, index, targetModel)
		if beforeTurn and afterTurn then
			appendPathPoint(renderPoints, beforeTurn, 0.05)
			local curveSegmentIndex = #renderPoints
			appendPathPoint(renderPoints, afterTurn, 0.05)
			if #renderPoints == curveSegmentIndex + 1 then
				curves[curveSegmentIndex] = curve
			end
		else
			appendPathPoint(renderPoints, points[index], 0.05)
		end
	end

	appendExactPathPoint(renderPoints, points[#points])
	return {
		points = renderPoints,
		curves = curves,
	}
end

local function computePathToDestination(origin, destination, target, targetModel, targetPart)
	local rawPoints = { origin }
	local path = Logic._computeNavigationPath(origin, destination)

	if path then
		for _, waypoint in ipairs(Logic._getPathWaypoints(path)) do
			local position = waypoint.Position
			if distanceSquared(position, origin) > 4 and distanceSquared(position, destination) > 9 then
				appendPathPoint(rawPoints, position + Vector3.new(0, K.PATH_FLOAT_HEIGHT, 0))
			end
		end

		appendExactPathPoint(rawPoints, destination)
		local simplified = simplifyPathPoints(rawPoints, targetModel)
		if pathSegmentsClear(simplified, targetModel) then
			local visualPath = appendVisualTarget(simplified, target, targetModel, targetPart)
			if visualPath then
				return visualPath
			end
		end

		local visualPath = appendVisualTarget(rawPoints, target, targetModel, targetPart)
		if visualPath then
			return visualPath
		end

		return nil
	end

	return nil
end

local function computeVisiblePathToDestination(origin, destination, target, targetModel, targetPart)
	if not isSegmentWalkable(origin, destination, targetModel) then
		return nil
	end

	if distanceSquared(origin, destination) > K.PATH_LOCAL_VISIBLE_DIRECT_DISTANCE_SQ
		and not Logic._isNavigationDirectEnough(origin, destination) then
		return nil
	end

	local points = { origin }
	appendExactPathPoint(points, destination)
	return appendVisualTarget(points, target, targetModel, targetPart)
end

local function computePathPoints(origin, target, targetModel, targetPart)
	local destinations = collectPathTargetPositions(targetModel, target, origin)
	local bestPoints
	local bestScore
	for _, destination in ipairs(destinations) do
		local points = computeVisiblePathToDestination(origin, destination, target, targetModel, targetPart)
		if points then
			local score = pathScore(points)
			if not bestScore or score < bestScore then
				bestPoints = points
				bestScore = score
			end
		end
	end

	if bestPoints then
		return bestPoints
	end

	for _, destination in ipairs(destinations) do
		local points = computePathToDestination(origin, destination, target, targetModel, targetPart)
		if points then
			local score = pathScore(points)
			if not bestScore or score < bestScore then
				bestPoints = points
				bestScore = score
			end
		end
	end

	for _, destination in ipairs(destinations) do
		local points = computeFallPathToDestination(origin, destination, target, targetModel, targetPart)
		if points then
			local score = pathScore(points)
			if not bestScore or score < bestScore then
				bestPoints = points
				bestScore = score
			end
		end
	end

	return bestPoints
end

local function collectGeneratorEntries(origin)
	local entries = {}
	for model in pairs(trackedGenerators) do
		local target, hitBox = nil, nil
		if not isGeneratorComplete(model) then
			target, hitBox = Logic._generatorTargetPosition(model)
		end

		if target then
			table.insert(entries, {
				model = model,
				target = target,
				targetPart = hitBox,
				distanceSq = distanceSquared(target, origin),
			})
		end
	end

	table.sort(entries, function(a, b)
		return a.distanceSq < b.distanceSq
	end)

	return entries
end

local function buildGeneratorPath(root, origin, entry, buildId)
	local target = entry.target
	local points = computePathPoints(origin, target, entry.model, entry.targetPart)
	if not points then
		return false
	end

	local renderPath = buildRenderPath(points, entry.model)
	points = renderPath.points
	local curves = renderPath.curves

	if not isCurrentPathBuild(root, buildId) then
		return false
	end

	local startAttachment = makePathStartAttachment(root, origin)
	local attachments = { startAttachment }
	local finalIsGeneratorApproach = entry.targetPart ~= nil or Logic._getGeneratorHitBox(entry.model) ~= nil

	for pointIndex = 2, #points do
		if not isCurrentPathBuild(root, buildId) then
			return false
		end

		local isTargetPoint = pointIndex == #points
		local pointPart = makePathPoint(
			root,
			isTargetPoint and (finalIsGeneratorApproach and "GeneratorApproach" or "GeneratorCenter") or "PathPoint",
			points[pointIndex],
			isTargetPoint and 0.5 or 0.22,
			isTargetPoint and 0.08 or 0.28
		)
		local attachment = make("Attachment", {
			Name = isTargetPoint and "Attachment2" or "PathPoint",
			Parent = pointPart,
		})
		table.insert(attachments, attachment)

		if isTargetPoint then
			addEmbers(attachment, 3)
		elseif pointIndex % 4 == 0 then
			addEmbers(attachment, 1)
		end
	end

	for segmentIndex = 1, #attachments - 1 do
		if not isCurrentPathBuild(root, buildId) then
			return false
		end

		local curve = curves[segmentIndex] or 0
		addPathBeam(root, attachments[segmentIndex], attachments[segmentIndex + 1], curve, -curve)
	end

	return {
		points = points,
		curves = curves,
	}
end

local function refreshPathTree(force)
	if not pathTreeEnabled then
		clearPathVisuals()
		return
	end

	local torso = getTorsoPart()
	if not torso then
		clearPathVisuals()
		return
	end

	if not mapContainer then
		setMapContainer(workspace:FindFirstChild("Map"))
	end

	if not mapContainer then
		clearPathVisuals()
		return
	end

	local origin = torso.Position
	local entries = collectGeneratorEntries(origin)
	if #entries == 0 then
		resyncMap()
		entries = collectGeneratorEntries(origin)
	end

	local now = os.clock()
	table.clear(Logic._pathNavigationCache)
	table.clear(Logic._pathWaypointCache)

	if not Logic._ensurePathFolder() then
		return
	end

	pathBuildId = pathBuildId + 1
	local buildId = pathBuildId

	local seenModels = {}
	local builtPathCount = 0
	local routeBuilds = 0
	local pendingMoreRoutes = false

	for _, entry in ipairs(entries) do
		seenModels[entry.model] = true
	end

	Logic._prunePathRoutes(seenModels)

	for index, entry in ipairs(entries) do
		if not active or not pathTreeEnabled or buildId ~= pathBuildId then
			return
		end

		local route = Logic._routeForModel(entry.model)
		if Logic._shouldRefreshRoute(route, origin, entry, now, force == true) then
			if routeBuilds >= K.PATH_MAX_ROUTE_BUILDS_PER_REFRESH then
				Logic._pathQueuedModels[entry.model] = true
				pendingMoreRoutes = true
			else
				routeBuilds = routeBuilds + 1
				local buildFolder = Logic._createRouteBuildFolder(route)
				local routeData = buildGeneratorPath(buildFolder, origin, entry, buildId)
				if routeData and isCurrentPathBuild(buildFolder, buildId) then
					local finishedAt = os.clock()
					Logic._swapRouteFolder(route, buildFolder)
					route.points = routeData.points
					route.curves = routeData.curves
					route.lastOrigin = origin
					route.lastTarget = entry.target
					route.lastRefreshClock = finishedAt
					route.nextRetryClock = nil
					builtPathCount = builtPathCount + 1
				else
					if buildFolder then
						buildFolder:Destroy()
					end
					if route.buildFolder == buildFolder then
						route.buildFolder = nil
					end
					route.nextRetryClock = now + 0.5
					route.lastRefreshClock = nil
				end

				Logic._pathQueuedModels[entry.model] = nil
			end
		elseif route.folder and route.folder.Parent then
			builtPathCount = builtPathCount + 1
		end

		if index % 3 == 0 then
			task.wait()
		end
	end

	if pendingMoreRoutes then
		pathRefreshQueued = true
	end

	return builtPathCount > 0 or #entries == 0
end

requestPathTreeRefresh = function(force, targetModel)
	if not active or not pathTreeEnabled then
		return
	end

	if targetModel then
		Logic._pathQueuedModels[targetModel] = true
	end

	pathRefreshQueued = true
	pathForceRefresh = pathForceRefresh or force == true
	if pathRefreshRunning then
		return
	end

	pathRefreshRunning = true
	task.spawn(function()
		while active and pathTreeEnabled and pathRefreshQueued do
			local forceNow = pathForceRefresh
			pathRefreshQueued = false
			pathForceRefresh = false
			refreshPathTree(forceNow)
			task.wait()
		end

		pathRefreshRunning = false
	end)
end

local function applyPathTree()
	if pathTreeEnabled then
		resyncMap()
		requestPathTreeRefresh(true)
	else
		clearPathVisuals()
	end
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
			if highlightsEnabled or pathTreeEnabled then
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
	if name == "SkillCheck" and not factory then
		error("Failed to load Skill Check module: " .. tostring(loadFailure), 0)
	end

	factory = factory or fallbackFactory
	local ok, feature = pcall(factory, context)
	if ok and type(feature) == "table" then
		return feature
	end
	if name == "SkillCheck" then
		error("Failed to initialize Skill Check module: " .. tostring(feature), 0)
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

	featureModules.PathTree = Logic._loadFeatureModule("PathTree", Logic._fallbackToggleFeature, {
		getEnabled = function()
			return pathTreeEnabled
		end,
		setEnabled = function(value)
			pathTreeEnabled = value
		end,
		apply = applyPathTree,
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

function Logic.setPathTreeEnabled(on)
	Logic._installFeatureModules()
	featureModules.PathTree.setEnabled(on)
end

function Logic.togglePathTree()
	Logic._installFeatureModules()
	featureModules.PathTree.toggle()
end

function Logic.setProjectileVisualiserEnabled(on)
	Logic._installFeatureModules()
	featureModules.ProjectileVisualiser.setEnabled(on)
end

function Logic.toggleProjectileVisualiser()
	Logic._installFeatureModules()
	featureModules.ProjectileVisualiser.toggle()
end

function Logic.setSkillCheckEnabled(on)
	Logic._installFeatureModules()
	featureModules.SkillCheck.setEnabled(on)
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
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if projectileWeaponActive() then
				setProjectileHolding(true, nil)
			end
			return
		end

		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.Y then
				Logic.toggleHighlights()
			elseif input.KeyCode == Enum.KeyCode.F then
				Logic.togglePathTree()
			elseif input.KeyCode == Enum.KeyCode.G then
				Logic.toggleSkillCheck()
			elseif input.KeyCode == Enum.KeyCode.H then
				Logic.toggleProjectileVisualiser()
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
		if pathTreeEnabled then
			clearPathVisuals()
			task.defer(function()
				if active and pathTreeEnabled and requestPathTreeRefresh then
					requestPathTreeRefresh(true)
				end
			end)
		end
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

	task.spawn(function()
		while active do
			task.wait(K.PATH_REFRESH_INTERVAL)
			if pathTreeEnabled then
				requestPathTreeRefresh(false)
			end
		end
	end)

	task.spawn(function()
		while active do
			task.wait(K.PATH_ROUTE_CHECK_INTERVAL)
			refreshFromRenderedBlockers()
			refreshFromRouteProximity()
		end
	end)

	applyHighlights()
	if pathTreeEnabled then
		applyPathTree()
	end
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
	clearPathVisuals()
	destroyProjectileVisuals()
	stopProjectileHeartbeat()
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
Logic.Version = VERSION

if globalState then
	globalState[GLOBAL_KEY] = Logic
end

return Logic
