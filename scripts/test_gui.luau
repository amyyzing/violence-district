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
		repeat task.wait() until content.Interactable or panel.Reopen.Visible or os.clock() >= deadline
	end
	local fields = {
		{ "Highlights", "highlightsEnabled", logic.setHighlightsEnabled },
		{ "SkillCheck", "skillCheckEnabled", logic.setSkillCheckEnabled },
		{ "Projectile", "projectileVisualiserEnabled", logic.setProjectileVisualiserEnabled },
		{ "SpearAim", "spearAimEnabled", logic.setSpearAimEnabled },
	}
	local ok, err = pcall(function()
		expect(not content.Features:FindFirstChild("PathTreeRow") and logic.setPathTreeEnabled == nil, "Path feature was not removed")
		if not controller.getState().enabled then activate(panel.Reopen) finishTransition() end
		expect(content.Title.Modal, "Visible panel did not release the pointer")
		for _, item in ipairs(fields) do
			local row = content.Features[item[1] .. "Row"]
			local initial = logic.getState()[item[2]]
			activate(row)
			expect(logic.getState()[item[2]] ~= initial, item[1] .. " did not toggle with one click")
			activate(row)
			expect(logic.getState()[item[2]] == initial, item[1] .. " did not toggle back")
		end
		for _, mode in ipairs({ "Normal", "Perfect" }) do
			activate(content.Mode[mode])
			activate(content.Mode[mode])
			expect(logic.getState().skillCheckMode == mode, "Mode selection failed")
		end
		logic.setSpearAimEnabled(true)
		task.wait(0.03)
		local fov = gui.SpearAimFov
		expect(fov.Visible and fov.AbsoluteSize.X == logic.SpearAimFovRadius * 2, "Aim FOV did not match the selection radius")
		local mouse = input:GetMouseLocation()
		expect((fov.AbsolutePosition + fov.AbsoluteSize * 0.5 - mouse).Magnitude < 1, "Aim FOV was offset from the mouse")
		logic.setSpearAimEnabled(false)
		task.wait(0.03)
		expect(not fov.Visible, "Aim FOV remained visible after disabling aim")
		local behavior, icon = input.MouseBehavior, input.MouseIconEnabled
		activate(content.Close)
		expect(not controller.getState().enabled and not content.Title.Modal, "Hide did not release modal state")
		expect(panel.Parent == gui and not content.Interactable, "Main frame did not start minimizing")
		expect(not panel.Reopen.Visible, "Cube appeared before minimize completed")
		expect(input.MouseBehavior == behavior and input.MouseIconEnabled == icon, "Hide overwrote the game's current mouse state")
		activate(panel.Reopen)
		finishTransition()
		expect(controller.getState().enabled and not panel.Reopen.Visible and content.Title.Modal, "Reopen failed")
		expect(gui.Panel == panel, "Transition replaced the main frame")
		local keyboardToggle
		for _, connection in ipairs(getconnections(input.InputBegan)) do
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
		keyboardToggle({ KeyCode = Enum.KeyCode.RightControl }, false)
		expect(not controller.getState().enabled and not content.Interactable, "Keyboard minimize did not start")
		task.wait(0.1)
		expect(not panel.Reopen.Visible, "Cube appeared during minimize")
		expect(panel.Size.Y.Offset < 328 and panel.Size.Y.Offset > 44, "Main frame did not shrink")
		expect(gui.Panel == panel and not gui:FindFirstChild("Minimizing"), "Minimize used a replacement frame")
		finishTransition()
		expect(panel.Reopen.Visible and not content.Visible, "Cube did not appear when minimize completed")
		local cube = panel.Reopen
		expect((panel.AbsolutePosition - cube.AbsolutePosition).Magnitude < 0.1 and
			(panel.AbsoluteSize - cube.AbsoluteSize).Magnitude < 0.1, "Cube did not match the main frame")
		expect(math.abs(panel.AbsoluteSize.X - 44) < 0.1 and math.abs(panel.AbsoluteSize.Y - 44) < 0.1, "Cube size was incorrect")
		keyboardToggle({ KeyCode = Enum.KeyCode.RightControl }, false)
		finishTransition()
		expect(controller.getState().enabled and content.Title.Modal, "Keyboard reopen failed")
		gui.Enabled = false
		task.wait(0.1)
		expect(not content.Title.Modal, "Disabled ScreenGui retained modal state")
		gui.Enabled = true
		task.wait(0.1)
		expect(content.Title.Modal, "Re-enabled ScreenGui did not restore modal state")
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
	if not savedGui.enabled then activate(content.Close) finishTransition() end
	assert(ok, err)
	return string.format("PASS: %d assertions; single-click toggles, mode selection, hide/reopen, mouse ownership, text fit", checks)
end
