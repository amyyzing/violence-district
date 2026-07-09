local LOGIC_KEY = "ViolenceDistrictLogic"
local GUI_KEY = "ViolenceDistrictGui"
local BASE_KEY = "ViolenceDistrictBaseUrl"
local DEFAULT_BASE_URL = "https://raw.githubusercontent.com/amyyzing/violence-district/main/"
local LOGIC_VERSION = 54

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local globalState = getgenv and getgenv() or _G
local baseUrl = globalState[BASE_KEY] or DEFAULT_BASE_URL
local LOGIC_URL = baseUrl .. "features/logic.luau"

if globalState[GUI_KEY] and globalState[GUI_KEY].destroy then
	globalState[GUI_KEY].destroy()
end

local existingGui = PG:FindFirstChild("CateyesGui")
if existingGui then
	existingGui:Destroy()
end

local Logic = globalState[LOGIC_KEY]
if Logic and Logic.Version ~= LOGIC_VERSION then
	if Logic.destroy then
		Logic.destroy()
	end
	globalState[LOGIC_KEY] = nil
	Logic = nil
end

if not Logic then
	local chunk, err = loadstring(game:HttpGet(LOGIC_URL))
	if not chunk then
		error("Failed to load logic: " .. tostring(err), 0)
	end

	Logic = chunk()
end

local connections = {}
local sg
local cursorState

local function captureCursorState()
	if cursorState then
		return
	end

	cursorState = {
		mouseBehavior = UserInputService.MouseBehavior,
		mouseIconEnabled = UserInputService.MouseIconEnabled,
	}
end

local function setCursorFree()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

local function restoreCursorState()
	if not cursorState then
		return
	end

	UserInputService.MouseBehavior = cursorState.mouseBehavior
	UserInputService.MouseIconEnabled = cursorState.mouseIconEnabled
	cursorState = nil
end

local function syncCursorToGui()
	if sg and sg.Enabled then
		captureCursorState()
		setCursorFree()
	else
		restoreCursorState()
	end
end

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function make(className, props)
	local obj = Instance.new(className)
	for key, value in pairs(props) do
		obj[key] = value
	end
	return obj
end

local function addCorner(parent, radius)
	return make("UICorner", {
		CornerRadius = UDim.new(0, radius or 8),
		Parent = parent,
	})
end

local function addStroke(parent, color, transparency)
	return make("UIStroke", {
		Color = color,
		Thickness = 1,
		Transparency = transparency or 0,
		Parent = parent,
	})
end

local colors = {
	panel = Color3.fromRGB(19, 20, 23),
	panelStroke = Color3.fromRGB(65, 70, 78),
	surface = Color3.fromRGB(29, 32, 36),
	surfaceHover = Color3.fromRGB(37, 41, 46),
	surfaceStroke = Color3.fromRGB(55, 60, 68),
	text = Color3.fromRGB(242, 244, 247),
	muted = Color3.fromRGB(150, 157, 166),
	on = Color3.fromRGB(46, 184, 116),
	off = Color3.fromRGB(78, 83, 91),
	accent = Color3.fromRGB(94, 166, 255),
	accentHover = Color3.fromRGB(126, 188, 255),
}

local dropdownTweenInfo = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local dropdownOpenSize = UDim2.new(1, -32, 0, 66)
local dropdownClosedSize = UDim2.new(1, -32, 0, 0)

sg = make("ScreenGui", {
	Name = "CateyesGui",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = PG,
})

local panel = make("Frame", {
	Name = "Panel",
	Size = UDim2.new(0, 286, 0, 386),
	Position = UDim2.new(0, 48, 0, 48),
	BackgroundColor3 = colors.panel,
	BackgroundTransparency = 0.02,
	BorderSizePixel = 0,
	Parent = sg,
})
addCorner(panel, 8)
addStroke(panel, colors.panelStroke, 0.18)

make("TextLabel", {
	Name = "Title",
	Size = UDim2.new(1, -32, 0, 26),
	Position = UDim2.new(0, 16, 0, 14),
	BackgroundTransparency = 1,
	Text = "Cateyes",
	TextColor3 = colors.text,
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = panel,
})

local statusText = make("TextLabel", {
	Name = "Status",
	Size = UDim2.new(1, -32, 0, 18),
	Position = UDim2.new(0, 16, 0, 38),
	BackgroundTransparency = 1,
	Text = "Highlights off",
	TextColor3 = colors.muted,
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = panel,
})

local togglePills = {}

local function makeToggleRow(name, y, onClick)
	local row = make("TextButton", {
		Name = name .. "Row",
		Size = UDim2.new(1, -32, 0, 42),
		Position = UDim2.new(0, 16, 0, y),
		BackgroundColor3 = colors.surface,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Parent = panel,
	})
	addCorner(row, 8)
	addStroke(row, colors.surfaceStroke, 0.35)

	make("TextLabel", {
		Name = "Label",
		Size = UDim2.new(1, -86, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = colors.text,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	local pill = make("TextLabel", {
		Name = "State",
		Size = UDim2.new(0, 56, 0, 24),
		Position = UDim2.new(1, -68, 0.5, -12),
		BackgroundColor3 = colors.off,
		BorderSizePixel = 0,
		Text = "OFF",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		Parent = row,
	})
	addCorner(pill, 12)

	connect(row.MouseEnter, function()
		row.BackgroundColor3 = colors.surfaceHover
	end)

	connect(row.MouseLeave, function()
		row.BackgroundColor3 = colors.surface
	end)

	connect(row.MouseButton1Click, onClick)
	togglePills[name] = pill
end

makeToggleRow("Highlights", 68, function()
	Logic.toggleHighlights()
end)

makeToggleRow("Skill Check", 118, function()
	Logic.toggleSkillCheck()
end)

makeToggleRow("Path Tree", 168, function()
	Logic.togglePathTree()
end)

makeToggleRow("Projectile Visualiser", 218, function()
	Logic.toggleProjectileVisualiser()
end)

local modeRow = make("Frame", {
	Name = "ModeRow",
	Size = UDim2.new(1, -32, 0, 42),
	Position = UDim2.new(0, 16, 0, 268),
	BackgroundColor3 = colors.surface,
	BorderSizePixel = 0,
	Parent = panel,
})
addCorner(modeRow, 8)
addStroke(modeRow, colors.surfaceStroke, 0.35)

make("TextLabel", {
	Name = "ModeLabel",
	Size = UDim2.new(1, -132, 1, 0),
	Position = UDim2.new(0, 12, 0, 0),
	BackgroundTransparency = 1,
	Text = "Skill Mode",
	TextColor3 = colors.text,
	Font = Enum.Font.GothamMedium,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = modeRow,
})

local modeButton = make("TextButton", {
	Name = "ModeButton",
	Size = UDim2.new(0, 112, 0, 28),
	Position = UDim2.new(1, -124, 0.5, -14),
	BackgroundColor3 = Color3.fromRGB(41, 45, 51),
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Text = "Perfect  v",
	TextColor3 = colors.text,
	Font = Enum.Font.GothamMedium,
	TextSize = 13,
	Parent = modeRow,
})
addCorner(modeButton, 6)

local options = make("Frame", {
	Name = "ModeOptions",
	Size = dropdownClosedSize,
	Position = UDim2.new(0, 16, 0, 314),
	BackgroundColor3 = colors.surface,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Visible = false,
	ZIndex = 5,
	Parent = panel,
})
addCorner(options, 8)
local optionsStroke = addStroke(options, colors.surfaceStroke, 1)

local dropdownOpen = false
local dropdownTween
local dropdownCompletedConnection
local modeButtons = {}
local modeButtonHovers = {}
local currentSkillMode = Logic.getState().skillCheckMode

local function setDropdownOpen(open)
	dropdownOpen = open
	if dropdownCompletedConnection then
		dropdownCompletedConnection:Disconnect()
		dropdownCompletedConnection = nil
	end

	if dropdownTween then
		dropdownTween:Cancel()
		dropdownTween = nil
	end

	if open then
		options.Visible = true
	end

	dropdownTween = TweenService:Create(options, dropdownTweenInfo, {
		Size = open and dropdownOpenSize or dropdownClosedSize,
		BackgroundTransparency = open and 0 or 1,
	})
	local strokeTween = TweenService:Create(optionsStroke, dropdownTweenInfo, {
		Transparency = open and 0.25 or 1,
	})
	dropdownTween:Play()
	strokeTween:Play()
	dropdownCompletedConnection = dropdownTween.Completed:Connect(function(playbackState)
		if playbackState == Enum.PlaybackState.Completed and not dropdownOpen then
			options.Visible = false
		end
		if dropdownCompletedConnection then
			dropdownCompletedConnection:Disconnect()
			dropdownCompletedConnection = nil
		end
	end)

	modeButton.Text = modeButton.Text:gsub("[%^v]$", open and "^" or "v")
end

local function renderModeOption(mode)
	local button = modeButtons[mode]
	if not button then
		return
	end

	local selected = currentSkillMode == mode
	local hovering = modeButtonHovers[mode] == true
	button.BackgroundColor3 = selected and (hovering and colors.accentHover or colors.accent) or (hovering and colors.surfaceHover or colors.surface)
	button.TextColor3 = selected and Color3.fromRGB(12, 18, 24) or colors.text
end

local function makeModeOption(mode, y)
	local button = make("TextButton", {
		Name = mode .. "Option",
		Size = UDim2.new(1, -8, 0, 28),
		Position = UDim2.new(0, 4, 0, y),
		BackgroundColor3 = colors.surface,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = mode,
		TextColor3 = colors.text,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		ZIndex = 6,
		Parent = options,
	})
	addCorner(button, 6)

	connect(button.MouseButton1Click, function()
		Logic.setSkillCheckMode(mode)
		setDropdownOpen(false)
	end)

	modeButtons[mode] = button
	connect(button.MouseEnter, function()
		modeButtonHovers[mode] = true
		renderModeOption(mode)
	end)

	connect(button.MouseLeave, function()
		modeButtonHovers[mode] = false
		renderModeOption(mode)
	end)
end

makeModeOption("Normal", 4)
makeModeOption("Perfect", 34)

connect(modeButton.MouseButton1Click, function()
	setDropdownOpen(not dropdownOpen)
end)

connect(modeButton.MouseEnter, function()
	modeButton.BackgroundColor3 = colors.surfaceHover
end)

connect(modeButton.MouseLeave, function()
	modeButton.BackgroundColor3 = Color3.fromRGB(41, 45, 51)
end)

local function setToggleVisual(name, on)
	local pill = togglePills[name]
	if not pill then
		return
	end

	pill.Text = on and "ON" or "OFF"
	pill.BackgroundColor3 = on and colors.on or colors.off
end

local function render(state)
	setToggleVisual("Highlights", state.highlightsEnabled)
	setToggleVisual("Skill Check", state.skillCheckEnabled)
	setToggleVisual("Path Tree", state.pathTreeEnabled)
	setToggleVisual("Projectile Visualiser", state.projectileVisualiserEnabled)

	currentSkillMode = state.skillCheckMode
	modeButton.Text = string.format("%s  %s", state.skillCheckMode, dropdownOpen and "^" or "v")
	for mode in pairs(modeButtons) do
		renderModeOption(mode)
	end

	local enabled = {}
	if state.highlightsEnabled then
		table.insert(enabled, "ESP")
	end
	if state.pathTreeEnabled then
		table.insert(enabled, "Paths")
	end
	if state.skillCheckEnabled then
		table.insert(enabled, "Skill")
	end
	if state.projectileVisualiserEnabled then
		table.insert(enabled, "Proj")
	end

	if #enabled > 0 then
		statusText.Text = table.concat(enabled, " + ") .. " on"
	else
		statusText.Text = "All off"
	end
end

connect(Logic.Changed, render)
connect(sg:GetPropertyChangedSignal("Enabled"), syncCursorToGui)
connect(UserInputService.InputBegan, function(input, gameProcessed)
	if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end

	if input.KeyCode == Enum.KeyCode.RightControl then
		sg.Enabled = not sg.Enabled
		syncCursorToGui()
	end
end)

globalState[GUI_KEY] = {
	destroy = function()
		restoreCursorState()
		if dropdownCompletedConnection then
			dropdownCompletedConnection:Disconnect()
			dropdownCompletedConnection = nil
		end
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		table.clear(connections)
		if sg then
			sg:Destroy()
		end
	end,
}

Logic.start()
render(Logic.getState())
syncCursorToGui()

return globalState[GUI_KEY]
