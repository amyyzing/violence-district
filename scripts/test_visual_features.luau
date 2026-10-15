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
	local ok, err = pcall(function()
		assert(logic.setPathTreeEnabled == nil and logic.getState().pathTreeEnabled == nil, "Path feature is still exposed")
		logic.setHighlightsEnabled(true)
		fixture.Parent = map
		task.wait(0.1)
		assert(fixture:FindFirstChild("CateyesGeneratorHighlight"), "Generator was not highlighted")
		local progress = assert(fixture:FindFirstChild("CateyesGeneratorProgress"), "Progress label missing")
		assert(progress.Progress.Text == "0/100 (0%)", "Initial fraction incorrect")
		assert(progress.Adornee == part and progress.Size.X.Scale == 6 and progress.Size.X.Offset == 0, "Label is not proportional to the generator")
		assert(progress.StudsOffsetWorldSpace.Y == part.Size.Y * 0.5 + 0.75, "Label is not above the generator")
		fixture:SetAttribute("RepairProgress", 100)
		task.wait(0.1)
		assert(not fixture:FindFirstChild("CateyesGeneratorHighlight"), "Completed generator stayed highlighted")
		assert(not fixture:FindFirstChild("CateyesGeneratorProgress"), "Completed generator retained its label")
		fixture:SetAttribute("RepairProgress", 25)
		task.wait(0.1)
		assert(fixture:FindFirstChild("CateyesGeneratorHighlight"), "Incomplete generator did not return")
		assert(fixture.CateyesGeneratorProgress.Progress.Text == "25/100 (25%)", "Fraction did not update")
		fixture:SetAttribute("RepairProgress", 33.34)
		task.wait()
		assert(fixture.CateyesGeneratorProgress.Progress.Text == "33.3/100 (33.3%)", "Fraction formatting incorrect")
		logic.setHighlightsEnabled(false)
		assert(not fixture:FindFirstChild("CateyesGeneratorHighlight"), "Disable left generator highlight")
		assert(not fixture:FindFirstChild("CateyesGeneratorProgress"), "Disable left progress label")
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
		assert(not fixture:FindFirstChild("CateyesGeneratorProgress"), "Removed generator retained label")
		local streamed = Instance.new("Model")
		streamed.Name = "Generator"
		streamed:SetAttribute("RepairProgress", 12)
		streamed.Parent = map
		task.wait()
		assert(not streamed:FindFirstChild("CateyesGeneratorProgress"), "A generator without parts created a label")
		local streamedPart = part:Clone()
		streamedPart.Parent = streamed
		task.wait()
		local streamedLabel = streamed:FindFirstChild("CateyesGeneratorProgress")
		local attached = streamedLabel and streamedLabel.Adornee == streamedPart
		streamed:Destroy()
		assert(attached, "Streamed hitbox did not attach its progress label")
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
	end)
	fixture:Destroy()
	logic.setHighlightsEnabled(saved.highlightsEnabled)
	logic.setProjectileVisualiserEnabled(saved.projectileVisualiserEnabled)
	assert(ok, err)
	return "PASS: generator progress and lifecycle, player colors, projectile cleanup, removed path API"
end
