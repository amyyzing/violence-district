local LOGIC_KEY = "ViolenceDistrictLogic"
local GUI_KEY = "ViolenceDistrictGui"
local BASE_KEY = "ViolenceDistrictBaseUrl"
local DEFAULT_BASE_URL = "https://raw.githubusercontent.com/amyyzing/violence-district/main/"
local LOGIC_VERSION = 67

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
local function tween(object, props)
	if tweens[object] then tweens[object]:Cancel() end
	local animation = TweenService:Create(object, TweenInfo.new(0.14, Enum.EasingStyle.Quad), props)
	tweens[object] = animation
	animation:Play()
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
	Size = UDim2.fromOffset(348, 330), BackgroundColor3 = C.panel,
	Position = previousGuiState and previousGuiState.position or UDim2.fromOffset(48, 80),
	Visible = not previousGuiState or previousGuiState.enabled ~= false,
})
corner(panel, 14)
make("UIStroke", "Outline", panel, { Color = C.line, Thickness = 1 })
local scale = make("UIScale", "Scale", panel, { Scale = 1 })
local reopen = button(sg, "Reopen", "CE", 12, 180, 44, 44, C.panel)
reopen.TextColor3 = C.accent
corner(reopen, 14)
make("UIStroke", "Outline", reopen, { Color = C.line, Thickness = 1 })
reopen.Visible = not panel.Visible

local header = button(panel, "Title", "", 20, 14, 258, 56, C.panel)
label(header, "Brand", "Cateyes", 0, 0, 220, 28, 23, C.text, Enum.Font.GothamBold)
label(header, "Subtitle", "Violence District", 0, 31, 220, 18, 12, C.muted)
local close = button(panel, "Close", "-", 296, 20, 32, 32, C.surface)
close.TextSize = 20
close.TextColor3 = C.muted
corner(close, 9)
make("Frame", "Divider", panel, { Position = UDim2.fromOffset(20, 80), Size = UDim2.fromOffset(308, 1), BackgroundColor3 = C.line })

local group = make("Frame", "Features", panel, {
	Position = UDim2.fromOffset(20, 96), Size = UDim2.fromOffset(308, 138), BackgroundColor3 = C.surface,
})
corner(group, 10)
local channels = {
	{ id = "Highlights", title = "Highlights", hotkey = "Y", key = "highlightsEnabled", set = Logic.setHighlightsEnabled },
	{ id = "SkillCheck", title = "Skill check", hotkey = "G", key = "skillCheckEnabled", set = Logic.setSkillCheckEnabled },
	{ id = "Projectile", title = "Projectile preview", hotkey = "H", key = "projectileVisualiserEnabled", set = Logic.setProjectileVisualiserEnabled },
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

label(panel, "ModeLabel", "Skill mode", 20, 249, 110, 32, 12, C.muted)
local modeGroup = make("Frame", "Mode", panel, {
	Position = UDim2.fromOffset(152, 248), Size = UDim2.fromOffset(176, 34), BackgroundColor3 = C.surface,
})
corner(modeGroup, 9)
local modeButtons = {}
for index, mode in ipairs({ "Normal", "Perfect" }) do
	local option = button(modeGroup, mode, mode, 3 + (index - 1) * 85, 3, 85, 28)
	corner(option, 7)
	modeButtons[mode] = option
	connect(option.Activated, function() Logic.setSkillCheckMode(mode) end)
end
local count = label(panel, "Status", "All off", 20, 299, 128, 16, 11, C.muted)
local hint = label(panel, "Hint", "Right Ctrl to hide", 170, 299, 158, 16, 11, C.muted)
hint.TextXAlignment = Enum.TextXAlignment.Right

local function render(state)
	local enabled = 0
	for _, channel in ipairs(channels) do
		local on = state[channel.key] == true
		enabled = enabled + (on and 1 or 0)
		channel.status.Text = on and "On" or "Off"
		channel.status.TextColor3 = on and C.accent or C.muted
		tween(channel.mark, { Rotation = on and 45 or 0, BackgroundColor3 = on and C.accent or C.line })
	end
	for mode, option in pairs(modeButtons) do
		local selected = state.skillCheckMode == mode
		option.BackgroundColor3 = selected and C.accent or C.surface
		option.TextColor3 = selected and C.panel or C.muted
	end
	count.Text = enabled == 0 and "All off" or string.format("%d enabled", enabled)
end
local function fitPanel()
	if destroyed then return end
	local viewport = sg.AbsoluteSize
	if viewport.X <= 0 or viewport.Y <= 0 then return end
	local inset = game:GetService("GuiService"):GetGuiInset()
	scale.Scale = math.min(1, math.max(1, viewport.X - 16) / 348, math.max(1, viewport.Y - inset.Y - 16) / 330)
	local x = panel.Position.X.Scale * viewport.X + panel.Position.X.Offset
	local y = panel.Position.Y.Scale * viewport.Y + panel.Position.Y.Offset
	panel.Position = UDim2.fromOffset(math.clamp(x, 8, math.max(8, viewport.X - 348 * scale.Scale - 8)),
		math.clamp(y, inset.Y + 8, math.max(inset.Y + 8, viewport.Y - 330 * scale.Scale - 8)))
	reopen.Position = UDim2.fromOffset(12, math.clamp(180, inset.Y + 8, math.max(inset.Y + 8, viewport.Y - 52)))
end
-- Modal only releases the pointer while this panel is visible.
-- Never write MouseBehavior/MouseIconEnabled or restore a saved camera state.
local function syncVisibility()
	header.Modal = not destroyed and sg.Enabled and panel.Visible
	reopen.Visible = not panel.Visible
end
local function setVisible(visible)
	drag = nil
	panel.Visible = visible
	reopen.Visible = not visible
	fitPanel()
	syncVisibility()
end
connect(header.InputBegan, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		drag = { input = input, start = input.Position, position = panel.Position }
	end
end)
connect(UserInputService.InputChanged, function(input)
	if not drag or not panel.Visible then return end
	local mouseMove = drag.input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement
	if input ~= drag.input and not mouseMove then return end
	local delta = input.Position - drag.start
	panel.Position = drag.position + UDim2.fromOffset(delta.X, delta.Y)
	fitPanel()
end)
connect(UserInputService.InputEnded, function(input) if drag and input == drag.input then drag = nil end end)
connect(UserInputService.WindowFocusReleased, function() drag = nil end)
connect(close.Activated, function() setVisible(false) end)
connect(reopen.Activated, function() setVisible(true) end)
connect(Logic.Changed, render)
connect(sg:GetPropertyChangedSignal("Enabled"), syncVisibility)
connect(panel:GetPropertyChangedSignal("Visible"), syncVisibility)
connect(sg:GetPropertyChangedSignal("AbsoluteSize"), fitPanel)
connect(UserInputService.InputBegan, function(input, processed)
	if not processed and not UserInputService:GetFocusedTextBox() and input.KeyCode == Enum.KeyCode.RightControl then
		setVisible(not panel.Visible)
	end
end)
local controller = { Gui = sg }
function controller.getState()
	return { enabled = panel.Visible, position = panel.Position }
end
function controller.destroy()
	if destroyed then return end
	destroyed = true
	drag = nil
	syncVisibility()
	for _, connection in ipairs(connections) do connection:Disconnect() end
	for _, animation in pairs(tweens) do animation:Cancel() end
	table.clear(connections)
	table.clear(tweens)
	sg:Destroy()
	if globalState[GUI_KEY] == controller then globalState[GUI_KEY] = nil end
end
globalState[GUI_KEY] = controller
connect(sg.Destroying, controller.destroy)
Logic.start()
render(Logic.getState())
task.defer(fitPanel)
syncVisibility()
return controller
