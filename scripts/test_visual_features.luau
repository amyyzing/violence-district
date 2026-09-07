-- Exercises client visuals using an owned fixture. Restores the feature switches.
return function()
	local logic = getgenv().ViolenceDistrictLogic
	local saved = logic.getState()
	local map = assert(workspace:FindFirstChild("Map"), "A loaded map is required")
	local fixture = Instance.new("Model")
	fixture.Name = "CateyesTestGenerator"
	fixture:SetAttribute("RepairProgress", 0)
	local part = Instance.new("Part")
	part.Name = "HitBox"
	part.Anchored, part.CanCollide, part.CanQuery, part.Transparency = true, false, false, 1
	part.Position = Vector3.new(0, -1000, 0)
	part.Parent = fixture
	local ensurePath = logic._ensurePathFolder
	local calls, routes = 0, 0
	local ok, err = pcall(function()
		logic.setPathTreeEnabled(false)
		logic.setHighlightsEnabled(true)
		fixture.Parent = map
		task.wait(0.1)
		assert(fixture:FindFirstChild("CateyesGeneratorHighlight"), "Generator was not highlighted")
		fixture:SetAttribute("RepairProgress", 100)
		task.wait(0.1)
		assert(not fixture:FindFirstChild("CateyesGeneratorHighlight"), "Completed generator stayed highlighted")
		fixture:SetAttribute("RepairProgress", 25)
		task.wait(0.1)
		assert(fixture:FindFirstChild("CateyesGeneratorHighlight"), "Incomplete generator did not return")
		logic.setHighlightsEnabled(false)
		assert(not fixture:FindFirstChild("CateyesGeneratorHighlight"), "Disable left generator highlight")
		for _, player in ipairs(game.Players:GetPlayers()) do
			assert(not player.Character or not player.Character:FindFirstChild("CateyesHighlight"), "Disable left player highlight")
		end
		logic.setHighlightsEnabled(true)
		for _, player in ipairs(game.Players:GetPlayers()) do
			if player.Character then
				local highlight = player.Character:FindFirstChild("CateyesHighlight")
				assert((highlight ~= nil) == (player ~= game.Players.LocalPlayer), "Wrong player highlight inclusion")
				if highlight then assert(highlight.FillColor == player.TeamColor.Color, "Wrong team color") end
			end
		end
		fixture.Parent = nil
		task.wait(0.1)
		assert(not fixture:FindFirstChild("CateyesGeneratorHighlight"), "Removed generator retained highlight")
		logic.setProjectileVisualiserEnabled(true)
		logic._setProjectileBeam(Vector3.zero, Vector3.new(0, 0, -5), Color3.new(1, 0, 0))
		logic._setProjectileImpact(Vector3.new(0, 0, -5), Color3.new(1, 0, 0))
		fixture.Parent = workspace
		logic._setProjectileTargetHighlight(fixture)
		assert(fixture:FindFirstChild("CateyesProjectileTargetHighlight"), "Target visual did not appear")
		local preview = assert(workspace:FindFirstChild("CateyesProjectileVisualiser"), "Preview folder missing")
		assert(preview:FindFirstChild("Impact"), "Impact visual missing")
		logic.setProjectileVisualiserEnabled(false)
		assert(not fixture:FindFirstChild("CateyesProjectileTargetHighlight"), "Disable retained target highlight")
		assert(not preview:FindFirstChild("Impact"), "Disable retained impact")
		fixture:Destroy()
		logic._ensurePathFolder = function()
			calls = calls + 1
			if calls == 1 then error("Intentional test: path worker must recover") end
			return ensurePath()
		end
		logic.setPathTreeEnabled(true)
		local deadline = os.clock() + 10
		repeat
			task.wait(0.2)
			routes = 0
			for _, route in pairs(logic._pathRoutes) do
				if route.folder and route.folder.Parent and route.folder:FindFirstChildWhichIsA("Beam", true) then routes = routes + 1 end
			end
		until (calls >= 2 and routes > 0) or os.clock() >= deadline
		assert(calls >= 2, "Path worker never recovered after an error")
		assert(routes > 0, "No path beams built on the live map")
		logic.setPathTreeEnabled(false)
		task.wait(0.1)
		assert(not workspace:FindFirstChild("CateyesPathTree"), "Disable retained path folder")
		assert(next(logic._pathRoutes) == nil, "Disable retained path routes")
	end)
	logic._ensurePathFolder = ensurePath
	fixture:Destroy()
	logic.setHighlightsEnabled(saved.highlightsEnabled)
	logic.setPathTreeEnabled(saved.pathTreeEnabled)
	logic.setProjectileVisualiserEnabled(saved.projectileVisualiserEnabled)
	assert(ok, err)
	return string.format("PASS: generator lifecycle, player colors, projectile cleanup, path worker recovery (%d passes, %d live routes)", calls, routes)
end
