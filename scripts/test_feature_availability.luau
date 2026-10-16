return function(logic)
	local checks = 0
	local function check(team, spearMode, dagger, expectedVeil, expectedParry, selected)
		local character = {
			GetAttribute = function(_, name) if name == "spearmode" then return spearMode end end,
			FindFirstChild = function(_, name) if name == "Parrying Dagger" and dagger then return {} end end,
		}
		local result = logic.getFeatureAvailability({ Team = team and { Name = team }, Character = character,
			GetAttribute = function() return selected end })
		assert(result.spearAimEnabled == expectedVeil and result.projectileVisualiserEnabled == expectedVeil,
			"Veil availability did not match the live character marker and team")
		assert(result.autoParryEnabled == expectedParry, "Dagger availability did not match equipped item and team")
		checks = checks + 2
	end
	check("Killer", true, false, true, false)
	check("Killer", false, false, true, false) -- Melee mode is still Veil.
	check("Killer", nil, true, false, false)
	check("Killer", nil, false, true, false, "Veil")
	check("Survivors", nil, true, false, true)
	check("Survivor", nil, false, false, false)
	check("Spectator", true, true, false, false)
	check(nil, nil, false, false, false)
	local missing = logic.getFeatureAvailability({ Team = { Name = "Killer" } })
	assert(not missing.spearAimEnabled and not missing.autoParryEnabled, "Missing character enabled restricted features")
	return string.format("PASS: %d feature availability assertions; team, Veil melee/spear modes, dagger and respawn", checks + 1)
end
