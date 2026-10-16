-- Run against the loaded GUI. Only its callbacks are invoked; no OS input.
return function()
	local logic = getgenv().ViolenceDistrictLogic
	local controller = getgenv().ViolenceDistrictGui
	local gui = controller.Gui
	local panel = gui.Panel
	local input = game:GetService("UserInputService")
	local saved, savedGui = logic.getState(), controller.getState()
	local checks = 0
	local function activate(button)
		for _, connection in ipairs(getconnections(button.Activated)) do
			if connection.Function then connection.Function() end
		end
	end
	local function expect(value, message)
		assert(value, message)
		checks = checks + 1
	end
	local function finishTransition()
		local deadline = os.clock() + 3
		repeat task.wait() until not gui:FindFirstChild("Minimizing") or os.clock() >= deadline
	end
	local fields = {
		{ "Highlights", "highlightsEnabled", logic.setHighlightsEnabled },
		{ "SkillCheck", "skillCheckEnabled", logic.setSkillCheckEnabled },
		{ "Projectile", "projectileVisualiserEnabled", logic.setProjectileVisualiserEnabled },
		{ "SpearAim", "spearAimEnabled", logic.setSpearAimEnabled },
	}
	local ok, err = pcall(function()
		expect(not panel.Features:FindFirstChild("PathTreeRow") and logic.setPathTreeEnabled == nil, "Path feature was not removed")
		if not panel.Visible then activate(gui.Reopen) finishTransition() end
		expect(panel.Title.Modal, "Visible panel did not release the pointer")
		for _, item in ipairs(fields) do
			local row = panel.Features[item[1] .. "Row"]
			local initial = logic.getState()[item[2]]
			activate(row)
			expect(logic.getState()[item[2]] ~= initial, item[1] .. " did not toggle with one click")
			activate(row)
			expect(logic.getState()[item[2]] == initial, item[1] .. " did not toggle back")
		end
		for _, mode in ipairs({ "Normal", "Perfect" }) do
			activate(panel.Mode[mode])
			activate(panel.Mode[mode])
			expect(logic.getState().skillCheckMode == mode, "Mode selection failed")
		end
		local behavior, icon = input.MouseBehavior, input.MouseIconEnabled
		activate(panel.Close)
		expect(not panel.Visible and not panel.Title.Modal, "Hide did not release modal state")
		expect(gui:FindFirstChild("Minimizing") ~= nil, "Minimize button skipped the minimize tween")
		expect(input.MouseBehavior == behavior and input.MouseIconEnabled == icon, "Hide overwrote the game's current mouse state")
		activate(gui.Reopen)
		finishTransition()
		expect(panel.Visible and not gui.Reopen.Visible and panel.Title.Modal, "Reopen failed")
		expect(gui:FindFirstChild("Minimizing") == nil, "Reopen did not cancel the minimize tween")
		local keyboardToggle
		for _, connection in ipairs(getconnections(input.InputBegan)) do
			if connection.Function then
				for _, value in pairs(getupvalues(connection.Function)) do
					if value == panel then keyboardToggle = connection.Function end
				end
			end
		end
		expect(keyboardToggle ~= nil, "GUI keyboard toggle was not found")
		keyboardToggle({ KeyCode = Enum.KeyCode.RightControl }, false)
		local proxy = gui:FindFirstChild("Minimizing")
		expect(not panel.Visible and proxy ~= nil, "Keyboard minimize skipped the minimize tween")
		task.wait(0.1)
		expect(proxy.Parent == gui and proxy.Size.Y.Offset < panel.Size.Y.Offset and proxy.Size.Y.Offset > 44,
			string.format("Minimize tween did not shrink the panel: parent=%s height=%s full=%s", tostring(proxy.Parent == gui), tostring(proxy.Size.Y.Offset), tostring(panel.Size.Y.Offset)))
		expect(proxy:FindFirstChild("Tail1") == nil and proxy.Rotation == 0, "Minimize still deformed the panel")
		finishTransition()
		expect(gui:FindFirstChild("Minimizing") == nil and gui.Reopen.Visible, "Minimize tween did not finish at the reopen button")
		local target = gui.Reopen.AbsolutePosition - gui.AbsolutePosition + gui.Reopen.AbsoluteSize * 0.5
		expect((Vector2.new(proxy.Position.X.Offset, proxy.Position.Y.Offset) - target).Magnitude < 0.1,
			"Minimize endpoint did not match the cube's position")
		keyboardToggle({ KeyCode = Enum.KeyCode.RightControl }, false)
		finishTransition()
		expect(panel.Visible and panel.Title.Modal, "Keyboard reopen failed")
		gui.Enabled = false
		task.wait(0.1)
		expect(not panel.Title.Modal, "Disabled ScreenGui retained modal state")
		gui.Enabled = true
		task.wait(0.1)
		expect(panel.Title.Modal, "Re-enabled ScreenGui did not restore modal state")
		for _, object in ipairs(panel:GetDescendants()) do
			if object:IsA("TextLabel") or object:IsA("TextButton") then
				expect(object.TextFits, "Text overflow: " .. object.Name)
			end
		end
	end)
	gui.Enabled = true
	for _, item in ipairs(fields) do item[3](saved[item[2]]) end
	logic.setSkillCheckMode(saved.skillCheckMode)
	panel.Position = savedGui.position
	if not savedGui.enabled then activate(panel.Close) finishTransition() end
	assert(ok, err)
	return string.format("PASS: %d assertions; single-click toggles, mode selection, hide/reopen, mouse ownership, text fit", checks)
end
