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
	local fields = {
		{ "Highlights", "highlightsEnabled", logic.setHighlightsEnabled },
		{ "SkillCheck", "skillCheckEnabled", logic.setSkillCheckEnabled },
		{ "Projectile", "projectileVisualiserEnabled", logic.setProjectileVisualiserEnabled },
	}
	local ok, err = pcall(function()
		expect(not panel.Features:FindFirstChild("PathTreeRow") and logic.setPathTreeEnabled == nil, "Path feature was not removed")
		if not panel.Visible then activate(gui.Reopen) end
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
		expect(not panel.Visible and gui.Reopen.Visible and not panel.Title.Modal, "Hide did not release modal state")
		expect(input.MouseBehavior == behavior and input.MouseIconEnabled == icon, "Hide overwrote the game's current mouse state")
		activate(gui.Reopen)
		expect(panel.Visible and not gui.Reopen.Visible and panel.Title.Modal, "Reopen failed")
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
	if not savedGui.enabled then activate(panel.Close) end
	assert(ok, err)
	return string.format("PASS: %d assertions; single-click toggles, mode selection, hide/reopen, mouse ownership, text fit", checks)
end
