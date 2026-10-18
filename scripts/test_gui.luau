-- Run against the loaded GUI. Only its callbacks are invoked; no OS input.
return function()
	local logic = getgenv().ViolenceDistrictLogic
	local controller = getgenv().ViolenceDistrictGui
	local gui = controller.Gui
	local panel = gui.Panel
	local content = panel.Content
	local input = game:GetService("UserInputService")
	local saved, savedGui = logic.getState(), controller.getState()
	local checks = 0
	local getupvalues = getupvalues or debug.getupvalues
	local function activate(button)
		for _, connection in pairs(getconnections(button.Activated)) do
			if connection.Function then connection.Function() end
		end
	end
	local function expect(value, message)
		assert(value, message)
		checks = checks + 1
	end
	local function finishTransition()
		local deadline = os.clock() + 3
		repeat task.wait() until content.Interactable or panel.Reopen.Visible or os.clock() >= deadline
	end
	local keyboardToggle
	for _, connection in pairs(getconnections(input.InputBegan)) do
		if connection.Function then
			for _, value in pairs(getupvalues(connection.Function)) do
				if type(value) == "function" then
					for _, nested in pairs(getupvalues(value)) do
						if nested == panel then keyboardToggle = connection.Function end
					end
				end
			end
		end
	end
	expect(keyboardToggle ~= nil, "GUI keyboard toggle was not found")
	local function toggle() keyboardToggle({ KeyCode = Enum.KeyCode.RightControl }, false) end
	local dragMove
	for _, c in pairs(getconnections(input.InputChanged)) do
		if c.Function then
			for _, value in pairs(getupvalues(c.Function)) do
				if type(value) == "function" then
					for _, nested in pairs(getupvalues(value)) do if nested == panel then dragMove = c.Function end end
				end
			end
		end
	end
	local function dragCube(delta)
		assert(dragMove, "Drag movement callback missing")
		local click = { UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(100, 100, 0) }
		for _, c in pairs(getconnections(panel.Reopen.InputBegan)) do if c.Function then c.Function(click) end end
		dragMove({ UserInputType = Enum.UserInputType.MouseMovement, Position = click.Position + Vector3.new(delta.X, delta.Y, 0) })
		for _, c in pairs(getconnections(input.InputEnded)) do
			if c.Function then
				for _, value in pairs(getupvalues(c.Function)) do
					if type(value) == "table" and value.input == click then c.Function(click) break end
				end
			end
		end
	end
	local fields = {
		{ "Highlights", "highlightsEnabled", logic.setHighlightsEnabled },
		{ "SkillCheck", "skillCheckEnabled", logic.setSkillCheckEnabled },
		{ "Projectile", "projectileVisualiserEnabled", logic.setProjectileVisualiserEnabled },
		{ "SpearAim", "spearAimEnabled", logic.setSpearAimEnabled },
		{ "AutoParry", "autoParryEnabled", logic.setAutoParryEnabled },
	}
	local ok, err = pcall(function()
		expect(not content.Features:FindFirstChild("PathTreeRow") and logic.setPathTreeEnabled == nil, "Path feature was not removed")
		if not controller.getState().enabled then toggle() finishTransition() end
		expect(content.DragHandle.Modal, "Visible panel did not release the pointer")
		expect(not content:FindFirstChild("Title") and not content:FindFirstChild("Close") and not content:FindFirstChild("ParryTiming"), "Removed UI remained")
		expect(panel.Reopen:IsA("Frame"), "Minimized cube remained clickable")
		expect(not panel:FindFirstChild("Outline"), "Outer stroke remained")
		expect(content.Features.BackgroundTransparency == 1, "Feature group background remained")
		for _, item in ipairs(fields) do
			expect(content.Features[item[1] .. "Row"].BackgroundTransparency == 1, "Feature row background remained")
		end
		expect(content.Mode.BackgroundTransparency == 1 and content.Mode:FindFirstChild("Outline") ~= nil,
			"Mode container was not transparent with a border")
		expect(panel.BackgroundTransparency > 0 and panel.BackgroundTransparency < 1, "Panel was not semi-transparent")
		expect(content.DragHandle.AbsoluteSize == content.AbsoluteSize and content.DragHandle.ZIndex < content.Features.ZIndex,
			"Drag background did not cover the panel behind controls")
		expect(content.HealingCounter.Current.TextSize > content.HealingCounter.Total.TextSize, "Healing numerator was not larger")
		local total = content.HealingCounter.Total
		local totalCenter = total.AbsolutePosition.Y + total.AbsoluteSize.Y - total.TextBounds.Y / 2
		expect(math.abs(totalCenter - (content.Mode.AbsolutePosition.Y + content.Mode.AbsoluteSize.Y / 2)) < 1,
			"Healing denominator was not vertically centered with mode toggle")
		for _, item in ipairs(fields) do expect(not content.Features[item[1] .. "Row"]:FindFirstChild("State"), "Feature status remained") end
		for _, item in ipairs(fields) do
			local row = content.Features[item[1] .. "Row"]
			local initial = logic.getState()[item[2]]
			activate(row)
			if logic.getFeatureAvailability()[item[2]] == false then
				expect(not row.Interactable and not row:FindFirstChild("State"), item[1] .. " was not greyed out")
				expect(logic.getState()[item[2]] == initial, item[1] .. " toggled while unavailable")
				if not initial then
					item[3](true)
					expect(logic.getState()[item[2]] == false, item[1] .. " API enabled an unavailable feature")
				end
			else
				expect(logic.getState()[item[2]] ~= initial, item[1] .. " did not toggle with one click")
				activate(row)
				expect(logic.getState()[item[2]] == initial, item[1] .. " did not toggle back")
			end
		end
		local selection = content.Mode.Selection
		activate(content.Mode.Perfect)
		task.wait(0.25)
		local moved = false
		local modeConnection = selection:GetPropertyChangedSignal("Position"):Connect(function()
			if selection.Position.X.Offset > 3 and selection.Position.X.Offset < 88 then moved = true end
		end)
		for _, mode in ipairs({ "Normal", "Perfect" }) do
			activate(content.Mode[mode])
			task.wait(0.25)
			expect(logic.getState().skillCheckMode == mode, "Mode selection failed")
			expect(math.abs(selection.Position.X.Offset - (mode == "Perfect" and 88 or 3)) < 0.1, "Mode selection did not finish tweening")
		end
		modeConnection:Disconnect()
		expect(moved, "Mode selection did not animate")
		if logic.getFeatureAvailability().spearAimEnabled then
			logic.setSpearAimEnabled(true)
			task.wait(0.03)
			local fov = gui.SpearAimFov
			expect(fov.Visible and fov.AbsoluteSize.X == logic.SpearAimFovRadius * 2, "Aim FOV did not match the selection radius")
			local mouse = input:GetMouseLocation()
			expect((fov.AbsolutePosition + fov.AbsoluteSize * 0.5 - mouse).Magnitude < 1, "Aim FOV was offset from the mouse")
			logic.setSpearAimEnabled(false)
			task.wait(0.03)
			expect(not fov.Visible, "Aim FOV remained visible after disabling aim")
		else
			expect(not gui.SpearAimFov.Visible, "Aim FOV remained visible for an unavailable character")
		end
		local behavior, icon = input.MouseBehavior, input.MouseIconEnabled
		toggle()
		expect(not controller.getState().enabled and not content.DragHandle.Modal, "Hide did not release modal state")
		expect(panel.Parent == gui and not content.Interactable, "Main frame did not start minimizing")
		expect(not panel.Reopen.Visible, "Cube appeared before minimize completed")
		expect(input.MouseBehavior == behavior and input.MouseIconEnabled == icon, "Hide overwrote the game's current mouse state")
		toggle()
		finishTransition()
		expect(controller.getState().enabled and not panel.Reopen.Visible and content.DragHandle.Modal, "Reopen failed")
		expect(gui.Panel == panel, "Transition replaced the main frame")
		local sawShrink = false
		local sizeConnection = panel:GetPropertyChangedSignal("Size"):Connect(function()
			if panel.Size.Y.Offset < content.Size.Y.Offset and panel.Size.Y.Offset > 44 then sawShrink = true end
		end)
		keyboardToggle({ KeyCode = Enum.KeyCode.RightControl }, false)
		expect(not controller.getState().enabled and not content.Interactable, "Keyboard minimize did not start")
		task.wait(0.1)
		expect(not panel.Reopen.Visible, "Cube appeared during minimize")
		expect(gui.Panel == panel and not gui:FindFirstChild("Minimizing"), "Minimize used a replacement frame")
		finishTransition()
		sizeConnection:Disconnect()
		expect(sawShrink, "Main frame did not shrink")
		expect(panel.Reopen.Visible and not content.Visible, "Cube did not appear when minimize completed")
		local cube = panel.Reopen
		expect((panel.AbsolutePosition - cube.AbsolutePosition).Magnitude < 0.1 and
			(panel.AbsoluteSize - cube.AbsoluteSize).Magnitude < 0.1, "Cube did not match the main frame")
		expect(math.abs(panel.AbsoluteSize.X - 44) < 0.1 and math.abs(panel.AbsoluteSize.Y - 44) < 0.1, "Cube size was incorrect")
		local beforeCube, beforeFull = panel.Position, controller.getState().position
		local viewport = gui.AbsoluteSize
		local delta = Vector2.new(beforeCube.X.Offset + 24 < viewport.X - 52 and 24 or -24,
			beforeCube.Y.Offset + 16 < viewport.Y - 52 and 16 or -16)
		dragCube(delta)
		local movedCube = panel.Position
		expect(not controller.getState().enabled and movedCube ~= beforeCube, "Dragging cube did not move it while minimized")
		expect(controller.getState().position == beforeFull, "Cube drag moved the maximized menu position")
		toggle() finishTransition()
		toggle() finishTransition()
		expect(panel.Position == movedCube, "Minimize forgot the dragged cube position")
		dragCube(Vector2.new(beforeCube.X.Offset - movedCube.X.Offset, beforeCube.Y.Offset - movedCube.Y.Offset))
		keyboardToggle({ KeyCode = Enum.KeyCode.RightControl }, false)
		finishTransition()
		expect(controller.getState().enabled and content.DragHandle.Modal, "Keyboard reopen failed")
		gui.Enabled = false
		task.wait(0.1)
		expect(not content.DragHandle.Modal, "Disabled ScreenGui retained modal state")
		gui.Enabled = true
		task.wait(0.1)
		expect(content.DragHandle.Modal, "Re-enabled ScreenGui did not restore modal state")
		for _, object in ipairs(panel:GetDescendants()) do
			if object:IsA("TextLabel") or object:IsA("TextButton") then
				expect(object.TextFits, "Text overflow: " .. object.Name)
			end
		end
	end)
	gui.Enabled = true
	for _, item in ipairs(fields) do item[3](saved[item[2]]) end
	logic.setSkillCheckMode(saved.skillCheckMode)
	-- The transition preserves the saved full-panel position.
	if controller.getState().enabled ~= savedGui.enabled then toggle() finishTransition() end
	assert(ok, err)
	return string.format("PASS: %d assertions; single-click toggles, mode selection, hide/reopen, mouse ownership, text fit", checks)
end
