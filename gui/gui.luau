local LOGIC_KEY = "ViolenceDistrictLogic"
local GUI_KEY = "ViolenceDistrictGui"
local BASE_KEY = "ViolenceDistrictBaseUrl"
local DEFAULT_BASE_URL = "https://raw.githubusercontent.com/amyyzing/violence-district/main/"
local LOGIC_VERSION = 81
local PANEL_HEIGHT = 328

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local globalState = getgenv and getgenv() or _G
local baseUrl = globalState[BASE_KEY] or DEFAULT_BASE_URL
local LOGIC_URL = baseUrl .. "features/logic.luau"

local previousGui = globalState[GUI_KEY]
local previousGuiState = previousGui and previousGui.getState and previousGui.getState()
local existingGui = previousGui and previousGui.Gui or PG:FindFirstChild("CateyesGui")
if not existingGui then
	pcall(function() existingGui = game:GetService("CoreGui"):FindFirstChild("CateyesGui") end)
end
if not previousGuiState and existingGui then
	local oldPanel = existingGui:FindFirstChild("Panel")
	previousGuiState = { enabled = existingGui.Enabled, position = oldPanel and oldPanel.Position }
end

local Logic = globalState[LOGIC_KEY]
if not Logic or Logic.Version ~= LOGIC_VERSION then
	local chunk, err = loadstring(game:HttpGet(LOGIC_URL))
	if not chunk then
		error("Failed to load logic: " .. tostring(err), 0)
	end

	Logic = chunk()
end
assert(Logic and Logic.Version == LOGIC_VERSION, "GUI and logic versions do not match; retry after the download cache refreshes")
if previousGui and previousGui.destroy then previousGui.destroy() end
if existingGui and existingGui.Parent then existingGui:Destroy() end

local sg, panel
local destroyed = false

local connections, tweens = {}, {}
local healingConnections = {}
local healingCharacter
local drag
local C = {
	panel = Color3.fromRGB(23, 25, 31), surface = Color3.fromRGB(32, 35, 43),
	hover = Color3.fromRGB(39, 42, 51), line = Color3.fromRGB(49, 53, 63),
	text = Color3.fromRGB(237, 238, 243), muted = Color3.fromRGB(148, 154, 171),
	accent = Color3.fromRGB(184, 172, 249),
}
local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end
local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	if object:IsA("GuiObject") then object.BorderSizePixel = 0 end
	for key, value in pairs(props or {}) do object[key] = value end
	object.Parent = parent
	return object
end
local function label(parent, name, value, x, y, w, h, size, color, font)
	return make("TextLabel", name, parent, {
		Text = value, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1, TextColor3 = color or C.text, TextSize = size or 13,
		Font = font or Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
	})
end
local function button(parent, name, value, x, y, w, h, color)
	return make("TextButton", name, parent, {
		Text = value, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = color or C.surface, TextColor3 = C.text, TextSize = 12,
		Font = Enum.Font.GothamMedium, AutoButtonColor = false,
	})
end
local function corner(object, radius)
	make("UICorner", "Corner", object, { CornerRadius = UDim.new(0, radius) })
end
local function tween(object, props, duration, direction)
	if tweens[object] then tweens[object]:Cancel() end
	local animation = TweenService:Create(object, TweenInfo.new(duration or 0.14, Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tweens[object] = animation
	animation:Play()
	return animation
end

sg = make("ScreenGui", "CateyesGui", nil, {
	ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 2147483647,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
-- CoreGui gives DisplayOrder priority over the game's PlayerGui layer.
local mounted = pcall(function() sg.Parent = game:GetService("CoreGui") end)
if not mounted and type(gethui) == "function" then
	mounted = pcall(function() sg.Parent = assert(gethui(), "UI container unavailable") end)
end
if not mounted then sg.Parent = PG end
panel = make("Frame", "Panel", sg, {
	Size = UDim2.fromOffset(348, PANEL_HEIGHT), BackgroundColor3 = C.panel,
	Position = previousGuiState and previousGuiState.position or UDim2.fromOffset(48, 80),
	Visible = not previousGuiState or previousGuiState.enabled ~= false,
})
corner(panel, 14)
make("UIStroke", "Outline", panel, { Color = C.line, Thickness = 1 })
local scale = make("UIScale", "Scale", panel, { Scale = 1 })
local reopen = button(panel, "Reopen", "", 0, 0, 44, 44, C.panel)
reopen.TextColor3 = C.accent
reopen.BackgroundTransparency = 1
reopen.Size = UDim2.fromScale(1, 1)
reopen.Visible = not panel.Visible

-- Native geometry sampled from the supplied icon's alpha silhouette.
local reopenIcon = make("Frame", "ReopenIcon", reopen, {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1,
})
-- Match the minimize icon's proportion within its 32px button, on this 44px cube.
make("UIScale", "Scale", reopenIcon, { Scale = 0.65 * 44 / 32 })
for index, span in ipairs({
	{ 29, 1, 1 }, { 28, 2, 3 }, { 27, 3, 3 }, { 10, 4, 12 }, { 26, 4, 3 },
	{ 8, 5, 16 }, { 25, 5, 3 }, { 7, 6, 20 }, { 5, 7, 22 }, { 4, 8, 9 },
	{ 19, 8, 9 }, { 3, 9, 8 }, { 20, 9, 9 }, { 2, 10, 8 }, { 20, 10, 10 },
	{ 2, 11, 7 }, { 13, 11, 17 }, { 1, 12, 8 }, { 12, 12, 9 }, { 23, 12, 8 },
	{ 0, 13, 8 }, { 11, 13, 10 }, { 24, 13, 8 }, { 0, 14, 8 }, { 11, 14, 10 },
	{ 24, 14, 8 }, { 0, 15, 8 }, { 11, 15, 10 }, { 24, 15, 8 }, { 0, 16, 8 },
	{ 11, 16, 10 }, { 24, 16, 8 }, { 0, 17, 8 }, { 11, 17, 10 }, { 24, 17, 8 },
	{ 0, 18, 8 }, { 11, 18, 10 }, { 24, 18, 8 }, { 1, 19, 8 }, { 11, 19, 9 },
	{ 23, 19, 8 }, { 2, 20, 17 }, { 23, 20, 7 }, { 2, 21, 10 }, { 22, 21, 8 },
	{ 3, 22, 9 }, { 21, 22, 8 }, { 4, 23, 9 }, { 19, 23, 9 }, { 5, 24, 22 },
	{ 5, 25, 20 }, { 4, 26, 3 }, { 8, 26, 16 }, { 3, 27, 3 }, { 11, 27, 11 },
	{ 2, 28, 3 }, { 1, 29, 3 }, { 2, 30, 1 },
}) do
	make("Frame", "Stroke" .. index, reopenIcon, {
		Position = UDim2.fromScale(span[1] / 32, span[2] / 32),
		Size = UDim2.fromScale(span[3] / 32, 1 / 32), BackgroundColor3 = C.accent,
	})
end

local header = button(panel, "Title", "", 20, 14, 258, 38, C.panel)
local brand = label(header, "Brand", "Cateyes", 0, 0, 258, 38, 23, C.text, Enum.Font.GothamBold)
brand.TextXAlignment = Enum.TextXAlignment.Center
brand.TextYAlignment = Enum.TextYAlignment.Center
local close = button(panel, "Close", "", 296, 20, 32, 32, C.surface)
corner(close, 9)
local minimizeIcon = make("Frame", "MinimizeIcon", close, {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1,
})
local minimizeScale = make("UIScale", "Scale", minimizeIcon, { Scale = 0.65 })
local closeHovered, closePressed = false, false
local function animateClose()
	tween(close, { BackgroundColor3 = (closeHovered or closePressed) and C.hover or C.surface })
	tween(minimizeScale, { Scale = closePressed and 0.55 or (closeHovered and 0.72 or 0.65) })
end
connect(close.MouseEnter, function() closeHovered = true animateClose() end)
connect(close.MouseLeave, function() closeHovered, closePressed = false, false animateClose() end)
connect(close.InputBegan, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		closePressed = true
		animateClose()
	end
end)
connect(close.InputEnded, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		closePressed = false
		animateClose()
	end
end)
-- Four inward corners, matching the supplied minimize symbol without an asset download.
for index, position in ipairs({ Vector2.new(0, 0), Vector2.new(12, 0), Vector2.new(12, 12), Vector2.new(0, 12) }) do
	local segment = make("Frame", "Corner" .. index, minimizeIcon, {
		Position = UDim2.fromOffset(position.X, position.Y), Size = UDim2.fromOffset(8, 8),
		Rotation = (index - 1) * 90, BackgroundTransparency = 1,
	})
	for _, geometry in ipairs({ { 5, 0, 3, 8 }, { 0, 5, 8, 3 } }) do
		local stroke = make("Frame", "Stroke", segment, {
			Position = UDim2.fromOffset(geometry[1], geometry[2]), Size = UDim2.fromOffset(geometry[3], geometry[4]),
			BackgroundColor3 = C.accent,
		})
		corner(stroke, 2)
	end
end
make("Frame", "Divider", panel, { Position = UDim2.fromOffset(20, 64), Size = UDim2.fromOffset(308, 1), BackgroundColor3 = C.line })

local group = make("Frame", "Features", panel, {
	Position = UDim2.fromOffset(20, 80), Size = UDim2.fromOffset(308, 184), BackgroundColor3 = C.surface,
})
corner(group, 10)
local channels = {
	{ id = "Highlights", title = "Highlights", hotkey = "Y", key = "highlightsEnabled", set = Logic.setHighlightsEnabled },
	{ id = "SkillCheck", title = "Skill check", hotkey = "G", key = "skillCheckEnabled", set = Logic.setSkillCheckEnabled },
	{ id = "Projectile", title = "Projectile preview", hotkey = "H", key = "projectileVisualiserEnabled", set = Logic.setProjectileVisualiserEnabled },
	{ id = "SpearAim", title = "Spear aim", hotkey = "J", key = "spearAimEnabled", set = Logic.setSpearAimEnabled },
}
for index, channel in ipairs(channels) do
	local row = button(group, channel.id .. "Row", "", 0, (index - 1) * 46, 308, 46)
	corner(row, 10)
	label(row, "Label", channel.title, 14, 0, 174, 46, 13, C.text, Enum.Font.GothamMedium)
	local key = label(row, "Hotkey", channel.hotkey, 190, 0, 20, 46, 11, C.muted)
	key.TextXAlignment = Enum.TextXAlignment.Center
	channel.status = label(row, "State", "Off", 226, 0, 32, 46, 11, C.muted)
	local mark = make("Frame", "Mark", row, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(280, 23),
		Size = UDim2.fromOffset(12, 12), BackgroundColor3 = C.line,
	})
	corner(mark, 3)
	channel.mark = mark
	connect(row.Activated, function() channel.set(not Logic.getState()[channel.key]) end)
	connect(row.MouseEnter, function() tween(row, { BackgroundColor3 = C.hover }) end)
	connect(row.MouseLeave, function() tween(row, { BackgroundColor3 = C.surface }) end)
	if index < #channels then
		make("Frame", "Divider" .. index, group, {
			Position = UDim2.fromOffset(14, index * 46 - 1), Size = UDim2.fromOffset(280, 1), BackgroundColor3 = C.line,
			ZIndex = 2,
		})
	end
end

local healingCounter = label(panel, "HealingCounter", "Heal —/100", 20, 278, 135, 34, 12, C.accent, Enum.Font.GothamMedium)
healingCounter.TextXAlignment = Enum.TextXAlignment.Center
local function updateHealingCounter()
	if destroyed then return end
	local humanoid = healingCharacter and healingCharacter:FindFirstChildOfClass("Humanoid")
	local progress = healingCharacter and healingCharacter:GetAttribute("HealProgress")
	if humanoid and humanoid.Health >= humanoid.MaxHealth and humanoid.Health > 0 then
		progress = 100
	elseif not humanoid or humanoid.Health <= 0 then
		progress = nil
	end
	if type(progress) == "number" then
		progress = math.clamp(progress, 0, 100)
		local amount = string.format("%.1f", progress):gsub("%.0$", "")
		healingCounter.Text = "Heal " .. amount .. "/100"
	else
		healingCounter.Text = "Heal —/100"
	end
end
local function bindHealingCharacter(character)
	if destroyed then return end
	for _, connection in ipairs(healingConnections) do connection:Disconnect() end
	table.clear(healingConnections)
	healingCharacter = character
	if character then
		table.insert(healingConnections, character:GetAttributeChangedSignal("HealProgress"):Connect(updateHealingCounter))
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			table.insert(healingConnections, humanoid.HealthChanged:Connect(updateHealingCounter))
		else
			table.insert(healingConnections, character.ChildAdded:Connect(function(child)
				if not destroyed and healingCharacter == character and child:IsA("Humanoid") then bindHealingCharacter(character) end
			end))
		end
	end
	updateHealingCounter()
end
connect(LP.CharacterAdded, bindHealingCharacter)
connect(LP.CharacterRemoving, function(character)
	if healingCharacter == character then bindHealingCharacter(nil) end
end)
bindHealingCharacter(LP.Character)

local modeGroup = make("Frame", "Mode", panel, {
	Position = UDim2.fromOffset(152, 278), Size = UDim2.fromOffset(176, 34), BackgroundColor3 = C.surface,
})
corner(modeGroup, 9)
local modeButtons = {}
for index, mode in ipairs({ "Normal", "Perfect" }) do
	local option = button(modeGroup, mode, mode, 3 + (index - 1) * 85, 3, 85, 28)
	corner(option, 7)
	modeButtons[mode] = option
	connect(option.Activated, function() Logic.setSkillCheckMode(mode) end)
end
local function render(state)
	for _, channel in ipairs(channels) do
		local on = state[channel.key] == true
		channel.status.Text = on and "On" or "Off"
		channel.status.TextColor3 = on and C.accent or C.muted
		tween(channel.mark, { Rotation = on and 45 or 0, BackgroundColor3 = on and C.accent or C.line })
	end
	for mode, option in pairs(modeButtons) do
		local selected = state.skillCheckMode == mode
		option.BackgroundColor3 = selected and C.accent or C.surface
		option.TextColor3 = selected and C.panel or C.muted
	end
end
local expanded = panel.Visible
local fullPosition = panel.Position
local cubePosition = UDim2.fromOffset(12, 180)
local animating = false
local content = make("CanvasGroup", "Content", panel, {
	Size = UDim2.fromOffset(348, PANEL_HEIGHT), BackgroundTransparency = 1,
})
for _, child in ipairs(panel:GetChildren()) do
	if child:IsA("GuiObject") and child ~= content and child ~= reopen then child.Parent = content end
end
panel.Visible, panel.ClipsDescendants = true, true
local function fitPanel()
	if destroyed then return end
	local viewport = sg.AbsoluteSize
	if viewport.X <= 0 or viewport.Y <= 0 then return end
	local inset = game:GetService("GuiService"):GetGuiInset()
	scale.Scale = math.min(1, math.max(1, viewport.X - 16) / 348, math.max(1, viewport.Y - inset.Y - 16) / PANEL_HEIGHT)
	local x = fullPosition.X.Scale * viewport.X + fullPosition.X.Offset
	local y = fullPosition.Y.Scale * viewport.Y + fullPosition.Y.Offset
	fullPosition = UDim2.fromOffset(math.clamp(x, 8, math.max(8, viewport.X - 348 * scale.Scale - 8)),
		math.clamp(y, inset.Y + 8, math.max(inset.Y + 8, viewport.Y - PANEL_HEIGHT * scale.Scale - 8)))
	cubePosition = UDim2.fromOffset(12, math.clamp(180, inset.Y + 8, math.max(inset.Y + 8, viewport.Y - 52)))
	if not animating then
		panel.Position = expanded and fullPosition or cubePosition
		panel.Size = expanded and UDim2.fromOffset(348, PANEL_HEIGHT) or UDim2.fromOffset(44 / scale.Scale, 44 / scale.Scale)
	end
end
-- The same frame remains on screen throughout both transitions.
local function syncVisibility()
	header.Modal = not destroyed and sg.Enabled and expanded and not animating
	reopen.Visible = not expanded and not animating
	content.Visible = expanded or animating
	content.Interactable = expanded and not animating
end
local function transition(visible)
	if destroyed or (not animating and expanded == visible) then return end
	if expanded and not animating then fullPosition = panel.Position end
	expanded = visible
	drag = nil
	closeHovered, closePressed = false, false
	animateClose()
	animating = true
	fitPanel()
	syncVisibility()
	tween(content, { GroupTransparency = visible and 0 or 1 }, 0.7)
	local animation = tween(panel, {
		Position = visible and fullPosition or cubePosition,
		Size = visible and UDim2.fromOffset(348, PANEL_HEIGHT) or UDim2.fromOffset(44 / scale.Scale, 44 / scale.Scale),
	}, 0.7, Enum.EasingDirection.InOut)
	task.spawn(function()
		local result = animation.Completed:Wait()
		if destroyed or tweens[panel] ~= animation or result ~= Enum.PlaybackState.Completed then return end
		animating = false
		fitPanel()
		syncVisibility()
	end)
end
connect(header.InputBegan, function(input)
	if expanded and not animating and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		drag = { input = input, start = input.Position, position = panel.Position }
	end
end)
connect(UserInputService.InputChanged, function(input)
	if not drag or not expanded or animating then return end
	local mouseMove = drag.input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement
	if input ~= drag.input and not mouseMove then return end
	local delta = input.Position - drag.start
	fullPosition = drag.position + UDim2.fromOffset(delta.X, delta.Y)
	fitPanel()
end)
connect(UserInputService.InputEnded, function(input) if drag and input == drag.input then drag = nil end end)
connect(UserInputService.WindowFocusReleased, function()
	drag = nil
	closeHovered, closePressed = false, false
	animateClose()
end)
connect(close.Activated, function() transition(false) end)
connect(reopen.Activated, function() transition(true) end)
connect(Logic.Changed, render)
connect(sg:GetPropertyChangedSignal("Enabled"), syncVisibility)
connect(sg:GetPropertyChangedSignal("AbsoluteSize"), fitPanel)
connect(UserInputService.InputBegan, function(input, processed)
	if not processed and not UserInputService:GetFocusedTextBox() and input.KeyCode == Enum.KeyCode.RightControl then
		transition(not expanded)
	end
end)
local controller = { Gui = sg }
function controller.getState()
	return { enabled = expanded, position = fullPosition }
end
function controller.destroy()
	if destroyed then return end
	destroyed = true
	drag = nil
	syncVisibility()
	for _, connection in ipairs(connections) do connection:Disconnect() end
	for _, connection in ipairs(healingConnections) do connection:Disconnect() end
	for _, animation in pairs(tweens) do animation:Cancel() end
	table.clear(connections)
	table.clear(healingConnections)
	healingCharacter = nil
	table.clear(tweens)
	sg:Destroy()
	if globalState[GUI_KEY] == controller then globalState[GUI_KEY] = nil end
end
globalState[GUI_KEY] = controller
connect(sg.Destroying, controller.destroy)
Logic.start()
render(Logic.getState())
content.GroupTransparency = expanded and 0 or 1
fitPanel()
syncVisibility()
return controller
